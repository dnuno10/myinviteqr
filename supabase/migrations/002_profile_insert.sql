-- Lets a signed-in user create their own profile row if the signup trigger did not (never as admin).
grant insert on profiles to authenticated;
drop policy if exists profiles_insert on profiles;
create policy profiles_insert on profiles for insert to authenticated
  with check (id = auth.uid() and role = 'host');
