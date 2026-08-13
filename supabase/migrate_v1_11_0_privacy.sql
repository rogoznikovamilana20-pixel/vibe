-- 3.7: настройки приватности владельца в облаке (зеркало локального кеша).
-- Клиент пишет целиком при каждом изменении; RLS-политика как у chat_pins:
-- доступ разрешён всем аутентифицированным, фильтрацию делает сервер/клиент.
create table if not exists profile_privacy (
  user_id uuid primary key references profiles(id) on delete cascade,
  last_seen smallint not null default 0,
  photo smallint not null default 0,
  forward smallint not null default 0,
  calls smallint not null default 0,
  groups smallint not null default 0,
  updated_at timestamptz not null default now()
);

alter table profile_privacy enable row level security;

drop policy if exists profile_privacy_all on profile_privacy;
create policy profile_privacy_all on profile_privacy
  for all
  using (true)
  with check (true);