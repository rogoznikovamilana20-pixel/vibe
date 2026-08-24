# Launch Runbook — Vibe v1.6.3 (конкурент Telegram)

**Что выкатываем:** 4 прод-блока + 2 критичных фикса — полный релиз мессенджера
- `pg_cron` фикс отложенных (migrate_v1_20)
- Whisper транскрибация голосовых (migrate_v1_21 + whisper-transcribe)
- Мультиаккаунт до 3 (account_service + SecureStorage)
- LiveKit SFU групповые звонки (livekit_client 2.4.1 + livekit-token)
- RLS hardening (migrate_v1_22) — закрываем `using (true)` дыру
- Scheduled double-delivery фикс (ScheduledService cancel чистит Supabase mirror)

**Дата:** 2026-08-24
**Окно:** 30 минут, без maintenance mode (мобильное приложение)
**Lead:** Sisyphus (opencode) + andre
**Deputy:** —

## Роли

| Роль | Кто | Контакт |
|---|---|---|
| Launch lead | Sisyphus | opencode chat |
| Deploy operator | Sisyphus | — |
| QA lead | Sisyphus | — |
| On-call 24ч | andre | — |

## Pre-launch чек (сейчас)

- [x] `flutter pub get` — ok (livekit_client 2.4.1, flutter_webrtc 0.12.12)
- [x] `dart analyze app/lib` — 0 ошибок, 4 info
- [x] Миграции 12 файлов (v1_11 → v1_22) в порядке
- [x] Функции 6/6 (exec-sql, send-push, send-call-invite, send-otp, livekit-token, whisper-transcribe)
- [x] Фиксы: RLS, double-delivery, whisper trigger scope, hasEnabledVideo → videoTrackPublications
- [ ] `supabase link` + `supabase db push` (нужен SUPABASE_ACCESS_TOKEN)
- [ ] `supabase secrets set OPENAI_API_KEY / LIVEKIT_API_KEY/SECRET/URL`
- [ ] `supabase functions deploy whisper-transcribe livekit-token`

## Cutover (T-0, 30 мин)

### 1. Объявить старт
- Owner: lead
- Action: пост в чат "Старт релиза v1.6.3, окно 30 мин"
- Verify: сообщение видно
- Time: 1м

### 2. Бэкап БД
- Owner: deploy
- Action: `supabase db dump -f backup_pre_v1.6.3.sql`
- Verify: файл >0, `pg_restore --list` ок
- Time: 3м
- Rollback: `psql < backup_pre_v1.6.3.sql`

### 3. Миграции
- Owner: deploy
- Pre: бэкап готов
- Action: `supabase db push` (прогонит v1_20, v1_21, v1_22)
- Verify: `supabase migration list` — все `applied`, `cron.job` есть `deliver-scheduled-messages`, `messages` имеет `transcript*`
- Time: 2м
- Rollback: `supabase db reset --linked` + восстановить бэкап, или вручную `drop policy` + `cron.unschedule`

### 4. Секреты
- Owner: deploy
- Action: `supabase secrets set OPENAI_API_KEY=... LIVEKIT_API_KEY=... LIVEKIT_API_SECRET=... LIVEKIT_URL=wss://...`
- Verify: `supabase secrets list` — 4 ключа
- Time: 1м

### 5. Функции
- Owner: deploy
- Action: `supabase functions deploy whisper-transcribe livekit-token --no-verify-jwt` (JWT проверяем внутри)
- Verify: `curl -H "Authorization: Bearer $ANON" $URL/functions/v1/whisper-transcribe` → 400 (не 500), аналогично livekit-token → 401 без токена, 200 с JWT
- Time: 3м
- Rollback: `supabase functions deploy --use-previous`

### 6. Приложение
- Owner: deploy
- Action: `flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
- Verify: `build/app/outputs/flutter-apk/app-release.apk` существует, `aapt dump badging` версия 1.6.3
- Time: 5м
- Rollback: предыдущий apk из `build/` архива

### 7. Дымовой тест (прод)
- Owner: QA
- Action: установить apk, логин по телефону, отправить текст/голосовое/отложенное (на 1 мин), групповой звонок 2 юзера, переключить аккаунт
- Verify: отложенное пришло через ~60с (cron), голосовое → через 5-10с `transcript` в `messages`, LiveKit комната `group_{chatId}` коннектится, мультиаккаунт переключает без ре-логина
- Time: 10м
- Rollback: если критичный флоу падает → откат шага 3-5

### 8. Объявить успех
- Owner: lead
- Action: пост "Релиз v1.6.3 выкачен, все чеки зелёные"
- Time: 1м

### 9. Мониторинг 60м
- Owner: on-call
- Action: `supabase logs --level error` + `firebase crashlytics`, смотреть `pg_cron` логи, `whisper-transcribe` 502, `livekit-token` 401
- Verify: error rate <1%, нет 5xx

## Rollback критерии

**Авто-откат (без споров):**
- [ ] `messages` RLS ломает чтение (пустой список чатов у всех)
- [ ] `pg_cron` не создался — отложенные не доставляются
- [ ] `whisper-transcribe` 500 на всех войсах
- [ ] `livekit-token` 500 — групповые не коннектятся

**Дискреционно (решает lead):**
- [ ] Транскрипт >15с задержка
- [ ] LiveKit эхо/лаг >2с

**Кто зовёт откат:** lead (Sisyphus) или andre

## Коммуникация
- Канал: opencode чат + Telegram andre
- Каданс: каждые 10м во время cutover
- Клиентам: пост после шага 8

## Верификация (первый час)
- [ ] Логин/регистрация по телефону
- [ ] Текст + silent + отложенное (1 мин) + редактирование + удаление
- [ ] Голосовое → транскрипт появится
- [ ] Фото/видео/файл
- [ ] Звонок 1:1 (WebRTC) — коннект <5с
- [ ] Групповой (LiveKit) — 2 участника, mute/камера/шаринг
- [ ] Мультиаккаунт — 2 номера, переключение
- [ ] Офлайн-очередь — авиарежим → отправить → онлайн → доставилось
- [ ] Пуши — бекграунд → тап → открывает чат

## Верификация (24ч)
- [ ] Нет роста crashlytics >5%
- [ ] pg_cron `select * from cron.job_run_details where jobname='deliver-scheduled-messages' order by start_time desc limit 5` — все `succeeded`
- [ ] Supabase Storage `voice` < 1GB

## Контакты
| Роль | Контакт |
|---|---|
| Supabase project | rgdwfoicidnamejluxfx |
| LiveKit Cloud | wss://... (из secrets) |
| OpenAI | sk-... (из secrets) |

## Пост-релиз
- [ ] AAR через неделю (шаблон из after-action-report)
- [ ] Залить `launch-runbook-v1.6.3.md` в `docs/`
- [ ] Обновить `MAPPING.md` если нужно
