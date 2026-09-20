-- =============================================================================
-- myinviteqr - PostgreSQL schema (v1)
-- Pricing model: one-time payment per event (Essential $9.99 / Premium $19.99),
-- 90 days of validity counted from PUBLICATION (payment), +$4.99 per 3-month
-- extension, Essential -> Premium upgrade for the price difference,
-- "Keepsake" add-on ($4.99/year), 7-day refund, 12-month host-data retention.
-- All money is stored in integer cents (USD).
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS citext;     -- case-insensitive emails / slugs

-- ---------------------------------------------------------------------------
-- Enumerations
-- ---------------------------------------------------------------------------
CREATE TYPE user_role          AS ENUM ('host', 'admin', 'support');
CREATE TYPE auth_provider      AS ENUM ('email', 'google', 'apple');
CREATE TYPE plan_code          AS ENUM ('essential', 'premium');
CREATE TYPE event_status       AS ENUM ('draft', 'published', 'grace', 'archived', 'deleted');
CREATE TYPE template_status    AS ENUM ('draft', 'in_review', 'published', 'retired');
CREATE TYPE rsvp_status        AS ENUM ('pending', 'yes', 'no', 'maybe');
CREATE TYPE order_status       AS ENUM ('pending', 'paid', 'failed', 'refunded', 'partially_refunded');
CREATE TYPE order_item_kind    AS ENUM ('plan', 'upgrade', 'extension', 'keepsake');
CREATE TYPE payment_method     AS ENUM ('card', 'apple_pay', 'google_pay');
CREATE TYPE refund_status      AS ENUM ('requested', 'approved', 'rejected', 'processed');
CREATE TYPE ticket_kind        AS ENUM ('refund', 'moderation', 'support', 'extension');
CREATE TYPE ticket_status      AS ENUM ('open', 'in_progress', 'resolved', 'closed');
CREATE TYPE email_kind         AS ENUM (
  'expiry_60d', 'expiry_80d', 'expiry_7d_left', 'grace_started', 'archived',
  'guest_invitation', 'guest_reminder', 'thank_you', 'receipt'
);
CREATE TYPE email_status       AS ENUM ('scheduled', 'sent', 'failed', 'cancelled');
CREATE TYPE block_kind         AS ENUM (
  'cover', 'main_text', 'date_time', 'location', 'itinerary', 'dress_code',
  'gifts', 'countdown', 'rsvp', 'gallery', 'free_text', 'access_qr',
  'lodging', 'menu', 'couple_story', 'baby_games', 'trip_checklist',
  'schedule_speakers', 'potluck'
);
CREATE TYPE question_type      AS ENUM ('text', 'single_choice', 'multi_choice', 'number');

-- ---------------------------------------------------------------------------
-- Accounts (guests never need an account)
-- ---------------------------------------------------------------------------
CREATE TABLE users (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email          citext NOT NULL UNIQUE,
  full_name      text   NOT NULL,
  avatar_url     text,
  role           user_role NOT NULL DEFAULT 'host',
  locale         text NOT NULL DEFAULT 'en' CHECK (locale IN ('en', 'es')),
  stripe_customer_id text UNIQUE,
  created_at     timestamptz NOT NULL DEFAULT now(),
  deleted_at     timestamptz
);

CREATE TABLE auth_identities (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider       auth_provider NOT NULL,
  provider_uid   text NOT NULL,              -- Google/Apple subject or email
  password_hash  text,                       -- only for provider = 'email'
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_uid)
);

-- ---------------------------------------------------------------------------
-- Catalog: plans, event categories, templates
-- ---------------------------------------------------------------------------
CREATE TABLE plans (
  code                   plan_code PRIMARY KEY,
  name                   text    NOT NULL,
  price_cents            integer NOT NULL,
  validity_days          integer NOT NULL DEFAULT 90,
  extension_price_cents  integer NOT NULL DEFAULT 499,
  extension_days         integer NOT NULL DEFAULT 90,
  max_guests             integer NOT NULL,
  max_reminders          integer,            -- NULL = unlimited
  max_co_hosts           integer NOT NULL DEFAULT 0,
  custom_slug            boolean NOT NULL DEFAULT false,
  individual_links       boolean NOT NULL DEFAULT false,
  custom_questions       boolean NOT NULL DEFAULT false,
  open_analytics         boolean NOT NULL DEFAULT false,
  shared_album           boolean NOT NULL DEFAULT false,
  gift_list              boolean NOT NULL DEFAULT false,
  multiple_sub_events    boolean NOT NULL DEFAULT false,
  remove_branding        boolean NOT NULL DEFAULT false,
  premium_editor         boolean NOT NULL DEFAULT false   -- premium fonts, animation, music, video
);

