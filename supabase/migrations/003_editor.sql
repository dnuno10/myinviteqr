-- =============================================================================
-- myinviteqr - migration 003: free-form editor, colour palettes, photo storage
-- Run AFTER 001/002 and BEFORE 004. Safe to run more than once.
-- =============================================================================

-- 1. Layers: event_blocks now holds free-form layers (text, photo, shape, deco, rsvp, qr).
--    Several layers of the same type are allowed, so the (event_id, kind) uniqueness goes away.
--    Layers written by the first editor have a different shape, so they are removed.
delete from event_blocks;
alter table event_blocks drop constraint if exists event_blocks_event_id_kind_key;
create index if not exists event_blocks_event_pos_idx on event_blocks (event_id, position);

-- 2. Templates are no longer tied to one event type: they list the themes they suit.
alter table templates alter column category_id drop not null;
alter table templates add column if not exists themes text[] not null default '{}';

-- 3. Colour combinations (roles: bg, ink, accent, accent2, soft)
create table if not exists color_palettes (
  id     serial primary key,
  name   text not null,
  tone   text not null default 'light' check (tone in ('light', 'dark', 'vivid')),
  colors jsonb not null
);
alter table color_palettes enable row level security;
drop policy if exists palettes_read on color_palettes;
create policy palettes_read on color_palettes for select to anon, authenticated using (true);
grant select on color_palettes to anon, authenticated;

-- 4. Premium plans allow up to 1,000 guests (the trigger and import RPC read this column)
update plans set max_guests = 1000 where code = 'premium';

-- 5. Any template can be published with any plan
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

-- 6. Photo storage. Public read (invitations are public links); only the owner can write in their own folder:
--    <user id>/<event id>/<file>
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('invitation-media', 'invitation-media', true, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

drop policy if exists invitation_media_read on storage.objects;
drop policy if exists invitation_media_insert on storage.objects;
drop policy if exists invitation_media_update on storage.objects;
drop policy if exists invitation_media_delete on storage.objects;
create policy invitation_media_read on storage.objects for select to anon, authenticated
  using (bucket_id = 'invitation-media');
create policy invitation_media_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'invitation-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy invitation_media_update on storage.objects for update to authenticated
  using (bucket_id = 'invitation-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy invitation_media_delete on storage.objects for delete to authenticated
  using (bucket_id = 'invitation-media' and (storage.foldername(name))[1] = auth.uid()::text);
