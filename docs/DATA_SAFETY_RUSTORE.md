# RuStore Data Safety — Vibe 1.7.0

**Категории (RuStore консоль):**

| Данные | Собираем | Цель | Шифрование | Удаление |
|---|---|---|---|---|
| Телефон | Да (OTP) | Аутентификация Supabase Auth | TLS, RLS | Удаление аккаунта |
| Имя/аватар | Да | Профиль | TLS, private bucket | Удаление |
| Сообщения (текст/медиа) | Да | Чаты | TLS + E2E X25519/AES-GCM (v2), `media-sign` 3600с, RAM-only queue | `clearHistory`/`deleteMessage` |
| Микрофон/камера | Да (по действию) | Голосовые, кружки, `livekit-token` | TLS, не храним без отправки | Удаление сообщения |
| Контакты (поиск) | Нет телефона, только `display_name` via `searchUsers` | Добавление чата | RLS | — |
| Уведомления | `FCM` токен `profiles` | `send-push` (F-048 без plaintext) | TLS | Отзыв разрешения |
| Биометрия | Опционально | `passcode` разблок | SecureStorage | Откл. в настройках |

**Шифрование:** E2E `devices`/`signed_prekeys`/`one_time_prekeys`, `offline_queue` RAM-only.
**Трекинг:** Нет.
**Сторонние SDK:** `supabase_flutter`, `firebase_messaging/crashlytics`, `livekit_client`, `cryptography`.
**Дети:** 0+.

*Заполнить в консоли RuStore → Data Safety, приложить PRIVACY_RUSTORE.md URL.*
