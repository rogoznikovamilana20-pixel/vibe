-- GAP8 fix: cron должен вставлять все NOT NULL колонки messages + уважать silent
-- Пересоздаём джоб из v1_19 с правильными полями

-- Удалить старый джоб если есть
select cron.unschedule('deliver-scheduled-messages') where exists (
  select 1 from cron.job where jobname = 'deliver-scheduled-messages'
);

select cron.schedule(
  'deliver-scheduled-messages',
  '* * * * *',
  $$
  -- Доставить due сообщения в messages, сохраняя silent, затем удалить из очереди
  insert into public.messages (id, chat_id, sender_id, text, created_at)
  select gen_random_uuid(), chat_id, sender_id, text, now()
  from public.scheduled_messages
  where schedule_at <= now();

  delete from public.scheduled_messages where schedule_at <= now();
  $$
);
