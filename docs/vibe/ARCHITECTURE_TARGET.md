# ARCHITECTURE TARGET — Vibe (Phase 2 design, 11.08.2026)

> Целевая архитектура после декомпозиции. Правила, слои состояния, именование, структура пакетов. Код пока не пишем — это дизайн.

## 1. Принципы

1. **Single Writer per Layer**: каждый слой состояния имеет одного владельца записи; остальные читают через него.
2. **UI — thin**: экраны не содержат логики данных; логика — в контроллерах (`*Controller`).
3. **Backend — единственный источник истины** для данных, видимых с других устройств; локальные слои — только кеш/экранные представления.
4. **Optimistic + Reconcile**: любая мутация сразу обновляет UI, а realtime-событие сверяет и корректирует.
5. **Idempotent writes**: у каждого клиентского действия есть `client_msg_id`, сервер идемпотентен по нему.
6. **Без новых внешних зависимостей** на этом этапе: setState + контроллеры-классы. Подключение Provider/Riverpod позже — только обёртка над теми же контроллерами (они уже тестируемые).

## 2. Слои состояния (StateEngine)

```
┌─ AppState ───────────── root_shell/main: сессия, тема, локаль, lock, navigation stack
│
├─ SessionState ───────── VibeBackend: JWT, network, realtime-каналы, кеши (5м/2м)
│   └─ PresenceState ──── online/offline пользователей (сейчас: заглушка «всегда онлайн»)
│
├─ ChatListState ──────── ChatListController: чаты, порядок (pinned/recency), unread,
│   │                     превью, поиск по списку
│   └─ ChatListScreenState: скролл, tab-фильтры, search mode
│
├─ ChatState ──────────── ChatController (на каждый открытый чат): лента [_Msg], пагинация
│   │                     (pageSize=80), MsgStatus, typing, selection mode, draft,
│   │                     reply-target, unread-jump
│   └─ ChatScreenState: скролл-позиция, открытые панели (emoji/sticker/recorder), keyboard
│
├─ MediaState ─────────── загрузки/аплоады, подписанные URL (media-sign), прогресс
│
└─ FeatureState ───────── флаги фич (Aurion: introspection/enabled/degraded/disabled)
```

**Правило владения**: `ChatController` — единственный владелец ленты. `ChatScreen` подписывается (`ValueListenable` / `Stream`) и не мутирует `_Msg[]` напрямую. Backend пишет в `ChatController` через события realtime (wire-события → доменные события).

## 3. Команды и события (Command/Event)

### Commands (UI → Controller → Backend)
```
ChatCommand: Send(text, replyTo?) | Edit(msgId, text) | Delete(msgId) | Forward(msgIds, chatId)
             | Copy(msgId) | Save(msgId) | React(msgId, emoji) | MarkRead(chatId)
ChatListCommand: Pin(chatId) | Mute(chatId) | MarkUnread(chatId) | Archive(chatId) | Delete(chatId)
ProfileCommand: UpdateProfile(fields) | SetAvatar(...) | Logout()
AurionCommand: Ask(prompt, contextScope) | ClearHistory() | SetApiKey(key)
```

### Events (Backend/Realtime → Controller → UI)
```
MessageEvent: New(msg) | Updated(msg) | Deleted(msgId) | Cleared(chatId) | StatusChanged(msgId, status)
PresenceEvent: Online(userId) | Offline(userId)
ChatEvent: MemberJoined/Left, TitleChanged, ChatCreated
TypingEvent: Typing(userId, chatId, expiresAt)
ReactionEvent: Reacted(msgId, userId, emoji, add/remove)
```

Каждое доменное событие строго типизировано; wire-формат (supabase realtime) разбирается только в адаптере (`data/`), не в UI.

## 4. Целевая структура пакетов

```
lib/
├─ main.dart
├─ core/                ← без изменений (theme, widgets, services, localization)
├─ data/                ← без изменений (backend, passcode, settings, mock)
│
├─ app/                 ← бывшее screens/: shell, splash, onboarding, auth, lock
│   ├─ root_shell.dart
│   └─ auth/  onboarding/  lock/
│
├─ chat/                ← chat_screen.dart декомпозиция
│   ├─ chat_controller.dart
│   ├─ models.dart        (Msg, MsgStatus, SelectionRange)
│   ├─ widgets/
│   │   ├─ message_bubble.dart      (текст/медиа/статус-тик/дата-разделитель)
│   │   ├─ message_status_tick.dart
│   │   ├─ chat_app_bar.dart
│   │   ├─ chat_composer.dart       (input, attach, reply-preview, emoji/sticker host)
│   │   ├─ chat_list_sliver.dart    (лента: reverse scroll, пагинация, unread-jump)
│   │   ├─ selection_overlay.dart
│   │   └─ context_menu.dart        (reply/copy/forward/save/delete/more)
│   └─ chat_screen.dart             (только сборка: Scaffold + подписки)
│
├─ chats/               ← chat_list_screen.dart декомпозиция
│   ├─ chat_list_controller.dart
│   └─ widgets/
│       ├─ chat_list_item.dart
│       ├─ pinned_section.dart
│       ├─ stories_header.dart
│       └─ chat_search_bar.dart
│
├─ profile/  contacts/  settings/  stories/  groups/  aurion/
│   └─ ... (перенос экранов из screens/ по мере фаз)
```

Миграция: **одна фаза = перенос одного экрана**, путь не ломается (старые импорты обновляются по `screens/` → новому пути).

## 5. Правила именования

| Что | Правило | Пример |
|---|---|---|
| Контроллер | `<Домен>Controller` | `ChatController` |
| Состояние | `<Домен>State` (не виджет) | `ChatListState` |
| Виджет | описание роли, kebab→snake | `message_bubble.dart` |
| Событие | `*Event` | `MessageEvent.Updated` |
| Команда | `*Command` | `SendCommand` |
| Wire-адаптер | `*Wire` в `data/` | `MessageWire.fromRealtime(...)` |
| Status tick | `*_tick` | `message_status_tick.dart` |

## 6. Что остаётся неизменным

- `VibeBackend` — единый вход в Supabase; контроллеры не трогают realtime/supabase напрямую.
- Дизайн-система `core/theme` + `core/widgets` — библиотека, без логики данных.
- `NotificationService` — слушает события `ChatEvent`/`MessageEvent` на уровне `SessionState`, не из экранов.
- RLS/миграции — серверная ответственность; клиент никогда не строит SQL-строк.

## 7. Критерии готовности декомпозиции

- `flutter analyze` — 0 ошибок на каждом шаге.
- Поведение 1:1 (скриншот-сравнение основных путей: лента, отправка, статусы, контекст-меню, pin).
- Ни один файл в `lib/chat/` и `lib/chats/` не превышает ~600 строк.
- Контроллеры покрыты unit-тестами (чистая логика без виджетов).
