-- Owners can delete any of their events (not only drafts). Paid orders are kept for accounting.
alter table orders alter column event_id drop not null;
alter table orders drop constraint if exists orders_event_id_fkey;
alter table orders add constraint orders_event_id_fkey
  foreign key (event_id) references events(id) on delete set null;

drop policy if exists events_delete on events;
create policy events_delete on events for delete to authenticated
  using (owner_id = auth.uid());
