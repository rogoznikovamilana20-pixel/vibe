# PRODUCT BIBLE — Vibe

> Источник правды о продукте и архитектуре. Обновляется только осознанно, вместе с кодом.

## 1. Формула продукта

**Vibe = App Shell + Communication Engine + State Engine + Entity/Action System + Aurion Intelligence Layer + Privacy/Security Layer**

- Самостоятельный продукт, визуально не Telegram-клон; механики зрелого мессенджера — ориентир.
- Telegram — только эталон UX-паттернов, не источник дизайна.

## 2. Принципы

1. **Быстрый и тактильный**: мгновенные реакции, отзывчивый UI.
2. **Дзен**: минимум шума, отступы, воздух.
3. **Параметры как продукт**: настройки всегда работают, сохраняются, не бывают «кнопкой-пустышкой». Реальные состояния.
4. **Сообщение как объект**: reply/copy/forward/save/delete/выделение/реакции.
5. **No fake features**: кнопка без бэкенда — либо интерфейс с честным состоянием, либо скрыта.
6. **Existing code first**: расширять работающее, не переписывать.
7. **Aurion — слой, не экран**: AI живёт внутри composer, меню сообщения, поиска — не отдельный чат.

## 3. Слои (физическая карта)

| Слой | Где живёт | Ответственность |
|---|---|---|
| App Shell | `lib/main.dart`, `lib/screens/root_shell.dart`, splash/onboarding/auth/lock | запуск, сессия, навигация, темы, локализация |
| UI экраны | `lib/screens/**` | виджеты, жесты, стейт экрана |
| Design System | `lib/core/theme/*`, `lib/core/widgets/*` | цвета, типографика, отступы, радиусы, иконки, motion, компоненты |
| State/Сервисы | `lib/core/services/*`, `lib/data/*` | уведомления, passcode, настройки, профиль |
| Backend | `lib/data/backend.dart` (`VibeBackend`) | Supabase: auth, БД, storage, realtime, presence |
| Аудит-слой (будущее) | `lib/core/aurion/*` (v2.0) | провайдеры AI, intent router, permission manager, tool registry, feature flags |

## 4. Текущая архитектура (факт, аудит 11.08.2026)

### 4.1 Бэкенд
- **Supabase** (auth JWT, Postgres, RLS, realtime, storage). URL/ключи — через `--dart-define` / `.env.example` (`lib/core/env_config.dart`).
- `VibeBackend` — синглтон (`init()`): восстанавливает JWT, поднимает realtime-каналы, сетевой мониторинг.
- Логин: `login(phone, password)`, телефон → email `…@vibe.local`. Регистрация `register()`, профиль создаёт серверный триггер.
- RLS: per-row политики (владелец профиля, членство в чате), `password_hash` скрыт column grants.
- Сессии: таблица `sessions` + `auth_logout`, вместо self-made UUID.
- Медиа: подписанные URL через edge-функцию `media-sign` (JWT-права; avatars — любой auth; stories/media/messages — участник).

### 4.2 Realtime
- Каналы per-user: личный `user:{id}` канал (новые чаты, presence, входящие события) + подписки на чаты (`stream`, `typingEvents`, `msgEvents` в `chat_screen.dart`).
- `msgEvents`: edited/deleted/cleared/reactions.

### 4.3 Состояния сообщений
- `MsgStatus { sending, sent, delivered, read, failed }` (`backend.dart`).
- Оптимистичная отправка: мгновенная вставка, статус до «sent».
- `_statusTick` (`chat_screen.dart`) — часики/✓/✓✓/синие ✓✓/красный error.
- **Known limitation**: `_firstUnreadAt => throw UnimplementedError()` — первое непрочитанное не реализовано. Read receipts частично: миграция `supabase/migrations/migrate_v1_7_0_read_state.sql` существует; delivered покрыто, «прочитано» (группы/read_by) — не полностью.

### 4.4 Кеши
- `profileById` — 5 мин; `chatMemberIds` / `chatKindOf` — 2 мин (в `VibeBackend`).

### 4.5 Уведомления
- `NotificationService` (`lib/core/services/notification_service.dart`): realtime → баннер (foreground) / локальное уведомление (background). Гейтинг: личные/группы, превью, звук/вибрация — из `SettingsService`.

## 5. Аудит: найденные проблемы

- `_firstUnreadAt` — UnimplementedError (заглушка).
- READ receipts в группах — нет списка читателей (read_by) в UI.
- Реакции (классические/emoji) — нет совсем (PRD 2.7.3).
- Закреплённые сообщения в чате — нет (есть только pinned chats).
- Drafts — нет.
- Оффлайн-очередь/retry — нет.
- «В сети» в профиле захардкожено зелёным (`profile_screen.dart`).
- Звонки: кнопки «Аудио/Видео» — заглушки.
- Мультиаккаунты — заглушка.
- «Инфо о пользователе» / «Личный канал» в EditProfile — заглушки.
- `chat_list_screen.dart` (1953 стр.) и `chat_screen.dart` (4210 стр.) — монолиты, требуют декомпозиции.
- Aurion — UI-превью («Aurion отвечает — в v2.0»), нет API-интеграции.

## 6. Дорожная карта (сверка с docs/MASTER_PLAN.md)

- **MASTER_PLAN v1.0** зафиксирован 10.08.2026, основан на аудите 35 экранов.
- Закрыто: безопасность/медиа/чаты-группы (Фазы 0–3), stories E2E, профили/уведомления — частично.
- Не реализовано (кандидаты в фазы): свайп между чатами (2.4.10), AI-composer жесты (2.4.16/17), реакции (2.7.3), оффлайн-пересылки (2.7.4), фон чата (2.7.5), галерея (2.7.6), pinned в чате (2.7.7), read receipts группы (2.7.8).
- Детали статусов: `docs/vibe/UX_BEHAVIOR_BIBLE.md`, `docs/vibe/STATE_MACHINE.md`, `docs/vibe/ENTITY_ACTION_MODEL.md`, `docs/vibe/NAVIGATION_MAP.md`, `docs/aurion/AURION_INTELLIGENCE_BIBLE.md`.
