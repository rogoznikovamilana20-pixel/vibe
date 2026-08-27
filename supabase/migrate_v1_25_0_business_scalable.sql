-- Business Space scalable: микро → энтерпрайз, витрины, метрики, команда, подписки
-- Тиры: Старт(0) Микро(299) Рост(799) Масштаб(2499) Энтерпрайз(9999+)

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text default '',
  category text default 'other',
  avatar_url text,
  cover_url text,
  address jsonb default '{}'::jsonb,
  phone text,
  verified boolean default false,
  tier text not null default 'start' check (tier in ('start','micro','growth','scale','enterprise')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists businesses_owner_idx on public.businesses(owner_id);
create index if not exists businesses_tier_idx on public.businesses(tier);

create table if not exists public.business_members (
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'employee' check (role in ('owner','admin','employee','support')),
  permissions jsonb default '{"can_edit_showcase": false, "can_answer_chats": true, "can_view_metrics": false}'::jsonb,
  added_at timestamptz not null default now(),
  primary key (business_id, user_id)
);
create index if not exists business_members_user_idx on public.business_members(user_id);

create table if not exists public.business_showcases (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  title text not null,
  description text default '',
  media jsonb default '[]'::jsonb,
  price numeric(12,2) default 0,
  currency text default 'RUB',
  category text default 'other',
  is_active boolean default true,
  created_at timestamptz not null default now()
);
create index if not exists showcases_business_idx on public.business_showcases(business_id, is_active);

create table if not exists public.business_chats (
  business_id uuid not null references public.businesses(id) on delete cascade,
  chat_id uuid not null references public.chats(id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (business_id, chat_id)
);

create table if not exists public.business_metrics_daily (
  business_id uuid not null references public.businesses(id) on delete cascade,
  date date not null default current_date,
  views int not null default 0,
  clicks int not null default 0,
  orders int not null default 0,
  revenue numeric(14,2) not null default 0,
  unique_chats int not null default 0,
  primary key (business_id, date)
);

create table if not exists public.business_subscriptions (
  business_id uuid primary key references public.businesses(id) on delete cascade,
  tier text not null default 'start' check (tier in ('start','micro','growth','scale','enterprise')),
  coins_spent int not null default 0,
  expires_at timestamptz,
  trial_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.business_addons (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  type text not null check (type in ('extra_showcase','extra_members','extra_products')),
  quantity int not null default 1,
  coins int not null,
  created_at timestamptz not null default now()
);

-- RLS
alter table public.businesses enable row level security;
alter table public.business_members enable row level security;
alter table public.business_showcases enable row level security;
alter table public.business_chats enable row level security;
alter table public.business_metrics_daily enable row level security;
alter table public.business_subscriptions enable row level security;
alter table public.business_addons enable row level security;

drop policy if exists businesses_select_member on public.businesses;
create policy businesses_select_member on public.businesses for select to authenticated
  using (owner_id = auth.uid() or exists (select 1 from public.business_members where business_id = businesses.id and user_id = auth.uid()));

drop policy if exists businesses_insert_owner on public.businesses;
create policy businesses_insert_owner on public.businesses for insert to authenticated with check (owner_id = auth.uid());

drop policy if exists businesses_update_owner on public.businesses;
create policy businesses_update_owner on public.businesses for update to authenticated
  using (owner_id = auth.uid() or exists (select 1 from public.business_members where business_id = businesses.id and user_id = auth.uid() and role in ('owner','admin')))
  with check (owner_id = auth.uid() or exists (select 1 from public.business_members where business_id = businesses.id and user_id = auth.uid() and role in ('owner','admin')));

drop policy if exists businesses_delete_owner on public.businesses;
create policy businesses_delete_owner on public.businesses for delete to authenticated using (owner_id = auth.uid());

drop policy if exists members_select on public.business_members;
create policy members_select on public.business_members for select to authenticated using (business_id in (select id from public.businesses where owner_id = auth.uid() or id in (select business_id from public.business_members where user_id = auth.uid())));

drop policy if exists members_insert on public.business_members;
create policy members_insert on public.business_members for insert to authenticated with check (business_id in (select id from public.businesses where owner_id = auth.uid()));

drop policy if exists showcases_select on public.business_showcases;
create policy showcases_select on public.business_showcases for select to authenticated using (business_id in (select id from public.businesses where owner_id = auth.uid() or id in (select business_id from public.business_members where user_id = auth.uid())));

drop policy if exists showcases_insert on public.business_showcases;
create policy showcases_insert on public.business_showcases for insert to authenticated with check (business_id in (select id from public.businesses where owner_id = auth.uid() or business_id in (select business_id from public.business_members where user_id = auth.uid() and (permissions->>'can_edit_showcase')::boolean = true)));

-- metrics: только owner/admin can_view_metrics
drop policy if exists metrics_select on public.business_metrics_daily;
create policy metrics_select on public.business_metrics_daily for select to authenticated using (business_id in (select id from public.businesses where owner_id = auth.uid() or business_id in (select business_id from public.business_members where user_id = auth.uid() and ((permissions->>'can_view_metrics')::boolean = true or role in ('owner','admin')))));

-- updated_at trigger
create or replace function public.touch_updated_at() returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end $$;
drop trigger if exists trg_businesses_updated on public.businesses;
create trigger trg_businesses_updated before update on public.businesses for each row execute function public.touch_updated_at();
drop trigger if exists trg_subs_updated on public.business_subscriptions;
create trigger trg_subs_updated before update on public.business_subscriptions for each row execute function public.touch_updated_at();
