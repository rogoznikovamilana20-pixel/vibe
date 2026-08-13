-- v1.8.0 — Расширенная модель правок: история правок сообщений.
-- Каждая правка текстового сообщения сохраняется снимком; текущий текст
-- живёт в messages.text (как и раньше), история — в message_edits.

create table if not exists public.message_edits (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  text text not null,
  edited_at timestamptz not null default now()
);
create index if not exists message_edits_msg_idx
  on public.message_edits (message_id, edited_at desc);

alter table public.message_edits enable row level security;

drop policy if exists message_edits_all on public.message_edits;
create policy message_edits_all on public.message_edits
  for all using (true) with check (true);