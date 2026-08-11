# Vibe

Мобильный мессенджер с неоновой тёмной темой. Flutter + Supabase (auth по телефону, chats/messages с realtime, профили, сториз, FCM-пуши).

## Возможности

- Вход по номеру телефона (OTP через Supabase Auth), настройка username/аватара
- Личные чаты: текст, фото, голосовые, сообщения поверх градиентов
- Realtime-обновления, статусы участников
- Лента сторис: свои (локально) и публичные из облака (`stories`), вьювер
- Настройки: био (синхронизируется с `profiles.bio`), аватар, плотность списка, радиус пузырей, размер шрифта, фонты, тёмная/неоновая тема
- Push-уведомления через FCM: Edge Function `send-push` по вебхуку INSERT в `messages`

## Бэкенд (Supabase)

Применение миграции (био + таблица stories + RLS):

```
supabase db push        # или выполнить supabase/push_setup.sql в SQL Editor
```

Push-уведомления:

1. `supabase functions deploy send-push`
2. `supabase secrets set FIREBASE_SERVICE_ACCOUNT="<base64 от firebase-adminsdk service account JSON>"`
3. В Dashboard → Database → Webhooks создать вебхук на `INSERT` в `messages`, URL: `https://<project-ref>.functions.supabase.co/send-push`

Код функции: `app/supabase/functions/send-push/index.ts` (JWT через google-auth-library, отправка через FCM v1).

## Конфигурация

Секреты не хранятся в репозитории — передаются через `--dart-define`
(заготовка: `.env.example`):

```
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

Без этих флагов приложение стартует с понятной ошибкой (`EnvConfig.missingError`).

## Сборка

```
flutter pub get
flutter analyze
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...   # APK: build/app/outputs/flutter-apk/app-release.apk
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Конфиг Android: AGP 8.11.1, Kotlin 2.1.20, Gradle 8.13, applicationId `com.vibe.messenger`.

## Структура

- `lib/data/backend.dart` — клиент Supabase (профили, чаты, сообщения, сторис, realtime)
- `lib/screens/` — экраны (списки чатов, чат, настройки, OTP и др.)
- `lib/core/` — сервисы (FCM, локализация, темы), дизайн-токены (VibeColors/VibeTypography/VibeShadows)
- `android/app/src/main/kotlin/com/vibe/messenger/MainActivity.kt` — точка входа Android
- `supabase/` — миграции и Edge Functions