# Политика конфиденциальности Vibe — RuStore 1.7.0

**Дата:** 30.08.2026  
**Приложение:** Vibe Messenger (`com.vibe.messenger`), 1.7.0+2  
**Контакты:** support@vibe.messenger (заглушка, заменить на реальный)

## 1. Какие данные собираем
- **Профиль:** `display_name`, `avatar` (хранение Supabase `profiles`, RLS по `auth.uid()`), `phone` — только для OTP через Supabase Auth, не показывается другим без `copyWithPrivacySafe`.
- **Сообщения:** `chats`/`messages` — текст/медиа, `media-sign` выдаёт подписанный URL 3600с, проверка членства в чате (аноним 401, чужой 403). E2E X25519+AES-GCM для `v2_` таблиц (`devices`, `signed_prekeys`).
- **Устройства:** `devices` — публичные ключи X25519/Ed25519, без приватных.
- **Разрешения:** `RECORD_AUDIO`/`CAMERA` — только по тапу (голосовые, кружки), `POST_NOTIFICATIONS` — по запросу, `USE_BIOMETRIC` — опционально для `passcode`.

## 2. Что не собираем
- Не продаём, не трекаем рекламу. `offline_queue` — RAM-only, не пишется на диск в plaintext (как Signal).

## 3. Хранение и RLS
25 таблиц, `rowsecurity=true`, 63 политики (проверено `pg_tables`). `storage.buckets: avatars` private. Бэкапы — Supabase PITR.

## 4. Удаление
Удаление аккаунта — `DELETE FROM auth.users` каскадом `profiles`/`chats`/`messages`. Запрос на support.

## 5. Контакты
Поиск `searchUsers` без телефона, `add_contact` через `ensurePmChat`.

---
*Шаблон для RuStore, заменить контакты и хостинг политики (URL).*
