-- Vibe 1.1/1.3: RPC-based auth.
-- Passwords are NEVER written by the client into the table.
-- Login/register go through functions only. password_hash is hidden from
-- anon (column grants). Apply in Supabase SQL Editor or: supabase db push.

create extension if not exists pgcrypto;

-- ================= Server-side sessions =================
create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create index if not exists sessions_profile_idx on public.sessions(profile_id);

alter table public.sessions enable row level security;
-- No policies: anon has NO direct access to sessions (RPC only).

-- ================= auth_register =================
create or replace function public.auth_register(p_phone text, p_password text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_phone text := btrim(replace(replace(p_phone, ' ', ''), '-', ''));
  v_profile public.profiles%rowtype;
  v_session uuid;
  v_username text;
  v_uid int;
  i int;
begin
  if length(v_phone) < 5 then
    raise exception 'INVALID_PHONE';
  end if;
  if length(coalesce(p_password, '')) < 4 then
    raise exception 'WEAK_PASSWORD';
  end if;
  if exists (select 1 from public.profiles where phone = v_phone) then
    raise exception 'PHONE_TAKEN';
  end if;

  -- username and uid are generated server-side only.
  v_username := 'user_' || lpad(floor(random() * 10000)::int::text, 4, '0');
  v_uid := 10000000;
  for i in 1..5 loop
    v_uid := 10000000 + floor(random() * 89999999)::int;
    exit when not exists (select 1 from public.profiles where uid = v_uid);
  end loop;

  insert into public.profiles(id, phone, password_hash, display_name, username, uid)
  values (
    gen_random_uuid(),
    v_phone,
    crypt(p_password, gen_salt('bf', 10)),
    '',
    v_username,
    v_uid
  )
  returning * into v_profile;

  insert into public.sessions(profile_id) values (v_profile.id)
  returning id into v_session;

  return jsonb_build_object(
    'profile', jsonb_build_object(
      'id', v_profile.id,
      'phone', v_profile.phone,
      'username', v_profile.username,
      'display_name', v_profile.display_name,
      'uid', v_profile.uid,
      'emoji', v_profile.emoji,
      'avatar_url', v_profile.avatar_url,
      'bio', v_profile.bio,
      'online', v_profile.online
    ),
    'session_id', v_session
  );
end $$;

-- ================= auth_login =================
create or replace function public.auth_login(p_phone text, p_password text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_phone text := btrim(replace(replace(p_phone, ' ', ''), '-', ''));
  v_profile public.profiles%rowtype;
  v_session uuid;
begin
  select * into v_profile from public.profiles where phone = v_phone;
  if v_profile.id is null or v_profile.password_hash is null then
    raise exception 'INVALID_CREDENTIALS';
  end if;
  if not (v_profile.password_hash = crypt(p_password, v_profile.password_hash)) then
    raise exception 'INVALID_CREDENTIALS';
  end if;

  insert into public.sessions(profile_id) values (v_profile.id)
  returning id into v_session;

  return jsonb_build_object(
    'profile', jsonb_build_object(
      'id', v_profile.id,
      'phone', v_profile.phone,
      'username', v_profile.username,
      'display_name', v_profile.display_name,
      'uid', v_profile.uid,
      'emoji', v_profile.emoji,
      'avatar_url', v_profile.avatar_url,
      'bio', v_profile.bio,
      'online', v_profile.online
    ),
    'session_id', v_session
  );
end $$;

-- ================= auth_logout =================
create or replace function public.auth_logout(session_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.sessions
     set revoked_at = now()
   where id = session_id and revoked_at is null;
end $$;

-- ================= Grants for anon =================
grant execute on function public.auth_register(text, text) to anon;
grant execute on function public.auth_login(text, text) to anon;
grant execute on function public.auth_logout(uuid) to anon;

-- ================= 1.3 Hide password_hash =================
-- Anon no longer has full access to profiles: only needed columns.
revoke all on public.profiles from anon;

-- Read: PostgREST requires table-level SELECT, then hide sensitive columns.
grant select on public.profiles to anon;
revoke select (password_hash) on public.profiles from anon;

-- Insert: only what is needed (no password_hash).
grant insert (id, phone, display_name, username, uid) on public.profiles to anon;

-- Update: public profile fields. Password changes via separate RPC (later).
grant update (display_name, username, emoji, avatar_url, bio, online,
              fcm_token) on public.profiles to anon;

-- Verify:
--   select * from public.profiles;             -- NO password_hash
--   select public.auth_register('+7...', '...'); -- bcrypt flow