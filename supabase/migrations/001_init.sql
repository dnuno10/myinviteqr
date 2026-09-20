-- =============================================================================
-- myinviteqr - Supabase migration 001
-- Paste the whole file in Supabase > SQL Editor > Run.
--
-- !! This REPLACES the first schema (backend/schema.sql) that was created before
-- !! Supabase Auth was wired in. Section 0 drops those objects (and any rows in
-- !! them). It is safe to run more than once.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0. Clean up the previous schema
-- ---------------------------------------------------------------------------
drop table if exists
  album_photos, rsvp_answers, rsvp_questions, invitation_opens, email_jobs, invoices,
  refunds, order_items, orders, discount_codes, support_tickets, gift_links, event_co_hosts,
  event_revisions, event_blocks, event_sub_events, guests, guest_groups, template_favorites,
  events, templates, font_pairs, event_categories, plans, auth_identities, users, profiles
  cascade;
drop function if exists touch_updated_at(), enforce_guest_limit(), apply_open(), touch_rsvp() cascade;
drop type if exists user_role, auth_provider, plan_code, event_status, template_status, rsvp_status,
  order_status, order_item_kind, payment_method, refund_status, ticket_kind, ticket_status,
  email_kind, email_status, block_kind, question_type cascade;

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null,
  full_name   text,
  role        text not null default 'host' check (role in ('host', 'admin')),
  locale      text not null default 'en' check (locale in ('en', 'es')),
  created_at  timestamptz not null default now()
);

create table plans (
  code                  text primary key,
  name                  text not null,
  price_cents           integer not null,
  validity_days         integer not null default 90,
  extension_price_cents integer not null default 499,
  extension_days        integer not null default 90,
  max_guests            integer not null,
  max_reminders         integer,
  max_co_hosts          integer not null default 0,
  custom_slug           boolean not null default false,
  individual_links      boolean not null default false,
  custom_questions      boolean not null default false,
  open_analytics        boolean not null default false,
  shared_album          boolean not null default false,
  gift_list             boolean not null default false,
  multiple_sub_events   boolean not null default false,
  remove_branding       boolean not null default false,
  premium_editor        boolean not null default false
);

create table event_categories (
  id          serial primary key,
  slug        text unique not null,
  name        text not null,
  icon        text,
  sort_order  integer not null default 0,
  is_active   boolean not null default true
);

