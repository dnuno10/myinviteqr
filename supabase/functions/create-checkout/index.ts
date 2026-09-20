// Creates a Stripe Checkout Session for publishing an event or extending it.
// The amount always comes from the database (start_checkout), never from the browser.
import { createClient } from "npm:@supabase/supabase-js@2.49.1";
import { corsHeaders, json } from "../_shared/cors.ts";
import { PRICES, stripeClient } from "../_shared/stripe.ts";

const SITE_URL = (Deno.env.get("SITE_URL") ?? "https://myinviteqr.com").replace(/\/+$/, "");
const EXTRA_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ?? "").split(",").map((s) => s.trim().replace(/\/+$/, "")).filter(Boolean);

/** Where Stripe sends the customer back to. Only our own origins (or localhost) are accepted. */
function returnOrigin(requested: unknown): string {
  if (typeof requested === "string") {
    const o = requested.replace(/\/+$/, "");
    if (o === SITE_URL || EXTRA_ORIGINS.includes(o) || /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(o)) return o;
  }
  return SITE_URL;
}

class UserError extends Error {}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) throw new UserError("Sign in to continue");

    const userClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: u, error: uErr } = await userClient.auth.getUser(token);
    if (uErr || !u.user) throw new UserError("Your session expired. Sign in again.");
    const user = u.user;

    const body = await req.json().catch(() => ({}));
    const kind = body.kind === "extension" ? "extension" : "publish";
    const eventId = String(body.event_id ?? "");
    if (!eventId) throw new UserError("Missing event");
    const plan = kind === "publish" ? String(body.plan ?? "") : null;
    if (kind === "publish" && plan !== "essential" && plan !== "premium") throw new UserError("Choose a plan");

    // 1. Validate and record a pending order (RLS + auth.uid() inside the function)
    const { data: order, error: oErr } = await userClient.rpc("start_checkout", {
      p_event: eventId,
      p_kind: kind,
      p_plan: plan,
      p_extension: kind === "publish" ? body.extension === true : true,
      p_code: kind === "publish" && body.code ? String(body.code) : null,
    });
    if (oErr) throw new UserError(oErr.message);

    const admin = createClient(url, service);

    // 2. Nothing to charge (100% discount code): fulfil right away
    if (order.total <= 0) {
      const { error } = await admin.rpc("fulfill_order", { p_order: order.order_id, p_payment_intent: null, p_session: null });
      if (error) throw new Error(error.message);
      return json({ free: true, url: null, order_id: order.order_id, kind });
    }

    // 3. Build the Stripe line items and make sure Stripe prices match our database
    const stripe = stripeClient();
    const items: { price: string; expected: number }[] = [];
    if (kind === "publish") items.push({ price: PRICES[order.plan as "essential" | "premium"], expected: order.plan_cents });
    if (order.extension) items.push({ price: PRICES.extension, expected: order.ext_cents });

    for (const it of items) {
      const p = await stripe.prices.retrieve(it.price);
      if (!p.active || p.type !== "one_time" || p.currency !== "usd" || p.unit_amount !== it.expected) {
        console.error("price mismatch", it.price, p.unit_amount, it.expected);
        throw new Error("Payment setup mismatch. Please contact support.");
      }
    }

    let discounts: { coupon: string }[] | undefined;
    if (order.discount > 0) {
      const coupon = await stripe.coupons.create(
        {
          amount_off: order.discount,
          currency: "usd",
          duration: "once",
          max_redemptions: 1,
          name: String(order.code ?? "Discount").slice(0, 40),
        },
        { idempotencyKey: `coupon-${order.order_id}` },
      );
      discounts = [{ coupon: coupon.id }];
    }

    const origin = returnOrigin(body.origin);
    const meta = { order_id: order.order_id, event_id: eventId, user_id: user.id, kind };
    const session = await stripe.checkout.sessions.create(
      {
        mode: "payment",
        line_items: items.map((i) => ({ price: i.price, quantity: 1 })),
        discounts,
        customer_email: user.email ?? undefined,
        client_reference_id: order.order_id,
        metadata: meta,
        payment_intent_data: { metadata: meta, description: `MyInviteQR - ${order.title || "Event"}` },
        success_url: `${origin}/?checkout=success&order=${order.order_id}&event=${eventId}&kind=${kind}`,
        cancel_url: `${origin}/?checkout=cancel&event=${eventId}&kind=${kind}`,
        expires_at: Math.floor(Date.now() / 1000) + 60 * 60,
      },
      { idempotencyKey: `checkout-${order.order_id}` },
    );

    await admin.from("orders").update({ stripe_session_id: session.id, provider_ref: session.id, provider: "stripe" }).eq("id", order.order_id);

    return json({ url: session.url, free: false, order_id: order.order_id, kind });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Something went wrong";
    console.error("create-checkout:", msg);
    return json({ error: msg }, e instanceof UserError ? 400 : 500);
  }
});
