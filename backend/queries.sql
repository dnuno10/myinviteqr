-- =============================================================================
-- myinviteqr - backend queries (PostgreSQL). Parameters use $1, $2, ...
-- Grouped by screen / job. Requires schema.sql.
-- =============================================================================


-- #############################################################################
-- 1. HOST DASHBOARD  ("Hi, Daniela")
-- #############################################################################

-- 1.1 Featured event card + validity bar ("34 days left", valid until ...)
-- $1 = event id, $2 = user id
SELECT e.id, e.title, c.name AS category, e.starts_at, e.status, e.plan,
       e.published_at, e.expires_at,
       GREATEST(0, CEIL(EXTRACT(EPOCH FROM (e.expires_at - now())) / 86400))::int AS days_left,
       e.grace_ends_at,
       ROUND(100.0 * GREATEST(0, EXTRACT(EPOCH FROM (e.expires_at - now()))) /
             NULLIF(EXTRACT(EPOCH FROM (e.expires_at - e.published_at)), 0), 0) AS pct_time_left,
       -- wizard progress: Event > Template > Edit > Guests > Publish
       true                                                       AS step_event,
       (e.template_id IS NOT NULL)                                AS step_template,
       EXISTS (SELECT 1 FROM event_revisions r WHERE r.event_id = e.id) AS step_edit,
       EXISTS (SELECT 1 FROM guests g WHERE g.event_id = e.id)    AS step_guests,
       (e.published_at IS NOT NULL)                               AS step_publish
  FROM events e
  JOIN event_categories c ON c.id = e.category_id
 WHERE e.id = $1
   AND (e.owner_id = $2 OR EXISTS (SELECT 1 FROM event_co_hosts h WHERE h.event_id = e.id AND h.user_id = $2));

-- 1.2 Stat tiles: confirmed / pending / declined / opens / total guests (+ %)
-- $1 = event id
WITH g AS (
  SELECT count(*)                                  AS invited,
         count(*) FILTER (WHERE rsvp = 'yes')      AS confirmed,
         count(*) FILTER (WHERE rsvp = 'pending')  AS pending,
         count(*) FILTER (WHERE rsvp = 'no')       AS declined,
         count(*) FILTER (WHERE rsvp = 'maybe')    AS maybe,
         count(*) FILTER (WHERE open_count > 0)    AS opened_guests,
         count(*) FILTER (WHERE open_count = 0)    AS not_opened,
         COALESCE(sum(companions) FILTER (WHERE rsvp = 'yes'), 0) AS companions
    FROM guests WHERE event_id = $1
), o AS (SELECT count(*) AS opens FROM invitation_opens WHERE event_id = $1)
SELECT g.*, o.opens,
       g.invited + g.companions                              AS total_people,
       ROUND(100.0 * g.confirmed / NULLIF(g.invited, 0))     AS confirmed_pct,
       ROUND(100.0 * g.pending   / NULLIF(g.invited, 0))     AS pending_pct,
       ROUND(100.0 * g.declined  / NULLIF(g.invited, 0))     AS declined_pct
  FROM g, o;

-- 1.3 RSVP summary chart (last 7 days, one row per day)
-- $1 = event id
SELECT d::date AS day,
       count(g.*) FILTER (WHERE g.rsvp = 'yes')     AS confirmed,
       count(g.*) FILTER (WHERE g.rsvp = 'pending') AS pending,
       count(g.*) FILTER (WHERE g.rsvp = 'no')      AS declined
  FROM generate_series(current_date - 6, current_date, interval '1 day') d
  LEFT JOIN guests g ON g.event_id = $1 AND g.responded_at::date = d::date
 GROUP BY d ORDER BY d;

-- 1.4 Recent activity feed (RSVPs, opens, silent openers), newest first
-- $1 = event id
(SELECT g.full_name, g.responded_at AS occurred_at,
        CASE g.rsvp WHEN 'yes' THEN 'confirmed' WHEN 'no' THEN 'declined' ELSE 'maybe' END AS activity
   FROM guests g WHERE g.event_id = $1 AND g.responded_at IS NOT NULL AND g.rsvp <> 'pending')
UNION ALL
(SELECT g.full_name, o.opened_at, 'opened'
   FROM invitation_opens o JOIN guests g ON g.id = o.guest_id WHERE o.event_id = $1)
