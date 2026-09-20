// Receives Stripe events. Signed with STRIPE_WEBHOOK_SECRET; never trusts the payload without it.
// Every database write goes through idempotent SQL functions, so retries and duplicate events are safe.
import Stripe from "npm:stripe@17.7.0";
import { createClient } from "npm:@supabase/supabase-js@2.49.1";
import { stripeClient } from "../_shared/stripe.ts";

const stripe = stripeClient();
const cryptoProvider = Stripe.createSubtleCryptoProvider();

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  const signature = req.headers.get("stripe-signature");
  if (!secret || !signature) return new Response("Missing signature", { status: 400 });

  const raw = await req.text();
  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(raw, signature, secret, undefined, cryptoProvider);
  } catch (e) {
    console.error("bad signature:", e instanceof Error ? e.message : e);
    return new Response("Invalid signature", { status: 400 });
  }

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const fulfill = async (orderId: string | null | undefined, paymentIntent: string | null, session: string | null) => {
    if (!orderId) {
      console.warn(event.type, "without order_id metadata, ignored");
      return;
    }
    const { data, error } = await admin.rpc("fulfill_order", {
      p_order: orderId,
      p_payment_intent: paymentIntent,
      p_session: session,
    });
    if (error) throw new Error(`fulfill_order: ${error.message}`);
    if (data?.orphan) console.error("PAID ORDER WITHOUT EVENT, refund it:", orderId, paymentIntent);
    console.log(event.type, "order", orderId, JSON.stringify(data));
  };

  try {
    switch (event.type) {
      case "checkout.session.completed":
      case "checkout.session.async_payment_succeeded": {
        const s = event.data.object as Stripe.Checkout.Session;
        if (s.payment_status === "paid" || s.payment_status === "no_payment_required") {
          const pi = typeof s.payment_intent === "string" ? s.payment_intent : s.payment_intent?.id ?? null;
          await fulfill(s.metadata?.order_id ?? s.client_reference_id, pi, s.id);
        }
        break;
      }
      case "payment_intent.succeeded": {
        // Safety net in case the session event arrives late; fulfil is idempotent.
        const pi = event.data.object as Stripe.PaymentIntent;
        await fulfill(pi.metadata?.order_id, pi.id, null);
        break;
      }
      case "checkout.session.expired": {
        const s = event.data.object as Stripe.Checkout.Session;
        const { error } = await admin.rpc("fail_order", { p_session: s.id, p_reason: "Checkout session expired" });
        if (error) throw new Error(`fail_order: ${error.message}`);
        break;
      }
      case "payment_intent.payment_failed": {
        // The customer can retry inside the same Checkout page, so the order stays pending.
        const pi = event.data.object as Stripe.PaymentIntent;
        const orderId = pi.metadata?.order_id;
        if (orderId) {
          await admin.from("orders").update({ stripe_error: pi.last_payment_error?.message ?? "Payment failed" })
            .eq("id", orderId).eq("status", "pending");
        }
        break;
      }
      case "charge.refunded": {
        const c = event.data.object as Stripe.Charge;
        const pi = typeof c.payment_intent === "string" ? c.payment_intent : c.payment_intent?.id;
        if (pi) {
          const { error } = await admin.rpc("record_refund", { p_payment_intent: pi, p_refunded_cents: c.amount_refunded });
          if (error) throw new Error(`record_refund: ${error.message}`);
        }
        break;
      }
      default:
        console.log("ignored", event.type);
    }
  } catch (e) {
    console.error("webhook processing failed:", e instanceof Error ? e.message : e);
    return new Response("Processing error", { status: 500 }); // Stripe retries with backoff
  }
  return new Response(JSON.stringify({ received: true }), { headers: { "Content-Type": "application/json" } });
});
