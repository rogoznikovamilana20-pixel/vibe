-- 1.2 JWT auth + RLS per-row (supabase.auth, phone as email prefix @vibe.local)

-- 1) trigger: auth.users -> profiles
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  next_uid bigint;
  uname text;
begin
  next_uid := floor(random() * 90000000 + 10000000)::bigint;
  uname := 'user_' || substr(md5(random()::text), 1, 6);
  insert into public.profiles (id, phone, username, display_name, uid, bio, online)
  values (new.id, split_part(new.email, '@', 1), uname, '', next_uid, '', false)
  on conflict (id) do nothing;
  return new;
end
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2) cleanup of the RPC/session scheme (1.1/1.4 approach)
drop function if exists public.auth_register(text, text);
drop function if exists public.auth_login(text, text);
drop function if exists public.auth_logout(uuid);
drop function if exists public.probe_headers();
drop table if exists public.sessions;
alter table public.profiles drop column if exists password_hash;

-- 3) grants: anon gets nothing, authenticated gets table access (RLS filters rows)
revoke all on public.chats, public.messages, public.profiles, public.stories from anon;
grant select, insert, update, delete on public.chats, public.messages, public.profiles, public.stories to authenticated;
revoke select (phone) on public.profiles from authenticated;

-- 4) profiles
drop policy if exists profiles_all on public.profiles;
create policy profiles_select_authed on public.profiles
  for select to authenticated using (true);
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- 5) chats
drop policy if exists chats_all on public.chats;
create policy chats_select_member on public.chats
  for select to authenticated using (members @> array[auth.uid()]);
create policy chats_insert_member on public.chats
  for insert to authenticated with check (members @> array[auth.uid()]);
create policy chats_update_member on public.chats
  for update to authenticated
  using (members @> array[auth.uid()])
  with check (members @> array[auth.uid()]);
create policy chats_delete_member on public.chats
  for delete to authenticated using (members @> array[auth.uid()]);

-- 6) messages
drop policy if exists messages_all on public.messages;
create policy messages_select_member on public.messages
  for select to authenticated
  using (exists (select 1 from public.chats c
                 where c.id = messages.chat_id
                   and c.members @> array[auth.uid()]));
create policy messages_insert_member on public.messages
  for insert to authenticated
  with check (exists (select 1 from public.chats c
                      where c.id = messages.chat_id
                        and c.members @> array[auth.uid()])
              and sender_id = auth.uid());
create policy messages_update_member on public.messages
  for update to authenticated
  using (exists (select 1 from public.chats c
                 where c.id = messages.chat_id
                   and c.members @> array[auth.uid()]))
  with check (exists (select 1 from public.chats c
                      where c.id = messages.chat_id
                        and c.members @> array[auth.uid()]));
create policy messages_delete_member on public.messages
  for delete to authenticated
  using (exists (select 1 from public.chats c
                 where c.id = messages.chat_id
                   and c.members @> array[auth.uid()]));

-- 7) stories
drop policy if exists stories_all on public.stories;
create policy stories_select_friend on public.stories
  for select to authenticated
  using (exists (select 1 from public.chats c
                 where c.members @> array[auth.uid()]
                   and c.members @> array[profile_id]));
create policy stories_insert_own on public.stories
  for insert to authenticated with check (profile_id = auth.uid());
create policy stories_update_own on public.stories
  for update to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());
create policy stories_delete_own on public.stories
  for delete to authenticated using (profile_id = auth.uid());

-- 8) supporting indexes
create index if not exists messages_chat_id_idx on public.messages (chat_id);
create index if not exists chats_members_gin on public.chats using gin (members);