create table templates (
  id            uuid primary key default gen_random_uuid(),
  category_id   integer not null references event_categories(id),
  name          text not null,
  style         text not null,
  languages     text[] not null default '{en}',
  min_plan      text not null default 'essential' references plans(code),
  palette       jsonb not null default '[]',
  layout        jsonb not null default '{}',   -- {"art","bg","ink","accent"}
  status        text not null default 'draft' check (status in ('draft', 'in_review', 'published', 'retired')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index templates_browse_idx on templates (category_id, status);

create table events (
  id               uuid primary key default gen_random_uuid(),
  owner_id         uuid not null references profiles(id) on delete cascade,
  category_id      integer references event_categories(id),
  template_id      uuid references templates(id),
  title            text not null default '',
  language         text not null default 'en' check (language in ('en', 'es')),
  plan             text references plans(code),
  status           text not null default 'draft' check (status in ('draft', 'published', 'grace', 'archived')),
  starts_at        timestamptz,
  venue_name       text,
  venue_address    text,
  rsvp_deadline    timestamptz,
  design           jsonb not null default '{}',
  public_token     text not null unique default substr(replace(gen_random_uuid()::text, '-', ''), 1, 16),
  noindex          boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  draft_expires_at timestamptz not null default now() + interval '60 days',
  published_at     timestamptz,
  expires_at       timestamptz,
  grace_ends_at    timestamptz,
  archived_at      timestamptz
);
create index events_owner_idx  on events (owner_id, status);
create index events_expiry_idx on events (status, expires_at);

create table event_blocks (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references events(id) on delete cascade,
  kind        text not null,
  is_enabled  boolean not null default true,
  position    integer not null,
  content     jsonb not null default '{}',
  unique (event_id, kind)
);

create table guests (
  id              uuid primary key default gen_random_uuid(),
  event_id        uuid not null references events(id) on delete cascade,
  full_name       text not null,
  email           text,
  phone           text,
  group_name      text,
  personal_token  text not null unique default substr(replace(gen_random_uuid()::text, '-', ''), 1, 16),
  rsvp            text not null default 'pending' check (rsvp in ('pending', 'yes', 'no', 'maybe')),
  companions      smallint not null default 0 check (companions between 0 and 20),
  message         text,
  responded_at    timestamptz,
  first_opened_at timestamptz,
  last_opened_at  timestamptz,
  open_count      integer not null default 0,
  source          text not null default 'manual',
  created_at      timestamptz not null default now()
);
create index guests_event_idx on guests (event_id, rsvp);
create unique index guests_email_uq on guests (event_id, lower(email)) where email is not null;

create table invitation_opens (
  id         bigserial primary key,
  event_id   uuid not null references events(id) on delete cascade,
  guest_id   uuid references guests(id) on delete set null,
  opened_at  timestamptz not null default now(),
  channel    text
);
create index invitation_opens_idx on invitation_opens (event_id, opened_at desc);

create table discount_codes (
  code             text primary key,             -- stored upper-case
  percent_off      smallint check (percent_off between 1 and 100),
  amount_off_cents integer check (amount_off_cents > 0),
  max_redemptions  integer,
  redeemed         integer not null default 0,
  valid_until      timestamptz,
  is_active        boolean not null default true,
  check (percent_off is not null or amount_off_cents is not null)
);

create table orders (
  id              uuid primary key default gen_random_uuid(),
  number          bigint generated always as identity unique,
  user_id         uuid not null references profiles(id),
  event_id        uuid not null references events(id) on delete cascade,
  kind            text not null check (kind in ('publish', 'extension', 'upgrade')),
  status          text not null default 'pending' check (status in ('pending', 'paid', 'failed', 'refunded')),
  subtotal_cents  integer not null,
  discount_code   text references discount_codes(code),
  discount_cents  integer not null default 0,
  total_cents     integer not null,
  currency        char(3) not null default 'USD',
  provider        text not null default 'manual',   -- 'manual' until Stripe is connected
  provider_ref    text,
  created_at      timestamptz not null default now(),
  paid_at         timestamptz
);
create index orders_idx on orders (status, paid_at);

create table order_items (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references orders(id) on delete cascade,
  kind         text not null check (kind in ('plan', 'upgrade', 'extension', 'keepsake')),
  plan         text references plans(code),
  description  text not null,
  amount_cents integer not null,
  extends_days integer
);

create table refunds (
  id            uuid primary key default gen_random_uuid(),
  order_id      uuid not null references orders(id),
  amount_cents  integer not null,
  reason        text,
  status        text not null default 'requested' check (status in ('requested', 'approved', 'rejected', 'processed')),
  requested_at  timestamptz not null default now(),
  processed_at  timestamptz
);

create table support_tickets (
  id          uuid primary key default gen_random_uuid(),
  kind        text not null default 'support' check (kind in ('refund', 'moderation', 'support', 'extension')),
  status      text not null default 'open' check (status in ('open', 'in_progress', 'resolved', 'closed')),
  title       text not null,
  body        text,
  user_id     uuid references profiles(id),
  event_id    uuid references events(id) on delete set null,
  created_at  timestamptz not null default now(),
  resolved_at timestamptz
);
create index support_tickets_idx on support_tickets (status, kind, created_at desc);

-- ---------------------------------------------------------------------------
-- 2. Helper functions
-- ---------------------------------------------------------------------------
create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as
$$ select exists (select 1 from profiles where id = auth.uid() and role = 'admin') $$;

create or replace function public.my_role() returns text
language sql security definer stable set search_path = public as
$$ select role from profiles where id = auth.uid() $$;

create or replace function public.owns_event(p_event uuid) returns boolean
language sql security definer stable set search_path = public as
$$ select exists (select 1 from events where id = p_event and owner_id = auth.uid()) $$;

-- profile row is created automatically for every new auth user
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, email) values (new.id, coalesce(new.email, '')) on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

insert into profiles (id, email)
select id, coalesce(email, '') from auth.users on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 3. Triggers
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;
create trigger events_touch    before update on events    for each row execute function touch_updated_at();
create trigger templates_touch before update on templates for each row execute function touch_updated_at();

-- Hosts can never change plan / status / dates directly: only the RPCs below can.
create or replace function public.protect_event_columns() returns trigger
language plpgsql as $$
begin
  if coalesce(current_setting('app.privileged', true), '') <> '1' and not public.is_admin() then
    if new.status is distinct from old.status or new.plan is distinct from old.plan
       or new.published_at is distinct from old.published_at or new.expires_at is distinct from old.expires_at
       or new.grace_ends_at is distinct from old.grace_ends_at or new.archived_at is distinct from old.archived_at
       or new.owner_id is distinct from old.owner_id or new.public_token is distinct from old.public_token then
      raise exception 'These fields can only be changed by publishing or extending the event' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
create trigger events_protect before update on events for each row execute function protect_event_columns();

create or replace function public.enforce_guest_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_limit integer; v_count integer;
begin
  select p.max_guests into v_limit
    from events e join plans p on p.code = coalesce(e.plan, 'essential') where e.id = new.event_id;
  select count(*) into v_count from guests where event_id = new.event_id;
  if v_count >= v_limit then
    raise exception 'Guest limit reached for this plan (%)', v_limit using errcode = 'check_violation';
  end if;
  return new;
end $$;
create trigger guests_limit before insert on guests for each row execute function enforce_guest_limit();

create or replace function public.touch_rsvp() returns trigger language plpgsql as $$
begin
  if new.rsvp is distinct from old.rsvp then new.responded_at := now(); end if;
  return new;
end $$;
create trigger guests_rsvp_touch before update on guests for each row execute function touch_rsvp();

create or replace function public.apply_open() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.guest_id is not null then
    update guests set open_count = open_count + 1,
                      first_opened_at = coalesce(first_opened_at, new.opened_at),
                      last_opened_at = new.opened_at
     where id = new.guest_id;
  end if;
  return new;
end $$;
create trigger opens_apply after insert on invitation_opens for each row execute function apply_open();

-- ---------------------------------------------------------------------------
-- 4. Seed data (catalog only; no demo events / guests)
-- ---------------------------------------------------------------------------
insert into plans (code, name, price_cents, max_guests, max_reminders, max_co_hosts, custom_slug,
                   individual_links, custom_questions, open_analytics, shared_album, gift_list,
                   multiple_sub_events, remove_branding, premium_editor)
values
  ('essential', 'Essential',  999,  50, 1,    0, false, false, false, false, false, false, false, false, false),
  ('premium',   'Premium',   1999, 300, null, 3, true,  true,  true,  true,  true,  true,  true,  true,  true);

insert into event_categories (slug, name, icon, sort_order) values
  ('birthday', 'Birthday', 'cake', 1), ('baby_shower', 'Baby shower', 'child', 2),
  ('wedding', 'Wedding', 'ring', 3), ('anniversary', 'Anniversary', 'heart', 4),
  ('graduation', 'Graduation', 'school', 5), ('farewell', 'Farewell', 'glass', 6),
  ('gender_reveal', 'Gender reveal', 'rainbow', 7), ('quinceanera', 'Quinceañera', 'dress', 8),
  ('baptism_communion', 'Baptism & communion', 'church', 9), ('year_end_party', 'Year-end party', 'party', 10),
  ('corporate', 'Corporate', 'work', 11), ('trip', 'Trip', 'flight', 12),
  ('dinner_gathering', 'Dinner or get-together', 'dinner', 13), ('other', 'Other', 'more', 14);

-- Six closed template designs for every event type
insert into templates (category_id, name, style, languages, min_plan, palette, layout, status)
select c.id, s.name, s.style, s.languages, s.min_plan, s.palette::jsonb, s.layout::jsonb, 'published'
  from event_categories c
 cross join (values
  ('Romantic Floral', 'romantic',   '{en,es}'::text[], 'premium',
   '["#F3C9CE","#A89886","#E9E4DD"]', '{"art":"floral","bg":"#FCEFEC","ink":"#5B3A3A","accent":"#E94B6F"}'),
  ('Minimal',         'minimalist', '{en,es}'::text[], 'essential',
   '["#7A7358","#EDE4D8","#8A7FD6"]', '{"art":"minimal","bg":"#FAF6F0","ink":"#3B3B3B","accent":"#7A7358"}'),
  ('Botanical',       'botanical',  '{en,es}'::text[], 'essential',
   '["#6B7A55","#D5D1C5","#2F4A38"]', '{"art":"botanical","bg":"#F7F4EC","ink":"#3A3A34","accent":"#6F8F5F"}'),
  ('Elegant',         'elegant',    '{en,es}'::text[], 'premium',
   '["#E4E0D8","#1E1E22","#E2C9B0"]', '{"art":"elegant","bg":"#15120E","ink":"#FFFFFF","accent":"#E2C9B0"}'),
  ('Sunset',          'modern',     '{en}'::text[],    'essential',
   '["#B5C9C4","#9A6A3C","#8A7FD6"]', '{"art":"sunset","bg":"#FCEBD9","ink":"#7A4B30","accent":"#C97B4A"}'),
  ('Bilingual',       'modern',     '{en,es}'::text[], 'premium',
   '["#E3E0E6","#8A7FD6","#E2C9B0"]', '{"art":"bilingual","bg":"#E3E0E6","ink":"#2B2D42","accent":"#8A7FD6"}')
 ) as s(name, style, languages, min_plan, palette, layout);

-- ---------------------------------------------------------------------------
-- 5. Row level security
-- ---------------------------------------------------------------------------
alter table profiles          enable row level security;
alter table plans             enable row level security;
alter table event_categories  enable row level security;
alter table templates         enable row level security;
alter table events            enable row level security;
alter table event_blocks      enable row level security;
alter table guests            enable row level security;
alter table invitation_opens  enable row level security;
alter table discount_codes    enable row level security;
alter table orders            enable row level security;
alter table order_items       enable row level security;
alter table refunds           enable row level security;
alter table support_tickets   enable row level security;

create policy profiles_select on profiles for select to authenticated using (id = auth.uid() or is_admin());
create policy profiles_update on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid() and role = public.my_role());

