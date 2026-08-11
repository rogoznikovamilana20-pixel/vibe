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
