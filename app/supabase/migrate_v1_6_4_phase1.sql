-- ============================================================
-- Vibe v1.6.4 · Миграция «Бэкенд-ядро» (Фаза 1)
-- Запускать в SQL-консоли Supabase один раз.
-- ============================================================

-- 1. Редактирование сообщений: метка времени правки.
--    non-null значение = сообщение изменено (метка «изменено» в клиенте,
--    как в Telegram).
alter table public.messages
  add column if not exists edited_at timestamptz;

-- 2. Пересылка сообщений: имя автора оригинала («Переслано от …»).
alter table public.messages
  add column if not exists forward_from text;

-- 2. Realtime: правки и удаления сообщений долетают до клиентов
--    (резервный канал к бродкастам на личные каналы).
alter publication supabase_realtime
  set (publish = 'insert, update, delete');

-- ============================================================
-- Защита «только своих сообщений» сейчас (прототип, anon-доступ):
-- клиент добавляет условия sender_id = мой id в update/delete.
-- Политики RLS полной силы добавятся на этапе миграции
-- пользователей на Supabase Auth (Фаза 8/10). Тогда:
--
--   create policy messages_update_own on public.messages
--     for update using (sender_id = auth.uid())
--     with check (sender_id = auth.uid());
--   create policy messages_delete_own on public.messages
--     for delete using (sender_id = auth.uid());
-- ============================================================