-- Draft sync: черновики как в TG (messages.saveDraft) — локальный кеш главный, облако best-effort.
create table if not exists drafts (
  user_id uuid not null references profiles(id) on delete cascade,
  chat_id text not null,
  text text not null default '',
  updated_at timestamptz not null default now(),
  primary key (user_id, chat_id)
);

alter table drafts enable row level security;

drop policy if exists drafts_all on drafts;
create policy drafts_all on drafts
  for all
  using (true)
  with check (true);

create index if not exists drafts_user_idx on drafts(user_id);
