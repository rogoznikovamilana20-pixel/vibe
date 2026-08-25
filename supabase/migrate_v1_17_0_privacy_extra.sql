-- PR3: privacy 5/8 -> 8/8, добавляем voice/bio/birthday как в TG
alter table public.profile_privacy add column if not exists voice_messages smallint not null default 0;
alter table public.profile_privacy add column if not exists bio smallint not null default 0;
alter table public.profile_privacy add column if not exists birthday smallint not null default 0;
