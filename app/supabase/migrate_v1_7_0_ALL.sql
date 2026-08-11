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

-- =====================================================================
-- Vibe v1.7.0 — 3.1: реакции на сервере (message_reactions) + realtime.
-- Применить в SQL Editor облачного проекта Supabase один раз.
-- idempotent: можно гонять повторно.
-- =====================================================================

-- ---------- 1. Таблица реакций ----------
create table if not exists public.message_reactions (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);

alter table public.message_reactions enable row level security;

drop policy if exists message_reactions_all on public.message_reactions;
create policy message_reactions_all on public.message_reactions
  for all using (true) with check (true);

-- ---------- 2. RPC: сгруппировать реакции по сообщениям чата ----------
create or replace function public.get_message_reactions(chat uuid)
returns table(message_id uuid, emoji text, cnt bigint)
language sql stable security definer set search_path = public as $$
  select r.message_id, r.emoji, count(*)::bigint as cnt
  from public.message_reactions r
  join public.messages m on m.id = r.message_id
  where m.chat_id = chat
  group by r.message_id, r.emoji;
$$;

grant execute on function public.get_message_reactions(uuid) to anon, authenticated;

-- ---------- 3. Realtime для реакций ----------
do $$
begin
  begin
    alter publication supabase_realtime add table public.message_reactions;
  exception when duplicate_object then null;
  end;
end $$;

-- =====================================================================
-- Vibe v1.7.0 — 3.2/3.3: архив и DND с таймером в облаке.
-- Дополняет migrate_v1_7_0_read_state.sql (таблицу read_states).
-- idempotent: можно гонять повторно.
-- =====================================================================

-- ---------- 1. Колонки состояния чата на read_states ----------
alter table public.read_states
  add column if not exists archived_at timestamptz,
  add column if not exists muted_until timestamptz;

-- ---------- 2. RPC: состояние всех моих чатов ----------
create or replace function public.get_my_chat_states()
returns table(chat_id uuid, archived_at timestamptz, muted_until timestamptz)
language sql stable security definer set search_path = public as $$
  select rs.chat_id, rs.archived_at, rs.muted_until
  from public.read_states rs
  where rs.user_id = auth.uid();
$$;

grant execute on function public.get_my_chat_states() to anon, authenticated;

