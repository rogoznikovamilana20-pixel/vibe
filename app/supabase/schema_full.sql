-- Vibe: полная живая схема для облачного проекта Supabase.
-- Применять через Management API (projects/{ref}/database/query).
-- Идемпотентно с нуля: снос шаблонных таблиц и создание нужных под код приложения.

drop table if exists public.stories cascade;
drop table if exists public.messages cascade;
drop table if exists public.chat_members cascade;
drop table if exists public.chats cascade;
drop table if exists public.profiles cascade;

-- ---------- profiles ----------
create table public.profiles (
  id uuid primary key,
  username text unique not null,
  phone text unique,
  display_name text not null default '',
  emoji text,
  avatar_url text,
  bio text not null default '',
  online boolean not null default false,
  fcm_token text,
  uid bigint
);

-- ---------- chats ----------
create table public.chats (
  id uuid primary key default gen_random_uuid(),
  kind text not null default 'pm',
  title text,
  members uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  last_message_id uuid
);
create index if not exists chats_members_idx on public.chats using gin (members);

-- ---------- messages ----------
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  text text,
  voice_url text,
  photo_url text,
  read_by uuid[] not null default '{}',
  created_at timestamptz not null default now()
);
create index messages_chat_idx on public.messages (chat_id, created_at desc);

-- ---------- stories ----------
create table public.stories (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  photo_url text,
  created_at timestamptz not null default now()
);
create index stories_profile_idx on public.stories (profile_id, created_at desc);

-- ---------- RLS: открытые права для всех (прототип, анонимный доступ) ----------
alter table public.profiles enable row level security;
alter table public.chats enable row level security;
alter table public.messages enable row level security;
alter table public.stories enable row level security;

drop policy if exists profiles_all on public.profiles;
drop policy if exists chats_all on public.chats;
drop policy if exists messages_all on public.messages;
drop policy if exists stories_all on public.stories;

create policy profiles_all on public.profiles for all using (true) with check (true);
create policy chats_all on public.chats for all using (true) with check (true);
create policy messages_all on public.messages for all using (true) with check (true);
create policy stories_all on public.stories for all using (true) with check (true);

-- ---------- Realtime (сообщения и профили) ----------
begin;
  drop publication if exists supabase_realtime;
  create publication supabase_realtime;
  alter publication supabase_realtime add table public.messages;
  alter publication supabase_realtime add table public.profiles;
commit;

-- ---------- Storage: публичный бакет avatars ----------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

drop policy if exists avatars_all on storage.objects;
create policy avatars_all on storage.objects
  for all using (bucket_id = 'avatars') with check (bucket_id = 'avatars');