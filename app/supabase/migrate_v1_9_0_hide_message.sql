-- v1.9.0 — Расширенная модель удалений: серверная пометка «скрыто для меня».
-- "Удалить для меня" не стирает сообщение (оно остаётся у других),
-- а добавляет id автора в deleted_by — клиент фильтрует такие сообщения.

alter table public.messages
  add column if not exists deleted_by uuid[] not null default '{}';