UNION ALL
(SELECT g.full_name, g.last_opened_at, 'not_responded'
   FROM guests g WHERE g.event_id = $1 AND g.rsvp = 'pending' AND g.open_count > 0)
ORDER BY occurred_at DESC
LIMIT 10;


-- #############################################################################
-- 2. NEW EVENT  (event type -> template picker)
-- #############################################################################

-- 2.1 Event types
SELECT id, slug, name, icon FROM event_categories WHERE is_active ORDER BY sort_order;

-- 2.2 Template browser with filters (style, color, language, plan) + favorites
-- $1 = category slug, $2 = style|NULL, $3 = color hex|NULL, $4 = language|NULL,
-- $5 = plan|NULL, $6 = user id, $7 = limit, $8 = offset
SELECT t.id, t.name, t.style, t.min_plan, t.palette, t.thumbnail_url, t.languages,
       (f.user_id IS NOT NULL)          AS is_favorite,
       count(*) OVER ()                 AS total_found      -- "36 templates found"
  FROM templates t
  JOIN event_categories c ON c.id = t.category_id AND c.slug = $1
  LEFT JOIN template_favorites f ON f.template_id = t.id AND f.user_id = $6
 WHERE t.status = 'published'
   AND ($2::text IS NULL OR t.style = $2)
   AND ($3::text IS NULL OR t.palette @> to_jsonb($3::text))
   AND ($4::text IS NULL OR $4 = ANY (t.languages))
   AND ($5::plan_code IS NULL OR t.min_plan = $5)
 ORDER BY t.min_plan DESC, t.name
 LIMIT $7 OFFSET $8;

-- 2.3 Create the draft event (free; designing and previewing never require payment)
-- $1 = owner, $2 = category slug, $3 = template id, $4 = title, $5 = language, $6 = starts_at
INSERT INTO events (owner_id, category_id, template_id, title, language, starts_at)
VALUES ($1, (SELECT id FROM event_categories WHERE slug = $2), $3, $4, $5, $6)
RETURNING id, draft_expires_at;

-- 2.4 Favorites: add / remove
INSERT INTO template_favorites (user_id, template_id) VALUES ($1, $2) ON CONFLICT DO NOTHING;
DELETE FROM template_favorites WHERE user_id = $1 AND template_id = $2;


-- #############################################################################
-- 3. EDITOR  (content blocks, autosave, undo / redo)
-- #############################################################################

-- 3.1 Blocks for the left panel, in display order
SELECT id, kind, is_enabled, position, content
  FROM event_blocks WHERE event_id = $1 ORDER BY position;

-- 3.2 Toggle a block on / off
UPDATE event_blocks SET is_enabled = $3 WHERE id = $2 AND event_id = $1;

-- 3.3 Reorder (drag & drop): send [{id, position}, ...] as jsonb
-- $1 = event id, $2 = '[{"id": "...", "position": 0}, ...]'
UPDATE event_blocks b
   SET position = x.position
  FROM jsonb_to_recordset($2::jsonb) AS x(id uuid, position int)
 WHERE b.id = x.id AND b.event_id = $1;

-- 3.4 Autosave: store a snapshot and update the live design
-- $1 = event id, $2 = snapshot jsonb
WITH rev AS (
  INSERT INTO event_revisions (event_id, snapshot) VALUES ($1, $2::jsonb) RETURNING created_at
)
UPDATE events SET design = $2::jsonb -> 'design' WHERE id = $1
RETURNING (SELECT created_at FROM rev) AS autosaved_at;

-- 3.5 Undo = previous snapshot before revision $2
SELECT id, snapshot FROM event_revisions
 WHERE event_id = $1 AND id < $2 ORDER BY id DESC LIMIT 1;

-- 3.6 Redo = next snapshot after revision $2
SELECT id, snapshot FROM event_revisions
 WHERE event_id = $1 AND id > $2 ORDER BY id ASC LIMIT 1;

-- 3.7 Premium-only editor features guard (animations, music, cover video, custom link)
SELECT p.premium_editor, p.custom_slug
  FROM events e JOIN plans p ON p.code = COALESCE(e.plan, 'essential') WHERE e.id = $1;


-- #############################################################################
-- 4. GUESTS & RSVP
-- #############################################################################

