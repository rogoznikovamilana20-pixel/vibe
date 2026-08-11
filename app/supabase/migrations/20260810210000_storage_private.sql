-- 1.5 Приватные медиа: бакет private + политики доступа + edge-функция подписанных URL.
-- Пути объектов (папка внутри бакета + ключ):
--   avatars/<uid>.png                  — аватарки: видит любой authenticated
--   stories/<uid>/<ts>.jpg             — стори: видит участник общего pm-чата (друг)
--   media/<chatId>/<type>_<uid>/<ts>   — медиа: видит участник чата <chatId>
--   messages/<type>_<uid>/<ts>.<ext>   — голосовые: участник общего pm-чата (аналог stories)
-- Запись/обновление/удаление: только владелец объекта (owner_id = auth.uid()).
--
-- ВАЖНО: финальный доступ к медиа идёт НЕ через select-политику, а через edge-функцию
-- supabase/functions/media-sign (service_role + собственная проверка прав), которая
-- возвращает подписанный URL (expiresIn=3600). Поэтому select-политика намеренно
-- ограничена: прямые GET /object/... по JWT пользователя закрыты (нужен select owner-only).

update storage.buckets set public = false where id = 'avatars';

drop policy if exists "avatars_all" on storage.objects;
drop policy if exists "media_insert_own" on storage.objects;
drop policy if exists "media_update_own" on storage.objects;
drop policy if exists "media_delete_own" on storage.objects;
drop policy if exists "media_select" on storage.objects;
drop policy if exists "media_select_like" on storage.objects;
drop policy if exists "media_select_owner" on storage.objects;

create policy "media_insert_own" on storage.objects
  for insert to authenticated
  with check (owner_id::uuid = auth.uid());

create policy "media_update_own" on storage.objects
  for update to authenticated
  using (owner_id::uuid = auth.uid())
  with check (owner_id::uuid = auth.uid());

create policy "media_delete_own" on storage.objects
  for delete to authenticated
  using (owner_id::uuid = auth.uid());

-- Клиент никогда не читает объекты напрямую по JWT (только подписанные URL от media-sign),
-- поэтому select разрешён только владельцу. Заменить текущую legacy-политику media_select_like:
create policy "media_select_owner" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and owner_id is not null
    and owner_id::uuid = auth.uid()
  );