INSERT INTO plans (code, name, price_cents, max_guests, max_reminders, max_co_hosts,
                   custom_slug, individual_links, custom_questions, open_analytics,
                   shared_album, gift_list, multiple_sub_events, remove_branding, premium_editor)
VALUES
  ('essential', 'Essential',  999,  50, 1,    0, false, false, false, false, false, false, false, false, false),
  ('premium',   'Premium',   1999, 300, NULL, 3, true,  true,  true,  true,  true,  true,  true,  true,  true);

CREATE TABLE event_categories (
  id          serial PRIMARY KEY,
  slug        text UNIQUE NOT NULL,          -- birthday, baby_shower, wedding...
  name        text NOT NULL,
  icon        text,
  sort_order  integer NOT NULL DEFAULT 0,
  is_active   boolean NOT NULL DEFAULT true
);

INSERT INTO event_categories (slug, name, sort_order) VALUES
  ('birthday','Birthday',1), ('baby_shower','Baby shower',2), ('wedding','Wedding',3),
  ('anniversary','Anniversary',4), ('graduation','Graduation',5), ('farewell','Farewell',6),
  ('gender_reveal','Gender reveal',7), ('quinceanera','Quinceañera',8),
  ('baptism_communion','Baptism & communion',9), ('year_end_party','Year-end party',10),
  ('corporate','Corporate',11), ('trip','Trip',12),
  ('dinner_gathering','Dinner or get-together',13), ('other','Other',14);

CREATE TABLE templates (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id   integer NOT NULL REFERENCES event_categories(id),
  name          text NOT NULL,
  style         text NOT NULL,               -- romantic, minimalist, modern, kids...
  languages     text[] NOT NULL DEFAULT '{en}',
  min_plan      plan_code NOT NULL DEFAULT 'essential',   -- premium = exclusive
  palette       jsonb NOT NULL DEFAULT '[]', -- swatches shown in the picker
  layout        jsonb NOT NULL,              -- closed layout + editable zones + design guards
  thumbnail_url text NOT NULL,
  status        template_status NOT NULL DEFAULT 'draft',
  designer      text,
  created_by    uuid REFERENCES users(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX templates_browse_idx ON templates (category_id, status, min_plan);

CREATE TABLE font_pairs (          -- the 12-15 curated heading/body pairs
  id            serial PRIMARY KEY,
  heading_font  text NOT NULL,
  body_font     text NOT NULL,
  is_premium    boolean NOT NULL DEFAULT false
);

CREATE TABLE template_favorites (
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  template_id uuid NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, template_id)
);

-- ---------------------------------------------------------------------------
-- Events
-- validity is counted from published_at (the payment), NOT from draft creation.
-- Drafts are kept 60 days (draft_expires_at); designing/previewing is free.
-- ---------------------------------------------------------------------------
CREATE TABLE events (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id        uuid NOT NULL REFERENCES users(id),
  category_id     integer NOT NULL REFERENCES event_categories(id),
  template_id     uuid REFERENCES templates(id),
  title           text NOT NULL,
  slug            citext UNIQUE,            -- /sofia  (custom = Premium only)
  public_token    text NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(9), 'hex'),
  language        text NOT NULL DEFAULT 'en' CHECK (language IN ('en', 'es')),
  plan            plan_code REFERENCES plans(code),          -- set at checkout
  status          event_status NOT NULL DEFAULT 'draft',
  starts_at       timestamptz,
  ends_at         timestamptz,
  timezone        text NOT NULL DEFAULT 'America/Mexico_City',
  venue_name      text,
  venue_address   text,
  venue_lat       numeric(9,6),
  venue_lng       numeric(9,6),
  rsvp_deadline   timestamptz,
  design          jsonb NOT NULL DEFAULT '{}',   -- colors, fonts, alignment, background, cover zoom
  opening_style   text NOT NULL DEFAULT 'envelope',   -- animated envelope open (configurable)
  cover_image_url text,
  noindex         boolean NOT NULL DEFAULT true,       -- invitations are noindex by default
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  draft_expires_at timestamptz NOT NULL DEFAULT now() + interval '60 days',
  published_at    timestamptz,
  expires_at      timestamptz,                   -- published_at + 90 days (+ extensions)
  grace_ends_at   timestamptz,                   -- expires_at + 7 days
  host_data_purge_at timestamptz,                -- expires_at + 12 months
  archived_at     timestamptz,
  keepsake_until  timestamptz,                   -- "Keepsake" add-on
  CHECK (status = 'draft' OR published_at IS NOT NULL)
);
CREATE INDEX events_owner_idx   ON events (owner_id, status);
CREATE INDEX events_expiry_idx  ON events (status, expires_at);

-- Ceremony + reception etc. (Premium: multiple events)
CREATE TABLE event_sub_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id    uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  title       text NOT NULL,
  starts_at   timestamptz NOT NULL,
  venue_name  text,
  venue_address text,
  sort_order  integer NOT NULL DEFAULT 0
);

