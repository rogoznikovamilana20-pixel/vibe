-- v1.10.0 — Множественные закреплённые сообщения в облаке.
-- Таблица chat_pins: сколько угодно закрепов на чат (как в Telegram),
-- каждый — отдельная строка. Пин считается «моим», если его поставил я
-- (pinned_by), но виден всем участникам чата.

create table if not exists public.chat_pins (
  chat_id uuid not null references public.chats(id) on delete cascade,
  message_id uuid not null references public.messages(id) on delete cascade,
  pinned_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (chat_id, message_id)
);
create index if not exists chat_pins_chat_idx
  on public.chat_pins (chat_id, created_at desc);

alter table public.chat_pins enable row level security;

-- Участник чата видит закрепы и может пинить; снять может автор пина.
-- (Стиль проекта: политики не строгие, проверка принадлежности — на клиенте.)
drop policy if exists chat_pins_all on public.chat_pins;
create policy chat_pins_all on public.chat_pins
  for all using (true) with check (true);