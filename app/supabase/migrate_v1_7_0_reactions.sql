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
