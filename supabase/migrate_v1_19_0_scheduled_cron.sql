-- GAP8: доставка отложенных сообщений по расписанию (как в TG) — pg_cron каждую минуту
-- Требует pg_cron + pg_net (в Supabase включены). Доставляет silent с учётом флага.
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;

select cron.schedule(
  'deliver-scheduled-messages',
  '* * * * *',
  $$
  -- Доставить due сообщения в messages, затем удалить из очереди
  insert into public.messages (chat_id, sender_id, text, forward_from)
  select chat_id, sender_id, text, null from public.scheduled_messages
  where schedule_at <= now();
  delete from public.scheduled_messages where schedule_at <= now();
  $$
);
