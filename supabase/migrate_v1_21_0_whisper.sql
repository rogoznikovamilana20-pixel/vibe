-- Whisper транскрибация голосовых: текст + язык + статус
alter table public.messages
  add column if not exists transcript text,
  add column if not exists transcript_language text,
  add column if not exists transcript_status text not null default 'pending'
    check (transcript_status in ('pending','processing','completed','failed'));

-- Индекс для выборки незавершённых транскриптов (дешёвый partial index)
create index if not exists messages_transcript_status_idx
  on public.messages (id) where transcript_status in ('pending','processing');
