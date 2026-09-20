# Deploying Stripe payments

Project ref: `qvdaelwujcerllbqufvn`

1. **Database.** In the Supabase SQL Editor run, in order, whatever you have not run yet:
   `003_editor.sql`, `004_palettes_templates.sql`, `005_delete_events.sql`, `006_extension_6_months.sql`, `007_stripe.sql`.

2. **Log in with the account that owns the project** (the Supabase CLI must list `qvdaelwujcerllbqufvn` in `supabase projects list`):
   ```
   supabase login
   supabase link --project-ref qvdaelwujcerllbqufvn
   ```

3. **Secrets** (never commit them):
   ```
   supabase secrets set STRIPE_SECRET_KEY=sk_live_...        # Stripe > Developers > API keys > Secret key
   supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...      # Stripe > Webhooks > your endpoint > Signing secret
   supabase secrets set SITE_URL=https://your-app-domain     # where the Flutter app is served (Stripe returns customers here)
   ```
   Optional: `ALLOWED_ORIGINS` (comma separated extra origins) and `STRIPE_PRICE_ESSENTIAL|PREMIUM|EXTENSION` if a price id changes.

4. **Deploy:**
   ```
   supabase functions deploy create-checkout
   supabase functions deploy stripe-webhook
   ```
   (`supabase/config.toml` already disables the JWT gateway check on both; each function authenticates on its own.)

5. **Stripe webhook endpoint:** `https://qvdaelwujcerllbqufvn.supabase.co/functions/v1/stripe-webhook`
   Events: `checkout.session.completed`, `checkout.session.expired`, `payment_intent.succeeded`,
   `payment_intent.payment_failed`, `charge.refunded`.