-- 4.1 Filter tabs with counters (All / Confirmed / Pending / Declined / Opened / Not opened)
-- $1 = event id
SELECT count(*)                                  AS all_guests,
       count(*) FILTER (WHERE rsvp = 'yes')      AS confirmed,
       count(*) FILTER (WHERE rsvp = 'pending')  AS pending,
       count(*) FILTER (WHERE rsvp = 'no')       AS declined,
       count(*) FILTER (WHERE open_count > 0)    AS opened,
       count(*) FILTER (WHERE open_count = 0)    AS not_opened
  FROM guests WHERE event_id = $1;

-- 4.2 Guest table: search + tab filter
-- $1 = event id, $2 = search text|NULL, $3 = 'all'|'yes'|'pending'|'no'|'opened'|'not_opened'
-- $4 = limit, $5 = offset
SELECT g.id, g.full_name, g.email, g.phone, gr.name AS "group", g.rsvp,
       g.companions, g.last_opened_at, g.personal_token
  FROM guests g
  LEFT JOIN guest_groups gr ON gr.id = g.group_id
 WHERE g.event_id = $1
   AND ($2::text IS NULL OR g.full_name ILIKE '%' || $2 || '%' OR g.email::text ILIKE '%' || $2 || '%')
   AND CASE $3
         WHEN 'yes'        THEN g.rsvp = 'yes'
         WHEN 'pending'    THEN g.rsvp = 'pending'
         WHEN 'no'         THEN g.rsvp = 'no'
         WHEN 'opened'     THEN g.open_count > 0
         WHEN 'not_opened' THEN g.open_count = 0
         ELSE true END
 ORDER BY g.full_name
 LIMIT $4 OFFSET $5;

-- 4.3 Add a guest manually (plan guest limit enforced by trigger)
INSERT INTO guests (event_id, group_id, full_name, email, phone, source)
VALUES ($1, $2, $3, $4, $5, 'manual')
RETURNING id, personal_token;

-- 4.4 CSV / contacts import (bulk upsert; duplicates by email are updated)
-- $1 = event id, $2 = '[{"name":"...","email":"...","phone":"...","group":"Family"}, ...]'
INSERT INTO guest_groups (event_id, name)
SELECT DISTINCT $1::uuid, x."group"
  FROM jsonb_to_recordset($2::jsonb) AS x(name text, email text, phone text, "group" text)
 WHERE x."group" IS NOT NULL
ON CONFLICT (event_id, name) DO NOTHING;

INSERT INTO guests (event_id, group_id, full_name, email, phone, source)
SELECT $1::uuid, gr.id, x.name, x.email, x.phone, 'csv'
  FROM jsonb_to_recordset($2::jsonb) AS x(name text, email text, phone text, "group" text)
  LEFT JOIN guest_groups gr ON gr.event_id = $1 AND gr.name = x."group"
ON CONFLICT (event_id, email) DO UPDATE
   SET full_name = EXCLUDED.full_name, phone = EXCLUDED.phone, group_id = EXCLUDED.group_id;

-- 4.5 Guest responds (public or individual link): 2 taps, editable until the deadline
-- $1 = personal token, $2 = 'yes'|'no'|'maybe', $3 = companions, $4 = message
UPDATE guests g
   SET rsvp = $2::rsvp_status, companions = $3, message = $4
  FROM events e
 WHERE g.personal_token = $1 AND e.id = g.event_id
   AND e.status = 'published'
   AND (e.rsvp_deadline IS NULL OR e.rsvp_deadline > now())
RETURNING g.id, g.rsvp, g.responded_at;

-- 4.6 Custom question answers (Premium)
INSERT INTO rsvp_answers (guest_id, question_id, answer) VALUES ($1, $2, $3)
ON CONFLICT (guest_id, question_id) DO UPDATE SET answer = EXCLUDED.answer;

-- 4.7 Record an invitation open (link / QR / email); trigger updates guest counters
-- $1 = event id, $2 = personal token|NULL, $3 = channel, $4 = device, $5 = country
INSERT INTO invitation_opens (event_id, guest_id, channel, device, country)
VALUES ($1, (SELECT id FROM guests WHERE personal_token = $2), $3, $4, $5);