-- Ordered, toggleable content blocks (drag & drop reorder in the editor)
CREATE TABLE event_blocks (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id    uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  kind        block_kind NOT NULL,
  is_enabled  boolean NOT NULL DEFAULT true,
  position    integer NOT NULL,
  content     jsonb NOT NULL DEFAULT '{}',
  UNIQUE (event_id, position) DEFERRABLE INITIALLY DEFERRED
);

-- Undo / redo + autosave history of the editor
CREATE TABLE event_revisions (
  id          bigserial PRIMARY KEY,
  event_id    uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  snapshot    jsonb NOT NULL,
  is_autosave boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX event_revisions_idx ON event_revisions (event_id, created_at DESC);

CREATE TABLE event_co_hosts (
  event_id   uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id),
  invited_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (event_id, user_id)
);

CREATE TABLE gift_links (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id  uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  store     text NOT NULL,
  url       text NOT NULL,
  label     text
);

-- ---------------------------------------------------------------------------
-- Guests & RSVP
-- ---------------------------------------------------------------------------
CREATE TABLE guest_groups (
  id        serial PRIMARY KEY,
  event_id  uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  name      text NOT NULL,            -- Family, Friends, Work
  UNIQUE (event_id, name)
);

CREATE TABLE guests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id      uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  group_id      integer REFERENCES guest_groups(id) ON DELETE SET NULL,
  full_name     text NOT NULL,
  email         citext,
  phone         text,
  personal_token text NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(9), 'hex'), -- individual link (Premium)
  rsvp          rsvp_status NOT NULL DEFAULT 'pending',
  companions    smallint NOT NULL DEFAULT 0 CHECK (companions >= 0),
  message       text,
  responded_at  timestamptz,
  first_opened_at timestamptz,
  last_opened_at  timestamptz,
  open_count    integer NOT NULL DEFAULT 0,
  source        text NOT NULL DEFAULT 'manual',   -- manual | csv | contacts | public_link
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (event_id, email)
);
CREATE INDEX guests_event_rsvp_idx ON guests (event_id, rsvp);

-- Premium: menu, allergies, size, age, company/position...
CREATE TABLE rsvp_questions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id    uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  label       text NOT NULL,
  help_text   text,
  type        question_type NOT NULL DEFAULT 'text',
  options     jsonb,
  is_required boolean NOT NULL DEFAULT false,
  position    integer NOT NULL DEFAULT 0
);

CREATE TABLE rsvp_answers (
  guest_id    uuid NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
  question_id uuid NOT NULL REFERENCES rsvp_questions(id) ON DELETE CASCADE,
  answer      jsonb NOT NULL,
  PRIMARY KEY (guest_id, question_id)
);

-- Every invitation open (analytics: who opened, when, who is missing)
CREATE TABLE invitation_opens (
  id          bigserial PRIMARY KEY,
  event_id    uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  guest_id    uuid REFERENCES guests(id) ON DELETE SET NULL,   -- NULL = generic link / QR
  opened_at   timestamptz NOT NULL DEFAULT now(),
  channel     text,                        -- link | qr | email | share
  device      text,
  country     text
);
CREATE INDEX invitation_opens_event_idx ON invitation_opens (event_id, opened_at DESC);

