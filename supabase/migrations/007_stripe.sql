-- Stripe payments. Events are published (or extended) only when Stripe confirms the payment.
-- The Edge Functions `create-checkout` and `stripe-webhook` call these functions.

alter table orders add column if not exists stripe_session_id text unique;
alter table orders add column if not exists payment_intent    text;
alter table orders add column if not exists stripe_error      text;
create index if not exists orders_payment_intent_idx on orders (payment_intent);

-- ---------------------------------------------------------------------------
-- 1. start_checkout: validates, records a PENDING order and returns what to charge.
--    Called by the signed-in host (through the create-checkout function).
-- ---------------------------------------------------------------------------
create or replace function public.start_checkout(
  p_event uuid, p_kind text, p_plan text default null, p_extension boolean default false, p_code text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  e events%rowtype; pl plans%rowtype; q jsonb; v_order uuid; v_guests integer;
  v_plan text; v_ext boolean; v_sub integer; v_disc integer := 0; v_total integer; v_code text;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  select * into e from events where id = p_event and owner_id = auth.uid() for update;
  if e.id is null then raise exception 'Event not found'; end if;

  if p_kind = 'publish' then
    if e.status <> 'draft' then raise exception 'This event is already published'; end if;
    if coalesce(trim(e.title), '') = '' then raise exception 'Add a title before publishing'; end if;
    if e.template_id is null then raise exception 'Choose a template before publishing'; end if;
    if e.starts_at is null then raise exception 'Add the event date before publishing'; end if;
    v_plan := p_plan; v_ext := coalesce(p_extension, false);
  elsif p_kind = 'extension' then
    if e.status = 'draft' or e.plan is null then raise exception 'Publish the event first'; end if;
    v_plan := e.plan; v_ext := true;
  else
    raise exception 'Unknown order type';
  end if;

  select * into pl from plans where code = v_plan;
  if pl.code is null then raise exception 'Unknown plan'; end if;

  if p_kind = 'publish' then
    select count(*) into v_guests from guests where event_id = e.id;
    if v_guests > pl.max_guests then
      raise exception 'The % plan allows up to % guests (you have %)', pl.name, pl.max_guests, v_guests;
    end if;
    q := quote_order(v_plan, v_ext, p_code);
    v_sub := (q->>'subtotal')::int; v_disc := (q->>'discount')::int; v_total := (q->>'total')::int; v_code := q->>'code';
  else
    v_sub := pl.extension_price_cents; v_total := v_sub;
  end if;

  -- one open checkout per event: older unpaid attempts are closed (a late payment still fulfils them)
  update orders set status = 'failed' where event_id = e.id and status = 'pending' and provider = 'stripe';

  insert into orders (user_id, event_id, kind, status, subtotal_cents, discount_code, discount_cents, total_cents, provider)
  values (auth.uid(), e.id, p_kind, 'pending', v_sub, v_code, v_disc, v_total, 'stripe')
  returning id into v_order;

  if p_kind = 'publish' then
    insert into order_items (order_id, kind, plan, description, amount_cents)
    values (v_order, 'plan', v_plan, pl.name || ' plan', pl.price_cents);
  end if;
  if v_ext then
    insert into order_items (order_id, kind, plan, description, amount_cents, extends_days)
    values (v_order, 'extension', v_plan, (pl.extension_days / 30) || '-month extension', pl.extension_price_cents, pl.extension_days);
  end if;

  return jsonb_build_object(
    'order_id', v_order, 'kind', p_kind, 'plan', v_plan, 'extension', v_ext,
    'subtotal', v_sub, 'discount', v_disc, 'total', v_total, 'code', v_code, 'title', e.title,
    'plan_cents', case when p_kind = 'publish' then pl.price_cents else 0 end,
    'ext_cents', case when v_ext then pl.extension_price_cents else 0 end
  );
end $$;

-- ---------------------------------------------------------------------------
-- 2. fulfill_order: marks the order paid and publishes / extends the event. Idempotent.
--    Only the service role (the webhook) can run it.
-- ---------------------------------------------------------------------------
create or replace function public.fulfill_order(p_order uuid, p_payment_intent text default null, p_session text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  o orders%rowtype; e events%rowtype; pl plans%rowtype; v_plan text; v_ext_days integer; v_new timestamptz; v_days integer;
begin
  select * into o from orders where id = p_order for update;
  if o.id is null then raise exception 'Order not found'; end if;
  if o.status = 'paid' then return jsonb_build_object('status', 'paid', 'already', true); end if;
  if o.status = 'refunded' then return jsonb_build_object('status', 'refunded'); end if;

  select plan into v_plan from order_items where order_id = o.id and kind = 'plan' limit 1;
  select coalesce(sum(extends_days), 0) into v_ext_days from order_items where order_id = o.id and kind = 'extension';

  update orders set status = 'paid', paid_at = now(), provider = 'stripe',
         stripe_session_id = coalesce(p_session, stripe_session_id),
         provider_ref = coalesce(p_session, provider_ref),
         payment_intent = coalesce(p_payment_intent, payment_intent), stripe_error = null
   where id = o.id;
  if o.discount_code is not null then
    update discount_codes set redeemed = redeemed + 1 where code = o.discount_code;
  end if;

  select * into e from events where id = o.event_id for update;
  if e.id is null then
    return jsonb_build_object('status', 'paid', 'orphan', true);   -- event was deleted after paying: refund it
  end if;

  perform set_config('app.privileged', '1', true);
  if o.kind = 'publish' then
    if e.status = 'draft' then
      select * into pl from plans where code = v_plan;
      v_days := pl.validity_days + v_ext_days;
      update events set status = 'published', plan = v_plan, published_at = now(),
             expires_at = now() + make_interval(days => v_days),
             grace_ends_at = now() + make_interval(days => v_days + 7)
       where id = e.id;
    end if;
  else
    v_new := greatest(coalesce(e.expires_at, now()), now()) + make_interval(days => v_ext_days);
    update events set expires_at = v_new, grace_ends_at = v_new + interval '7 days',
           status = 'published', archived_at = null where id = e.id;
  end if;
  return jsonb_build_object('status', 'paid', 'event_id', e.id);
end $$;

-- ---------------------------------------------------------------------------
-- 3. Session expired / refund bookkeeping
-- ---------------------------------------------------------------------------
create or replace function public.fail_order(p_session text, p_reason text default null)
returns void language sql security definer set search_path = public as $$
  update orders set status = 'failed', stripe_error = coalesce(p_reason, stripe_error)
   where stripe_session_id = p_session and status = 'pending';
$$;

create or replace function public.record_refund(p_payment_intent text, p_refunded_cents integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; v_done integer; v_delta integer;
begin
  select * into o from orders where payment_intent = p_payment_intent for update;
  if o.id is null then return jsonb_build_object('matched', false); end if;
  select coalesce(sum(amount_cents), 0) into v_done from refunds where order_id = o.id and status = 'processed';
  v_delta := p_refunded_cents - v_done;
  if v_delta > 0 then
    insert into refunds (order_id, amount_cents, reason, status, processed_at)
    values (o.id, v_delta, 'Refunded in Stripe', 'processed', now());
  end if;
  if p_refunded_cents >= o.total_cents and o.total_cents > 0 then
    update orders set status = 'refunded' where id = o.id;
  end if;
  return jsonb_build_object('matched', true, 'order_id', o.id);
end $$;

-- ---------------------------------------------------------------------------
-- 4. Permissions. No one can publish or extend without paying any more.
-- ---------------------------------------------------------------------------
revoke all on function public.publish_event(uuid, text, boolean, text) from public, anon, authenticated;
revoke all on function public.extend_event(uuid) from public, anon, authenticated;
revoke all on function public.fulfill_order(uuid, text, text) from public, anon, authenticated;
revoke all on function public.fail_order(text, text) from public, anon, authenticated;
revoke all on function public.record_refund(text, integer) from public, anon, authenticated;
revoke all on function public.start_checkout(uuid, text, text, boolean, text) from public, anon;

grant execute on function public.start_checkout(uuid, text, text, boolean, text) to authenticated, service_role;
grant execute on function public.fulfill_order(uuid, text, text) to service_role;
grant execute on function public.fail_order(text, text) to service_role;
grant execute on function public.record_refund(text, integer) to service_role;
