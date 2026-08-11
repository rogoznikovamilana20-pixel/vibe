-- ============================================================
-- Vibe 1.6.4 Phase 2 — стикер-система
-- 1) messages.sticker_emoji — сообщение-стикер (эмодзи на подложке)
-- 2) sticker_packs / stickers — паки и стикеры (прослоены под будущую
--    загрузку собственных паков; RLS открыт, как и весь прототип)
-- ============================================================

alter table public.messages add column if not exists sticker_emoji text;

-- ---------- sticker_packs ----------
create table if not exists public.sticker_packs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  author_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ---------- stickers ----------
create table if not exists public.stickers (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid not null references public.sticker_packs(id) on delete cascade,
  emoji text not null,
  position int not null default 0
);
create index if not exists stickers_pack_idx on public.stickers (pack_id, position);

-- ---------- начальный пак «Vibe» ----------
insert into public.sticker_packs (id, title)
values ('00000000-0000-0000-0000-000000000001', 'Vibe')
on conflict (id) do nothing;

insert into public.stickers (pack_id, emoji, position)
select '00000000-0000-0000-0000-000000000001', e.emoji, e.pos
from (values
  ('😀', 0), ('😂', 1), ('🥳', 2), ('😎', 3), ('🥰', 4), ('😭', 5),
  ('😡', 6), ('🤔', 7), ('👍', 8), ('👎', 9), ('🔥', 10), ('❤️', 11),
  ('🎉', 12), ('🙏', 13), ('👏', 14), ('💯', 15), ('🚀', 16), ('🌈', 17),
  ('💪', 18), ('🤝', 19), ('😴', 20), ('🤯', 21), ('🥶', 22), ('😇', 23)
) as e(emoji, pos)
on conflict do nothing;

-- ---------- RLS (открытый прототип, как остальные таблицы) ----------
alter table public.sticker_packs enable row level security;
alter table public.stickers enable row level security;

drop policy if exists sticker_packs_all on public.sticker_packs;
drop policy if exists stickers_all on public.stickers;

create policy sticker_packs_all on public.sticker_packs for all using (true) with check (true);
create policy stickers_all on public.stickers for all using (true) with check (true);