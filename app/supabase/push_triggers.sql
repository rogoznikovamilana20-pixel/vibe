-- Vibe: триггеры доставки пушей через pg_net.
-- Событие INSERT в messages/stories -> http POST на edge-функцию send-push.
-- Сигнатура net.http_post: (url, body jsonb, params jsonb, headers jsonb, timeout_ms).

create extension if not exists pg_net;

create or replace function public.push_on_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform net.http_post(
    url := 'https://rgdwfoicidnamejluxfx.functions.supabase.co/send-push',
    body := jsonb_build_object(
      'record', jsonb_set(to_jsonb(NEW), '{type}', '"chat"')
    ),
    params := '{}'::jsonb,
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
  return NEW;
end;
$$;

drop trigger if exists messages_push on public.messages;
create trigger messages_push
after insert on public.messages
for each row execute function push_on_message();

create or replace function push_on_story()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform net.http_post(
    url := 'https://rgdwfoicidnamejluxfx.functions.supabase.co/send-push',
    body := jsonb_build_object(
      'record', jsonb_set(to_jsonb(NEW), '{type}', '"story"')
    ),
    params := '{}'::jsonb,
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
  return NEW;
end;
$$;

drop trigger if exists push_story on public.stories;
create trigger push_story
after insert on public.stories
for each row execute function push_on_story();