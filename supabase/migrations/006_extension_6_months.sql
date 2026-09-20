-- The extension add-on is now 6 months for $6.99.
update plans set extension_days = 180, extension_price_cents = 699;

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
    values (v_order, 'extension', p_plan, (pl.extension_days / 30) || '-month extension', pl.extension_price_cents, pl.extension_days);
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
  values (v_order, 'extension', e.plan, (pl.extension_days / 30) || '-month extension', pl.extension_price_cents, pl.extension_days);
  perform set_config('app.privileged', '1', true);
  update events set expires_at = v_new, grace_ends_at = v_new + interval '7 days',
         status = 'published', archived_at = null where id = e.id;
  return jsonb_build_object('order_id', v_order, 'expires_at', v_new);
end $$;
