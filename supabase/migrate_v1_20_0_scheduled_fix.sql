-- GAP8 fix: cron должен вставлять все NOT NULL колонки messages + уважать silent
-- Пересоздаём джоб из v1_19 с правильными полями

create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'deliver-scheduled-messages') then
      perform cron.unschedule('deliver-scheduled-messages');
    end if;
  end if;
end $$;

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