-- 4.8 Opens chart (opens vs unique guests, last 7 days) - Premium analytics
-- $1 = event id
SELECT d::date AS day,
       count(o.*)                       AS opens,
       count(DISTINCT o.guest_id)       AS unique_guests
  FROM generate_series(current_date - 6, current_date, interval '1 day') d
  LEFT JOIN invitation_opens o ON o.event_id = $1 AND o.opened_at::date = d::date
 GROUP BY d ORDER BY d;

-- 4.9 Pending guests for reminders
-- $1 = event id
SELECT g.id, g.full_name, g.email
  FROM guests g
 WHERE g.event_id = $1 AND g.rsvp = 'pending' AND g.email IS NOT NULL;

-- 4.10 Reminders used vs allowed by plan (Essential = 1, Premium = unlimited / NULL)
-- $1 = event id
SELECT p.max_reminders,
       (SELECT count(DISTINCT j.send_at::date) FROM email_jobs j
         WHERE j.event_id = e.id AND j.kind = 'guest_reminder' AND j.status <> 'cancelled') AS used
  FROM events e JOIN plans p ON p.code = e.plan WHERE e.id = $1;

-- 4.11 Export list (Excel / CSV)
SELECT g.full_name AS "Name", g.email AS "Email", g.phone AS "Phone", gr.name AS "Group",
       g.rsvp AS "RSVP", g.companions AS "Guests", g.message AS "Message", g.last_opened_at AS "Last opened"
  FROM guests g LEFT JOIN guest_groups gr ON gr.id = g.group_id
 WHERE g.event_id = $1 ORDER BY g.full_name;


-- #############################################################################
-- 5. PUBLISH & PAY
-- #############################################################################

-- 5.1 Price quote for the checkout summary
-- $1 = plan, $2 = wants extension (bool), $3 = discount code|NULL
WITH base AS (
  SELECT p.price_cents + CASE WHEN $2::boolean THEN p.extension_price_cents ELSE 0 END AS subtotal
    FROM plans p WHERE p.code = $1::plan_code
), disc AS (
  SELECT d.percent_off, d.amount_off_cents
    FROM discount_codes d
   WHERE d.code = $3 AND d.is_active
     AND (d.valid_until IS NULL OR d.valid_until > now())
     AND (d.max_redemptions IS NULL OR d.redeemed < d.max_redemptions)
), calc AS (
  SELECT b.subtotal,
         LEAST(b.subtotal,
               COALESCE(ROUND(b.subtotal * d.percent_off / 100.0)::int, 0)
             + COALESCE(d.amount_off_cents, 0)) AS discount
    FROM base b LEFT JOIN disc d ON true
)
SELECT subtotal, discount, subtotal - discount AS total FROM calc;

-- 5.2 Create the pending order (the Stripe PaymentIntent id is stored right after)
-- $1 user, $2 event, $3 subtotal, $4 code, $5 discount, $6 total, $7 method, $8 save method, $9 plan
WITH o AS (
  INSERT INTO orders (user_id, event_id, subtotal_cents, discount_code, discount_cents, total_cents,
                      payment_method, save_payment_method)
  VALUES ($1, $2, $3, $4, $5, $6, $7::payment_method, $8) RETURNING id
)
INSERT INTO order_items (order_id, kind, plan, description, amount_cents)
SELECT o.id, 'plan', p.code, p.name || ' plan', p.price_cents
  FROM o, plans p WHERE p.code = $9::plan_code;

-- 5.3 Stripe webhook "payment_intent.succeeded": mark paid AND publish in ONE transaction.
--     Validity starts NOW (publication), not when the draft was created.
-- $1 = payment intent id, $2 = Stripe fee in cents
BEGIN;
  UPDATE orders SET status = 'paid', paid_at = now(), stripe_fee_cents = $2
   WHERE stripe_payment_intent = $1 AND status = 'pending';

  UPDATE discount_codes SET redeemed = redeemed + 1
   WHERE code = (SELECT discount_code FROM orders WHERE stripe_payment_intent = $1);

  -- publish: plan validity (90 days) + 90 days for each extension bought in the same order
  UPDATE events e
     SET status             = 'published',
         plan               = oi.plan,
         published_at       = now(),
         expires_at         = now() + make_interval(days => p.validity_days + COALESCE(ext.days, 0)),
         grace_ends_at      = now() + make_interval(days => p.validity_days + COALESCE(ext.days, 0) + 7),
         host_data_purge_at = now() + make_interval(days => p.validity_days + COALESCE(ext.days, 0))
                                    + interval '12 months'
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id AND oi.kind = 'plan'
    JOIN plans p ON p.code = oi.plan
    LEFT JOIN LATERAL (SELECT sum(extends_days) AS days FROM order_items
                        WHERE order_id = o.id AND kind = 'extension') ext ON true
   WHERE o.stripe_payment_intent = $1 AND e.id = o.event_id AND e.status = 'draft';

  -- receipt + invoice
  INSERT INTO invoices (order_id, number)
  SELECT id, 'INV-' || to_char(now(), 'YYYY') || '-' || lpad(number::text, 6, '0')
    FROM orders WHERE stripe_payment_intent = $1
  ON CONFLICT (order_id) DO NOTHING;
