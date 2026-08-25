-- GAP1: reply_to FK для кросс-девайс превью и прыжка (как в TG replyMessageId)
alter table public.messages add column if not exists reply_to uuid references public.messages(id) on delete set null;
alter table public.messages add column if not exists reply_text text;
alter table public.messages add column if not exists reply_author text;
create index if not exists messages_reply_to_idx on public.messages(reply_to);