create policy plans_read      on plans            for select to anon, authenticated using (true);
create policy categories_read on event_categories for select to anon, authenticated using (true);
create policy templates_read  on templates        for select to anon, authenticated using (status = 'published');
create policy templates_admin on templates        for all to authenticated using (is_admin()) with check (is_admin());

create policy events_select on events for select to authenticated using (owner_id = auth.uid() or is_admin());
create policy events_insert on events for insert to authenticated
  with check (owner_id = auth.uid() and status = 'draft' and plan is null and published_at is null);
create policy events_update on events for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy events_delete on events for delete to authenticated
  using (owner_id = auth.uid() and status = 'draft');

create policy blocks_all on event_blocks for all to authenticated
  using (owns_event(event_id)) with check (owns_event(event_id));
create policy guests_all on guests for all to authenticated
  using (owns_event(event_id)) with check (owns_event(event_id));
create policy opens_select on invitation_opens for select to authenticated using (owns_event(event_id));

create policy orders_select on orders for select to authenticated using (user_id = auth.uid() or is_admin());
create policy order_items_select on order_items for select to authenticated
  using (exists (select 1 from orders o where o.id = order_id and (o.user_id = auth.uid() or is_admin())));
create policy refunds_admin on refunds for select to authenticated using (is_admin());

