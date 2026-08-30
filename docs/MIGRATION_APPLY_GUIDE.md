# Применение миграций Vibe + деплой media-sign

## Проблема
В проде `rgdwfoicidnamejluxfx` — 14 таблиц, отсутствуют `devices` (v1_14) и `businesses/*` (v1_25). Все 15 файлов `migrate_v1_11→v1_25` не применены. Причина: `supabase link` падает (LegacyLinkApiKeysNetworkError, IPv6-only, без Docker).

## Порядок применения (Dashboard → SQL Editor → Run по очереди, каждый файл целиком)

1. `supabase/migrate_v1_11_0_privacy.sql` (975B)
2. `supabase/migrate_v1_12_0_cleanup_rls.sql` (4941B) — чистка RLS
3. `supabase/migrate_v1_13_0_call_safety.sql` (738B)
4. `supabase/migrate_v1_14_0_e2e_v2.sql` (5399B) — создает `devices` + индексы
5. `supabase/migrate_v1_15_0_drafts.sql` (641B)
6. `supabase/migrate_v1_16_0_reply_to.sql` (455B)
7. `supabase/migrate_v1_17_0_privacy_extra.sql` (378B)
8. `supabase/migrate_v1_18_0_scheduled.sql` (797B)
9. `supabase/migrate_v1_19_0_scheduled_cron.sql` (816B)
10. `supabase/migrate_v1_20_0_scheduled_fix.sql` (1075B)
11. `supabase/migrate_v1_21_0_whisper.sql` (636B)
12. `supabase/migrate_v1_22_0_rls_hardening.sql` (3459B) — hardening
13. `supabase/migrate_v1_23_0_e2e_devices_rls_fix.sql` (532B)
14. `supabase/migrate_v1_24_0_fix_username_trigger.sql` (1484B)
15. `supabase/migrate_v1_25_0_business_scalable.sql` (7761B) — businesses, members, showcases, chats, metrics_daily

После каждого: `select * from storage.buckets; select table_name from information_schema.tables where table_schema='public' and table_name like 'business%';`

Ожидаем: `devices` + 5 `business*` таблиц появятся.

## Buckets
Сейчас один `avatars` (private=false→true after migrations). Для `stories/media/messages` пока используется тот же бакет `avatars` с префиксом `stories/...` (см. `media_backend.dart: uploadStory` → `storage.from('avatars').uploadBinary('stories/...')`). Отдельные бакеты `stories/media/messages` можно не создавать — `media-sign` работает с любым префиксом внутри `avatars`. Если хотите изоляцию — создайте через Dashboard Storage → New bucket (private).

## Деплой media-sign

Файл создан: `supabase/functions/media-sign/index.ts` (210 строк, JWT + проверка членства в чате + `POST /storage/v1/object/sign` через `VIBE_SVC_KEY`).

Деплой (один из вариантов):

**Вариант A — CLI (требует Docker + supabase link):**
```bash
supabase link --project-ref rgdwfoicidnamejluxfx  # нужен SUPABASE_ACCESS_TOKEN
supabase functions deploy media-sign --no-verify-jwt
supabase secrets set VIBE_SVC_KEY=<SERVICE_ROLE_KEY> SUPABASE_URL=https://rgdwfoicidnamejluxfx.supabase.co SUPABASE_ANON_KEY=<anon>
```

**Вариант B — Dashboard (без CLI):**
Dashboard → Edge Functions → Create function `media-sign` → вставить содержимое `supabase/functions/media-sign/index.ts` → Deploy → Secrets добавить `VIBE_SVC_KEY`.

Проверка после деплоя:
```bash
# anon → 401
curl -X POST https://rgdwfoicidnamejluxfx.supabase.co/functions/v1/media-sign -H "Content-Type: application/json" -d '{"bucket":"avatars","path":"avatars/test.jpg"}' # 401

# auth чужой чат → 403, свой → 200
# через Dart: VibeBackend.instance.mediaUrl("avatars/<id>/...") → должен вернуть signed URL, flutter analyze 0
```

## Фикс клиента
Исправлено `app/lib/data/media_backend.dart`: `mediaUrl` теперь извлекает `bucket = path.split('/').first` вместо хардкода `avatars` (было `invoke('media-sign', body:{bucket:'avatars',...})` для всех). `flutter analyze` — 4 info (как было).

## Что дальше
1. Применить 15 миграций по списку выше.
2. Деплой `media-sign` + `VIBE_SVC_KEY`.
3. `flutter test` (85 тестов) + `flutter build apk --dart-define`.