COMMIT;

-- 5.4 Extend validity (+$4.99 / 3 months) after the payment is confirmed.
--     Extends from the CURRENT expiry, or from now if it already expired; also reactivates
--     events that are in the grace period or archived.
-- $1 = order id, $2 = event id
BEGIN;
  INSERT INTO order_items (order_id, kind, plan, description, amount_cents, extends_days)
  SELECT $1, 'extension', e.plan, '3-month extension', p.extension_price_cents, p.extension_days
    FROM events e JOIN plans p ON p.code = e.plan WHERE e.id = $2;

  UPDATE events e
     SET expires_at         = GREATEST(e.expires_at, now()) + make_interval(days => p.extension_days),
         grace_ends_at      = GREATEST(e.expires_at, now()) + make_interval(days => p.extension_days + 7),
         host_data_purge_at = GREATEST(e.expires_at, now()) + make_interval(days => p.extension_days)
                              + interval '12 months',
         status             = 'published',
         archived_at        = NULL
    FROM plans p
   WHERE e.id = $2 AND p.code = e.plan;

  -- cancel obsolete expiry notices; job 6.1 re-schedules them for the new date
  UPDATE email_jobs SET status = 'cancelled'
   WHERE event_id = $2 AND status = 'scheduled'
     AND kind IN ('expiry_60d', 'expiry_80d', 'expiry_7d_left');
COMMIT;

-- 5.5 Upgrade Essential -> Premium paying only the difference ($10 by default)
SELECT (SELECT price_cents FROM plans WHERE code = 'premium')
     - (SELECT price_cents FROM plans WHERE code = 'essential') AS upgrade_price_cents;

-- after the upgrade payment is confirmed:
UPDATE events SET plan = 'premium' WHERE id = $1 AND plan = 'essential';

-- 5.6 Refund eligibility: full refund within 7 days if the invitation has not been sent
-- $1 = order id
SELECT o.id,
       (o.status = 'paid'
        AND o.paid_at > now() - interval '7 days'
        AND NOT EXISTS (SELECT 1 FROM email_jobs j
                         WHERE j.event_id = o.event_id
                           AND j.kind = 'guest_invitation' AND j.status = 'sent')
        AND NOT EXISTS (SELECT 1 FROM refunds r WHERE r.order_id = o.id AND r.status <> 'rejected')
       ) AS eligible,
       o.total_cents
  FROM orders o WHERE o.id = $1;

-- 5.7 Billing history / invoices page
-- $1 = user id
SELECT i.number, i.issued_at, i.pdf_url, o.total_cents, o.status, e.title
  FROM invoices i JOIN orders o ON o.id = i.order_id JOIN events e ON e.id = o.event_id
 WHERE o.user_id = $1 ORDER BY i.issued_at DESC;


-- #############################################################################
-- 6. LIFECYCLE JOBS  (run hourly by a scheduler)
-- #############################################################################

-- 6.1 Schedule expiry notices: day 60 and day 80 of validity, plus 7 days before expiry.
--     Each one carries an "Extend $4.99" button. Idempotent thanks to email_jobs_expiry_uq.
INSERT INTO email_jobs (kind, event_id, to_email, send_at, payload)
SELECT k.kind, e.id, u.email, k.send_at,
       jsonb_build_object('event_title', e.title, 'expires_at', e.expires_at,
                          'extend_url', '/events/' || e.id || '/extend', 'extend_price', '$4.99')
  FROM events e
  JOIN users u ON u.id = e.owner_id
  CROSS JOIN LATERAL (VALUES
      ('expiry_60d'::email_kind,      e.published_at + interval '60 days'),
      ('expiry_80d'::email_kind,      e.published_at + interval '80 days'),
      ('expiry_7d_left'::email_kind,  e.expires_at   - interval '7 days')
  ) AS k(kind, send_at)
 WHERE e.status = 'published' AND k.send_at > now() AND k.send_at < e.expires_at
