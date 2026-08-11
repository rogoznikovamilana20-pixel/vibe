-- =====================================================================
-- Vibe v1.7.0 — B4: серверный read_state (непрочитанные чаты).
-- Применить в SQL Editor облачного проекта Supabase один раз.
-- idempotent: можно гонять повторно.
-- =====================================================================

-- ---------- 1. Таблица прочитанности по каждой паре (чат, пользователь) ----------
create table if not exists public.read_states (
  chat_id uuid not null references public.chats(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (chat_id, user_id)
);

alter table public.read_states enable row level security;

drop policy if exists read_states_all on public.read_states;
create policy read_states_all on public.read_states
  for all using (true) with check (true);

-- ---------- 2. RPC: количество непрочитанных сообщений по всем чатам ----------
-- Считаются только чужие сообщения, пришедшие ПОСЛЕ последнего прочтения.
-- Если записи read_states нет — таймстамп -infinity, т.е. всё непрочитано.
create or replace function public.get_unread_counts()
returns table(chat_id uuid, unread bigint)
language sql stable security definer set search_path = public as $$
  select
    c.id as chat_id,
    count(m.id)::bigint as unread
  from public.chats c
  left join public.read_states rs
    on rs.chat_id = c.id
    and rs.user_id = auth.uid()
  left join public.messages m
    on m.chat_id = c.id
    and m.sender_id <> auth.uid()
    and m.created_at > coalesce(rs.last_read_at, '-infinity'::timestamptz)
  where auth.uid() = any(c.members)
  group by c.id
  having count(m.id) > 0;
$$;

grant execute on function public.get_unread_counts() to anon, authenticated;