-- Shared photo album (Premium) and post-event thank-you
CREATE TABLE album_photos (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id    uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  guest_id    uuid REFERENCES guests(id) ON DELETE SET NULL,
  url         text NOT NULL,
  is_hidden   boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Payments & billing (Stripe: card, Apple Pay, Google Pay)
-- ---------------------------------------------------------------------------
CREATE TABLE discount_codes (
  code            citext PRIMARY KEY,
  percent_off     smallint CHECK (percent_off BETWEEN 1 AND 100),
  amount_off_cents integer CHECK (amount_off_cents > 0),
  max_redemptions integer,
  redeemed        integer NOT NULL DEFAULT 0,
  valid_until     timestamptz,
  is_active       boolean NOT NULL DEFAULT true,
  CHECK (percent_off IS NOT NULL OR amount_off_cents IS NOT NULL)
);

CREATE TABLE orders (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  number           bigint GENERATED ALWAYS AS IDENTITY UNIQUE,   -- #4582
  user_id          uuid NOT NULL REFERENCES users(id),
  event_id         uuid NOT NULL REFERENCES events(id),
  status           order_status NOT NULL DEFAULT 'pending',
  subtotal_cents   integer NOT NULL,
  discount_code    citext REFERENCES discount_codes(code),
  discount_cents   integer NOT NULL DEFAULT 0,
  total_cents      integer NOT NULL,
  currency         char(3) NOT NULL DEFAULT 'USD',
  payment_method   payment_method,
  save_payment_method boolean NOT NULL DEFAULT false,
  stripe_payment_intent text UNIQUE,
  stripe_fee_cents integer,
  created_at       timestamptz NOT NULL DEFAULT now(),
  paid_at          timestamptz
);
CREATE INDEX orders_paid_idx ON orders (status, paid_at);

CREATE TABLE order_items (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  kind         order_item_kind NOT NULL,
  plan         plan_code REFERENCES plans(code),
  description  text NOT NULL,
  amount_cents integer NOT NULL,
  extends_days integer                       -- extension items: days added to expires_at
);

CREATE TABLE refunds (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id      uuid NOT NULL REFERENCES orders(id),
  amount_cents  integer NOT NULL,
  reason        text,
  status        refund_status NOT NULL DEFAULT 'requested',
  requested_at  timestamptz NOT NULL DEFAULT now(),
  processed_at  timestamptz,
  processed_by  uuid REFERENCES users(id),
  stripe_refund_id text UNIQUE
);

CREATE TABLE invoices (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     uuid NOT NULL UNIQUE REFERENCES orders(id),
  number       text NOT NULL UNIQUE,
  pdf_url      text,
  issued_at    timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Emails / reminders (expiry notices, guest reminders)
-- ---------------------------------------------------------------------------
CREATE TABLE email_jobs (
  id          bigserial PRIMARY KEY,
  kind        email_kind NOT NULL,
  event_id    uuid REFERENCES events(id) ON DELETE CASCADE,
  guest_id    uuid REFERENCES guests(id) ON DELETE CASCADE,
  to_email    citext NOT NULL,
  payload     jsonb NOT NULL DEFAULT '{}',
  send_at     timestamptz NOT NULL,
  status      email_status NOT NULL DEFAULT 'scheduled',
  sent_at     timestamptz,
  error       text
);
CREATE INDEX email_jobs_due_idx ON email_jobs (status, send_at);
-- idempotency: one expiry notice of each kind per event
CREATE UNIQUE INDEX email_jobs_expiry_uq ON email_jobs (event_id, kind)
  WHERE kind IN ('expiry_60d', 'expiry_80d', 'expiry_7d_left', 'grace_started', 'archived');

-- ---------------------------------------------------------------------------
-- Support & moderation
-- ---------------------------------------------------------------------------
CREATE TABLE support_tickets (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind        ticket_kind NOT NULL,
  status      ticket_status NOT NULL DEFAULT 'open',
  title       text NOT NULL,
  body        text,
  user_id     uuid REFERENCES users(id),
  event_id    uuid REFERENCES events(id),
  order_id    uuid REFERENCES orders(id),
  assigned_to uuid REFERENCES users(id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);
CREATE INDEX support_tickets_queue_idx ON support_tickets (status, kind, created_at DESC);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$ LANGUAGE plpgsql;

CREATE TRIGGER events_touch    BEFORE UPDATE ON events    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER templates_touch BEFORE UPDATE ON templates FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- Guest limit per plan (Essential 50 / Premium 300) enforced on insert.
CREATE OR REPLACE FUNCTION enforce_guest_limit() RETURNS trigger AS $$
DECLARE v_limit integer; v_count integer;
BEGIN
  SELECT p.max_guests INTO v_limit
    FROM events e JOIN plans p ON p.code = COALESCE(e.plan, 'essential')
   WHERE e.id = NEW.event_id;
  SELECT count(*) INTO v_count FROM guests WHERE event_id = NEW.event_id;
  IF v_count >= v_limit THEN
    RAISE EXCEPTION 'Guest limit reached for this plan (%)', v_limit USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER guests_limit BEFORE INSERT ON guests FOR EACH ROW EXECUTE FUNCTION enforce_guest_limit();

-- Keep guest open stats in sync with invitation_opens.
CREATE OR REPLACE FUNCTION apply_open() RETURNS trigger AS $$
BEGIN
  IF NEW.guest_id IS NOT NULL THEN
    UPDATE guests
       SET open_count      = open_count + 1,
           first_opened_at = COALESCE(first_opened_at, NEW.opened_at),
           last_opened_at  = NEW.opened_at
     WHERE id = NEW.guest_id;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER opens_apply AFTER INSERT ON invitation_opens FOR EACH ROW EXECUTE FUNCTION apply_open();

-- Guest edits of their own RSVP are allowed until the deadline.
CREATE OR REPLACE FUNCTION touch_rsvp() RETURNS trigger AS $$
BEGIN
  IF NEW.rsvp IS DISTINCT FROM OLD.rsvp THEN NEW.responded_at := now(); END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER guests_rsvp_touch BEFORE UPDATE ON guests FOR EACH ROW EXECUTE FUNCTION touch_rsvp();
