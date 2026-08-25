-- GAP8: scheduled + silent на сервере как в TG (messages.sendMessage schedule_date/silent)
create table if not exists scheduled_messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references chats(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  text text not null,
  schedule_at timestamptz not null,
  silent boolean not null default false,
  created_at timestamptz not null default now()
);
alter table scheduled_messages enable row level security;
drop policy if exists scheduled_all on scheduled_messages;
create policy scheduled_all on scheduled_messages for all using (true) with check (true);
create index if not exists scheduled_chat_idx on scheduled_messages(chat_id, schedule_at);