ON CONFLICT DO NOTHING;

-- 6.2 Dispatch due emails (workers claim rows without blocking each other)
SELECT * FROM email_jobs
 WHERE status = 'scheduled' AND send_at <= now()
 ORDER BY send_at LIMIT 200 FOR UPDATE SKIP LOCKED;

-- 6.3 Expired -> grace period. The public page shows "This event has ended", never an error.
UPDATE events SET status = 'grace'
 WHERE status = 'published' AND expires_at <= now();

-- 6.4 Grace over -> archive mode (read-only; host data kept 12 months)
UPDATE events SET status = 'archived', archived_at = now()
 WHERE status = 'grace' AND grace_ends_at <= now();

-- 6.5 Purge host data 12 months after expiry (events with an active Keepsake are kept)
DELETE FROM guests WHERE event_id IN (
  SELECT id FROM events
   WHERE status = 'archived' AND host_data_purge_at <= now()
     AND (keepsake_until IS NULL OR keepsake_until < now()));

-- 6.6 Drafts that were never paid are removed after 60 days
UPDATE events SET status = 'deleted' WHERE status = 'draft' AND draft_expires_at <= now();

-- 6.7 Public invitation lookup (guest view). Returns a has_ended flag instead of a 404.
-- $1 = slug or public token
SELECT e.id, e.title, e.starts_at, e.language, e.design, e.noindex, e.cover_image_url,
       (e.status IN ('grace', 'archived') OR e.expires_at <= now()) AS has_ended,
       (SELECT NOT p.remove_branding FROM plans p WHERE p.code = e.plan) AS show_branding
  FROM events e
 WHERE (e.slug = $1 OR e.public_token = $1) AND e.status IN ('published', 'grace', 'archived');


-- #############################################################################
-- 7. INTERNAL ADMINISTRATION
-- #############################################################################

-- 7.1 KPI row: sales this month (+ change vs last month), published events, extensions,
--     refunds, open tickets
WITH m AS (
  SELECT
    COALESCE(sum(total_cents) FILTER (WHERE paid_at >= date_trunc('month', now())), 0) AS sales_cur,
    COALESCE(sum(total_cents) FILTER (WHERE paid_at >= date_trunc('month', now()) - interval '1 month'
                                        AND paid_at <  date_trunc('month', now())), 0) AS sales_prev,
    count(*) FILTER (WHERE paid_at >= date_trunc('month', now()))                      AS orders_cur
    FROM orders WHERE status IN ('paid', 'partially_refunded')
)
SELECT sales_cur / 100.0 AS sales_month, orders_cur,
       ROUND(100.0 * (sales_cur - sales_prev) / NULLIF(sales_prev, 0), 0) AS sales_change_pct,
       (SELECT count(*) FROM events WHERE published_at >= date_trunc('month', now()))      AS published_month,
       (SELECT count(*) FROM events WHERE published_at IS NOT NULL)                         AS published_total,
       (SELECT count(*) FROM order_items oi JOIN orders o ON o.id = oi.order_id
         WHERE oi.kind = 'extension' AND o.status IN ('paid', 'partially_refunded')
           AND o.paid_at >= date_trunc('month', now()))                                     AS extensions_month,
       (SELECT count(*) FROM refunds WHERE requested_at >= date_trunc('month', now()))     AS refunds_month,
       (SELECT count(*) FROM support_tickets WHERE status IN ('open', 'in_progress'))      AS open_tickets
  FROM m;

-- 7.2 Template management table (search + category + status)
-- $1 = search|NULL, $2 = category slug|NULL, $3 = status|NULL
SELECT t.id, t.thumbnail_url, t.name, c.name AS category, t.style,
       (SELECT string_agg(upper(l), ' / ') FROM unnest(t.languages) AS l) AS languages,
       CASE t.min_plan WHEN 'premium' THEN 'Premium' ELSE 'Essential / Premium' END AS plan,
       t.status
  FROM templates t JOIN event_categories c ON c.id = t.category_id
 WHERE ($1::text IS NULL OR t.name ILIKE '%' || $1 || '%')
   AND ($2::text IS NULL OR c.slug = $2)
   AND ($3::template_status IS NULL OR t.status = $3)
 ORDER BY t.updated_at DESC;

