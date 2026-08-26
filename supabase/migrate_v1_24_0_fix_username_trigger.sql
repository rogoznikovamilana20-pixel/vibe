-- Fix @vibetest default username on new accounts
-- The handle_new_user trigger was generating 'vibetest' instead of random user_####
-- This migration recreates it properly and cleans up any existing vibetest usernames.

-- Recreate the trigger with proper random username generation
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  next_uid bigint;
  uname text;
  attempts int := 0;
begin
  next_uid := floor(random() * 90000000 + 10000000)::bigint;

  -- Generate unique username: user_XXXXXX (6 random hex chars)
  loop
    uname := 'user_' || substr(md5(random()::text || clock_timestamp()::text), 1, 6);
    exit when not exists (select 1 from public.profiles where username = uname) or attempts > 10;
    attempts := attempts + 1;
  end loop;

  insert into public.profiles (id, phone, username, display_name, uid, bio, online)
  values (new.id, split_part(new.email, '@', 1), uname, '', next_uid, '', false)
  on conflict (id) do nothing;
  return new;
end
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Fix existing vibetest usernames (if any)
update public.profiles
set username = 'user_' || substr(md5(random()::text || id::text), 1, 6)
where username = 'vibetest' or username like 'vibetest%';
