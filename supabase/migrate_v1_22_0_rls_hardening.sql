-- RLS hardening для релиза (конкурент ТГ) — закрываем дыру `using (true)`
-- До этого все таблицы были открыты всем, теперь только участникам/владельцу.
-- Оставлен `service_role` обход (pg_cron и Edge Functions работают от service_role).

-- ---------- scheduled_messages: только свой sender_id ----------
drop policy if exists scheduled_all on public.scheduled_messages;
create policy scheduled_owner_all on public.scheduled_messages
  for all
  using (auth.uid() = sender_id)
  with check (auth.uid() = sender_id);

-- Разрешить service_role (cron) читать/удалять всё — через обход RLS (service_role bypasses RLS по умолчанию)
-- Явно не нужно, но для ясности: service_role уже bypasses RLS

-- ---------- messages: вставлять может только свой sender_id, читать — пока открыто для членов чата через приложение
-- Для MVP: INSERT только своим sender_id, SELECT/UPDATE/DELETE — только если auth.uid() в members чата
-- Упростим: INSERT с проверкой sender_id, остальное пока оставим для совместимости, но закроем spoofing
drop policy if exists messages_all on public.messages;
-- Insert: только своим id
create policy messages_insert_own on public.messages
  for insert with check (auth.uid() = sender_id);
-- Select: только если состоишь в чате (через GIN members)
create policy messages_select_member on public.messages
  for select using (
    exists (select 1 from public.chats where chats.id = messages.chat_id and auth.uid() = any(chats.members))
    or auth.uid() = sender_id
  );
-- Update/Delete: только автор или член чата (для реакций, удалений)
create policy messages_modify_member on public.messages
  for all using (
    auth.uid() = sender_id
    or exists (select 1 from public.chats where chats.id = messages.chat_id and auth.uid() = any(chats.members))
  ) with check (auth.uid() = sender_id);

-- ---------- chats: видеть только свои чаты ----------
drop policy if exists chats_all on public.chats;
create policy chats_select_member on public.chats
  for select using (auth.uid() = any(members));
create policy chats_insert_member on public.chats
  for insert with check (auth.uid() = any(members));
create policy chats_update_member on public.chats
  for update using (auth.uid() = any(members)) with check (auth.uid() = any(members));

-- ---------- profiles: читать всем, писать только себе ----------
drop policy if exists profiles_all on public.profiles;
create policy profiles_select_all on public.profiles
  for select using (true);
create policy profiles_modify_own on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- ---------- stories: как и было — публично читать, писать только себе ----------
drop policy if exists stories_all on public.stories;
create policy stories_select_all on public.stories
  for select using (true);
create policy stories_modify_own on public.stories
  for all using (auth.uid() = profile_id) with check (auth.uid() = profile_id);