-- 7.3 Support & moderation queue: tab counters, then the list
SELECT count(*)                                            AS all_open,
       count(*) FILTER (WHERE kind = 'moderation')         AS reports,
       count(*) FILTER (WHERE kind = 'refund')             AS refunds,
       count(*) FILTER (WHERE kind IN ('support', 'extension')) AS inquiries
  FROM support_tickets WHERE status IN ('open', 'in_progress');

-- $1 = kind|NULL
SELECT t.id, t.kind, t.title, t.body, t.created_at, o.number AS order_number
  FROM support_tickets t LEFT JOIN orders o ON o.id = t.order_id
 WHERE t.status IN ('open', 'in_progress') AND ($1::ticket_kind IS NULL OR t.kind = $1)
 ORDER BY t.created_at DESC LIMIT 50;

-- 7.4 Process a refund (admin). A full refund returns the event to draft.
-- $1 = refund id, $2 = admin user id, $3 = Stripe refund id
BEGIN;
  UPDATE refunds SET status = 'processed', processed_at = now(), processed_by = $2, stripe_refund_id = $3
   WHERE id = $1;

  UPDATE orders o
     SET status = CASE WHEN r.amount_cents >= o.total_cents THEN 'refunded'::order_status
                       ELSE 'partially_refunded'::order_status END
    FROM refunds r WHERE r.id = $1 AND o.id = r.order_id;

  UPDATE events e
     SET status = 'draft', published_at = NULL, expires_at = NULL,
         grace_ends_at = NULL, host_data_purge_at = NULL
    FROM refunds r JOIN orders o ON o.id = r.order_id
   WHERE r.id = $1 AND e.id = o.event_id AND r.amount_cents >= o.total_cents;
COMMIT;

-- 7.5 Sales by plan (last 30 days): share per bucket + daily series for the bar chart
SELECT CASE WHEN oi.kind IN ('plan', 'upgrade') AND oi.plan = 'essential' THEN 'Essential'
            WHEN oi.kind IN ('plan', 'upgrade')                           THEN 'Premium'
            WHEN oi.kind = 'extension'                                    THEN 'Extension'
            ELSE 'Keepsake' END                              AS bucket,
       sum(oi.amount_cents) / 100.0                          AS revenue,
       ROUND(100.0 * sum(oi.amount_cents) / sum(sum(oi.amount_cents)) OVER (), 0) AS share_pct
  FROM order_items oi JOIN orders o ON o.id = oi.order_id
 WHERE o.status IN ('paid', 'partially_refunded') AND o.paid_at >= now() - interval '30 days'
 GROUP BY 1 ORDER BY revenue DESC;

SELECT o.paid_at::date AS day,
       sum(oi.amount_cents) FILTER (WHERE oi.kind = 'plan' AND oi.plan = 'essential') / 100.0 AS essential,
       sum(oi.amount_cents) FILTER (WHERE (oi.kind = 'plan' AND oi.plan = 'premium') OR oi.kind = 'upgrade') / 100.0 AS premium,
       sum(oi.amount_cents) FILTER (WHERE oi.kind = 'extension') / 100.0 AS extension,
       sum(oi.amount_cents) FILTER (WHERE oi.kind = 'keepsake')  / 100.0 AS keepsake
  FROM order_items oi JOIN orders o ON o.id = oi.order_id
 WHERE o.status IN ('paid', 'partially_refunded') AND o.paid_at >= now() - interval '30 days'
 GROUP BY 1 ORDER BY 1;

-- 7.6 Expirations & automated emails panel
SELECT count(*) FILTER (WHERE status = 'published' AND expires_at >  now() + interval '30 days' AND expires_at <= now() + interval '60 days') AS expiring_60d,
       count(*) FILTER (WHERE status = 'published' AND expires_at >  now() + interval '7 days'  AND expires_at <= now() + interval '30 days') AS expiring_30d,
       count(*) FILTER (WHERE status = 'published' AND expires_at >  now()                      AND expires_at <= now() + interval '7 days')  AS expiring_7d,
       count(*) FILTER (WHERE status IN ('grace', 'archived'))                                                                                AS expired_archived
  FROM events;