create policy tickets_select on support_tickets for select to authenticated using (user_id = auth.uid() or is_admin());
create policy tickets_insert on support_tickets for insert to authenticated with check (user_id = auth.uid());
create policy tickets_admin_update on support_tickets for update to authenticated using (is_admin()) with check (is_admin());
-- discount_codes: no policies on purpose (only the RPCs read them)

grant usage on schema public to anon, authenticated;
grant select on plans, event_categories, templates to anon, authenticated;
grant select, update on profiles to authenticated;
grant select, insert, update, delete on events, event_blocks, guests to authenticated;
grant select on invitation_opens, orders, order_items, refunds to authenticated;
grant select, insert, update on support_tickets to authenticated;
grant insert, update, delete on templates to authenticated;   -- admin only via policy
grant usage, select on all sequences in schema public to authenticated;

-- ---------------------------------------------------------------------------
-- 6. RPC: pricing, publish, extend
-- ---------------------------------------------------------------------------
create or replace function public.quote_order(p_plan text, p_extension boolean, p_code text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_price integer; v_ext integer; v_sub integer; v_disc integer := 0; d discount_codes%rowtype;
  v_code text := upper(nullif(trim(coalesce(p_code, '')), ''));
begin
  select price_cents, extension_price_cents into v_price, v_ext from plans where code = p_plan;
  if v_price is null then raise exception 'Unknown plan'; end if;
  v_sub := v_price + case when p_extension then v_ext else 0 end;
  if v_code is not null then
    select * into d from discount_codes
     where code = v_code and is_active
       and (valid_until is null or valid_until > now())
       and (max_redemptions is null or redeemed < max_redemptions);
    if d.code is null then raise exception 'This discount code is not valid'; end if;
    v_disc := least(v_sub, coalesce(round(v_sub * d.percent_off / 100.0)::int, 0) + coalesce(d.amount_off_cents, 0));
  end if;
  return jsonb_build_object('subtotal', v_sub, 'discount', v_disc, 'total', v_sub - v_disc, 'code', v_code);
end $$;

-- Payments are not connected yet (Stripe): the order is recorded as 'pending' with provider 'manual'
-- and the event is published anyway. Switch the order to 'paid' from the Stripe webhook later.
create or replace function public.publish_event(p_event uuid, p_plan text, p_extension boolean, p_code text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  e events%rowtype; pl plans%rowtype; q jsonb; v_order uuid; v_days integer; v_guests integer;
begin
  select * into e from events where id = p_event and owner_id = auth.uid() for update;
  if e.id is null then raise exception 'Event not found'; end if;
  if e.status <> 'draft' then raise exception 'This event is already published'; end if;
  if coalesce(trim(e.title), '') = '' then raise exception 'Add a title before publishing'; end if;
  if e.template_id is null then raise exception 'Choose a template before publishing'; end if;
  if e.starts_at is null then raise exception 'Add the event date before publishing'; end if;
  select * into pl from plans where code = p_plan;
  if pl.code is null then raise exception 'Unknown plan'; end if;
  if p_plan <> 'premium' and exists (select 1 from templates t where t.id = e.template_id and t.min_plan = 'premium') then
    raise exception 'This template requires the Premium plan';
  end if;
  select count(*) into v_guests from guests where event_id = e.id;
  if v_guests > pl.max_guests then
    raise exception 'The % plan allows up to % guests (you have %)', pl.name, pl.max_guests, v_guests;
  end if;

  q := quote_order(p_plan, p_extension, p_code);
  v_days := pl.validity_days + case when p_extension then pl.extension_days else 0 end;

  insert into orders (user_id, event_id, kind, subtotal_cents, discount_code, discount_cents, total_cents)
  values (auth.uid(), e.id, 'publish', (q->>'subtotal')::int, q->>'code', (q->>'discount')::int, (q->>'total')::int)
  returning id into v_order;
  insert into order_items (order_id, kind, plan, description, amount_cents)
  values (v_order, 'plan', p_plan, pl.name || ' plan', pl.price_cents);
  if p_extension then
    insert into order_items (order_id, kind, plan, description, amount_cents, extends_days)
    values (v_order, 'extension', p_plan, '3-month extension', pl.extension_price_cents, pl.extension_days);
  end if;
  if q->>'code' is not null then update discount_codes set redeemed = redeemed + 1 where code = q->>'code'; end if;

  perform set_config('app.privileged', '1', true);
  update events set status = 'published', plan = p_plan, published_at = now(),
         expires_at = now() + make_interval(days => v_days),
         grace_ends_at = now() + make_interval(days => v_days + 7)
   where id = e.id;
  return jsonb_build_object('order_id', v_order, 'total', (q->>'total')::int);
end $$;

create or replace function public.extend_event(p_event uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare e events%rowtype; pl plans%rowtype; v_order uuid; v_new timestamptz;
begin
  select * into e from events where id = p_event and owner_id = auth.uid() for update;
  if e.id is null then raise exception 'Event not found'; end if;
  if e.status = 'draft' or e.plan is null then raise exception 'Publish the event first'; end if;
  select * into pl from plans where code = e.plan;
  v_new := greatest(coalesce(e.expires_at, now()), now()) + make_interval(days => pl.extension_days);
  insert into orders (user_id, event_id, kind, subtotal_cents, total_cents)
  values (auth.uid(), e.id, 'extension', pl.extension_price_cents, pl.extension_price_cents) returning id into v_order;
  insert into order_items (order_id, kind, plan, description, amount_cents, extends_days)
  values (v_order, 'extension', e.plan, '3-month extension', pl.extension_price_cents, pl.extension_days);
  perform set_config('app.privileged', '1', true);
  update events set expires_at = v_new, grace_ends_at = v_new + interval '7 days',
         status = 'published', archived_at = null where id = e.id;
  return jsonb_build_object('order_id', v_order, 'expires_at', v_new);
end $$;

-- ---------------------------------------------------------------------------
-- 7. RPC: guests import (respects the plan limit, skips duplicates)
-- ---------------------------------------------------------------------------
create or replace function public.import_guests(p_event uuid, p_rows jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r jsonb; v_limit integer; v_count integer; v_ins integer := 0; v_dup integer := 0; v_over integer := 0;
  v_rows integer; v_name text; v_email text;
begin
  if not owns_event(p_event) then raise exception 'Event not found'; end if;
  select p.max_guests into v_limit from events e join plans p on p.code = coalesce(e.plan, 'essential') where e.id = p_event;
  select count(*) into v_count from guests where event_id = p_event;
  for r in select * from jsonb_array_elements(p_rows) loop
    v_name  := nullif(trim(coalesce(r->>'name', '')), '');
    v_email := lower(nullif(trim(coalesce(r->>'email', '')), ''));
    if v_name is null then continue; end if;
    if v_count >= v_limit then v_over := v_over + 1; continue; end if;
    insert into guests (event_id, full_name, email, phone, group_name, source)
    values (p_event, v_name, v_email, nullif(trim(coalesce(r->>'phone', '')), ''),
            nullif(trim(coalesce(r->>'group', '')), ''), coalesce(r->>'source', 'manual'))
    on conflict (event_id, lower(email)) where email is not null do nothing;
    get diagnostics v_rows = row_count;
    if v_rows = 1 then v_ins := v_ins + 1; v_count := v_count + 1; else v_dup := v_dup + 1; end if;
  end loop;
  return jsonb_build_object('inserted', v_ins, 'duplicates', v_dup, 'over_limit', v_over);
end $$;

-- ---------------------------------------------------------------------------
-- 8. RPC: public invitation (used by guests, no account needed)
-- ---------------------------------------------------------------------------
create or replace function public.get_public_invitation(p_token text, p_guest text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare e events%rowtype; g guests%rowtype; t templates%rowtype; v_ended boolean; v_brand boolean; v_blocks jsonb;
begin
  select * into e from events where public_token = p_token and status in ('published', 'grace', 'archived');
  if e.id is null then return null; end if;
  v_ended := e.status <> 'published' or coalesce(e.expires_at <= now(), false);
  if p_guest is not null then select * into g from guests where personal_token = p_guest and event_id = e.id; end if;
  if not v_ended then
    insert into invitation_opens (event_id, guest_id, channel) values (e.id, g.id, case when g.id is null then 'link' else 'personal' end);
  end if;
  select * into t from templates where id = e.template_id;
  select coalesce(remove_branding, false) into v_brand from plans where code = e.plan;
  select coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'content', content) order by position), '[]'::jsonb)
    into v_blocks from event_blocks where event_id = e.id and is_enabled;
  return jsonb_build_object(
    'event', jsonb_build_object('id', e.id, 'title', e.title, 'starts_at', e.starts_at, 'venue_name', e.venue_name,
                                'venue_address', e.venue_address, 'language', e.language, 'design', e.design,
                                'rsvp_deadline', e.rsvp_deadline, 'public_token', e.public_token),
    'layout', coalesce(t.layout, '{}'::jsonb),
    'blocks', v_blocks,
    'has_ended', v_ended,
    'show_branding', not coalesce(v_brand, false),
    'rsvp_open', not v_ended and (e.rsvp_deadline is null or e.rsvp_deadline > now()),
    'guest', case when g.id is null then null else jsonb_build_object(
        'name', g.full_name, 'rsvp', g.rsvp, 'companions', g.companions, 'message', g.message,
        'token', g.personal_token) end);
end $$;

create or replace function public.submit_rsvp(p_token text, p_guest text, p_name text, p_email text,
                                              p_rsvp text, p_companions integer, p_message text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare e events%rowtype; g guests%rowtype; v_email text := lower(nullif(trim(coalesce(p_email, '')), ''));
begin
  if p_rsvp not in ('yes', 'no', 'maybe') then raise exception 'Choose yes, no or maybe'; end if;
  select * into e from events where public_token = p_token and status = 'published' and expires_at > now();
  if e.id is null then raise exception 'This event has ended'; end if;
  if e.rsvp_deadline is not null and e.rsvp_deadline <= now() then raise exception 'The RSVP deadline has passed'; end if;
  if p_guest is not null then select * into g from guests where personal_token = p_guest and event_id = e.id; end if;
  if g.id is null and v_email is not null then select * into g from guests where event_id = e.id and lower(email) = v_email; end if;
  if g.id is null then
    if nullif(trim(coalesce(p_name, '')), '') is null then raise exception 'Please enter your name'; end if;
    insert into guests (event_id, full_name, email, rsvp, companions, message, source)
    values (e.id, trim(p_name), v_email, p_rsvp, least(greatest(coalesce(p_companions, 0), 0), 20), p_message, 'public_link')
    returning * into g;
  else
    update guests set rsvp = p_rsvp, companions = least(greatest(coalesce(p_companions, 0), 0), 20), message = p_message,
           full_name = coalesce(nullif(trim(coalesce(p_name, '')), ''), full_name)
     where id = g.id returning * into g;
  end if;
  return jsonb_build_object('guest_token', g.personal_token, 'rsvp', g.rsvp);
end $$;

grant execute on function public.get_public_invitation(text, text), public.submit_rsvp(text, text, text, text, text, integer, text)
  to anon, authenticated;
grant execute on function public.quote_order(text, boolean, text), public.publish_event(uuid, text, boolean, text),
  public.extend_event(uuid), public.import_guests(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 9. Admin reports (admins only) and lifecycle job
-- ---------------------------------------------------------------------------
create or replace function public.admin_kpis() returns jsonb
language plpgsql security definer set search_path = public as $$
declare m timestamptz := date_trunc('month', now());
begin
  if not is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  return jsonb_build_object(
    'sales_cents',  coalesce((select sum(total_cents) from orders where status = 'paid' and paid_at >= m), 0),
    'sales_prev_cents', coalesce((select sum(total_cents) from orders where status = 'paid'
                                  and paid_at >= m - interval '1 month' and paid_at < m), 0),
    'orders_month', (select count(*) from orders where created_at >= m),
    'published_month', (select count(*) from events where published_at >= m),
    'published_total', (select count(*) from events where published_at is not null),
    'extensions_month', (select count(*) from orders where kind = 'extension' and created_at >= m),
    'refunds_month', (select count(*) from refunds where requested_at >= m),
    'open_tickets', (select count(*) from support_tickets where status in ('open', 'in_progress')),
    'exp_60', (select count(*) from events where status = 'published' and expires_at >  now() + interval '30 days' and expires_at <= now() + interval '60 days'),
    'exp_30', (select count(*) from events where status = 'published' and expires_at >  now() + interval '7 days'  and expires_at <= now() + interval '30 days'),
    'exp_7',  (select count(*) from events where status = 'published' and expires_at >  now() and expires_at <= now() + interval '7 days'),
    'expired', (select count(*) from events where status in ('grace', 'archived')));
end $$;

create or replace function public.admin_sales_by_bucket() returns table (bucket text, revenue_cents bigint)
language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  return query
  select case when oi.kind in ('plan', 'upgrade') and oi.plan = 'essential' then 'Essential'
              when oi.kind in ('plan', 'upgrade') then 'Premium'
              when oi.kind = 'extension' then 'Extension' else 'Keepsake' end,
         sum(oi.amount_cents)::bigint
    from order_items oi join orders o on o.id = oi.order_id
   where o.status = 'paid' and o.paid_at >= now() - interval '30 days'
   group by 1 order by 2 desc;
end $$;

grant execute on function public.admin_kpis(), public.admin_sales_by_bucket() to authenticated;

-- published -> grace -> archived, and stale drafts removed. Schedule it hourly, e.g. with pg_cron:
--   select cron.schedule('event-lifecycle', '0 * * * *', 'select public.run_event_lifecycle()');
create or replace function public.run_event_lifecycle() returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('app.privileged', '1', true);
  update events set status = 'grace' where status = 'published' and expires_at <= now();
  update events set status = 'archived', archived_at = now() where status = 'grace' and grace_ends_at <= now();
  delete from events where status = 'draft' and draft_expires_at <= now();
end $$;
revoke execute on function public.run_event_lifecycle() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 10. Make yourself an admin (run once, with your own email):
--   update profiles set role = 'admin' where email = 'you@example.com';
-- ---------------------------------------------------------------------------
