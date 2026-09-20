import Stripe from "npm:stripe@17.7.0";

export function stripeClient(): Stripe {
  const key = Deno.env.get("STRIPE_SECRET_KEY");
  if (!key) throw new Error("STRIPE_SECRET_KEY is not set");
  return new Stripe(key, { httpClient: Stripe.createFetchHttpClient() });
}

/** Stripe price ids (public identifiers, not secrets). Override with the STRIPE_PRICE_* secrets if they change. */
export const PRICES = {
  essential: Deno.env.get("STRIPE_PRICE_ESSENTIAL") ?? "price_1UHowp3kPVs6fjFLhC7f8mdA",
  premium: Deno.env.get("STRIPE_PRICE_PREMIUM") ?? "price_1UHoxP3kPVs6fjFLeSKNnJpd",
  extension: Deno.env.get("STRIPE_PRICE_EXTENSION") ?? "price_1UHoxt3kPVs6fjFLwjY7BQrP",
} as const;
