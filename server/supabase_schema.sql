-- =====================================================================
-- Vibe messenger: схема для Supabase (выполнить в SQL Editor один раз)
-- https://supabase.com/dashboard/project/rgdwfoicidnamejluxfx/sql/new
-- =====================================================================

-- ---------- 1. PROFILES (профили пользователей) ------------------------
alter table public.profiles
  add column if not exists username text,
  add column if not exists display_name text,
  add column if not exists emoji text,
  add column if not exists avatar text,
  add column if not exists online boolean default false;

-- ---------- 2. CHATS (чаты: pm/group) -------------------------------
create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  kind text not null default 'pm',
  title text,
  created_at timestamptz not null default now()
);

alter table public.chats enable row level security;

create table if not exists public.chat_members (
  chat_id uuid references public.chats(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (chat_id, profile_id)
);

alter table public.chat_members enable row level security;

-- ---------- 3. MESSAGES (сообщения: текст/голос/фото) ---------------
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid references public.chats(id) on delete cascade not null,
  sender_id uuid references public.profiles(id) on delete set null not null,
  text text,
  voice text,
  photo text,
  read_by uuid[] default '{}',
  created_at timestamptz not null default now()
);

alter table public.messages enable row level security;
create index if not exists messages_chat_id_idx on public.messages (chat_id, created_at desc);

-- ---------- 4. ПРАВА (открытые для MVP, RLS упрощён) ----------------
create policy "public all profiles" on public.profiles
  for all using (true) with check (true);
create policy "public all chats" on public.chats
  for all using (true) with check (true);
create policy "public all chat_members" on public.chat_members
  for all using (true) with check (true);
create policy "public all messages" on public.messages
  for all using (true) with check (true);

-- ---------- 5. REALTIME для сообщений -------------------------------
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.profiles;

-- ---------- 6. CORRECTIVE: метод createRecord для профиля. ----------
-- (не требуется: profiles создаётся через /auth/v1/signup + profiles.trigger)