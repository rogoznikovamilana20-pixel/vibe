# REFACTORING PLAN — декомпозиция монолитов (Phase 2 design)

> Как безболезненно разбить `chat_screen.dart` (было 3991 стр.) и `chat_list_screen.dart` (было 1953 стр.). Правило: **каждый шаг — компилируемая, поведенчески идентичная единица** (`flutter analyze` = 0). Декомпозиция идёт **до** больших фич (реакции, read_by), чтобы фичи сразу писались в правильных файлах.

## Статус на 12.08.2026

- ✅ Фаза A выполнена: `chat_screen.dart` 3991 → 1879 стр., `chat_list_screen.dart` 1953 → 1829 стр.
- ✅ Новые пакеты: `lib/chat/` (models + 7 файлов виджетов), `lib/chats/` (2 файла виджетов)
- ✅ Фаза B выполнена: `ChatController` + `ChatListController` + DI (`VibeBackendApi`/`LiveVibeBackend` в `lib/data/backend_api.dart`) + unit-тесты (36)
- ✅ `ChatListItem` (tile) вынесен в `chats/widgets/chat_list_item.dart` (+ общий `core/widgets/vibe_island.dart`) — `chat_list_screen.dart` 1584 → 1316 стр.
- ⏳ Следующее: Фаза C (фичи из gap list)

## 0. Общие правила шага

1. Перед шагом: `flutter analyze` — 0 ошибок, 0 предупреждений (базовая линия).
2. Шаг = перенос кода без изменения поведения (никакой новой логики).
3. После шага: `flutter analyze` + ручная проверка ключевого пути (лента/отправка/меню).
4. Импорты внутри `lib/` — относительные пути по целевой структуре (см. ARCHITECTURE_TARGET §4).
5. Крупный State (100+ строк) переносится вместе со своими методами; виджеты выносятся первыми.

## 1. Декомпозиция `chat_screen.dart`

Порядок шагов (каждый уменьшает файл на ~300–700 строк):

| Шаг | Что выносится | Куда | Выход |
|---|---|---|---|
| 1 | `_statusTick` (статусы: часики/✓/✓✓/синие/error) | `chat/widgets/message_status_tick.dart` | чистый StatelessWidget, вход `MsgStatus` |
| 2 | Date separator + системные сообщения (create/leave) | `chat/widgets/message_date_divider.dart` | StatelessWidget |
| 3 | MessageBubble: текст/медиа-карточки/вложения, собранные из шагов 1–2; контекст-меню (reply/copy/forward/save/delete) | `chat/widgets/message_bubble.dart` | контракт `MessageBubble(msg, isMine, onMenu...)` |
| 4 | Composer: VibeInput, attach-кнопки, reply-preview, host для `emoji_sticker_panel.dart`, кнопка видео-рекордера, отправка | `chat/widgets/chat_composer.dart` | контракт `ChatComposer(controller, callbacks)` |
| 5 | AppBar чата: title (name/typing), avatar, кнопки (search, profile/group info, more) | `chat/widgets/chat_app_bar.dart` | контракт `ChatAppBar(chat, members, ...)` |
| 6 | **ChatController**: лента `_Msg[]`, пагинация `_pageSize=80` / `_loadOlderIfNeeded`, оптимистичная отправка, статусы, typing, selection mode, draft, reply-target, unread-jump | `chat/chat_controller.dart` | `ChatController(backend)` + `ValueNotifier<ChatState>`; подписки realtime (stream/typingEvents/msgEvents) переносятся сюда из State |
| 7 | `chat_screen.dart` остаётся обёрткой: Scaffold + подписка на controller + сборка виджетов | `chat/chat_screen.dart` | ≤ 400 строк |

**Проверка каждого шага**: `flutter analyze`; ручные пути: отправка → статус → доставка; reply; контекст-меню; пагинация вверх; typing.

## 2. Декомпозиция `chat_list_screen.dart`

| Шаг | Что выносится | Куда | Выход |
|---|---|---|---|
| 1 | ChatListItem: аватар, имя, превью, время, статус-пиктограмма, pin, unread-бейдж | `chats/widgets/chat_list_item.dart` | `ChatListItem(chat, onTap, onLongPress)` |
| 2 | Stories header (аватары историй) + search bar + кнопки нового чата/группы | `chats/widgets/stories_header.dart`, `chats/widgets/chat_search_bar.dart` | контракты с callbacks |
| 3 | **ChatListController**: подписка на чаты (stream), сортировка (pinned → recency), unread-счётчики, контекст-меню чата (pin/delete/…) | `chats/chat_list_controller.dart` | `ValueNotifier<ChatListState>`; навигация остаётся в Screen |
| 4 | `chat_list_screen.dart` — обёртка | `chats/chat_list_screen.dart` | ≤ 400 строк |

## 3. Порядок с фазами фич

1. **Фаза A**: Шаги 1–5 chat_screen (виджеты) + шаги 1–2 chat_list (виджеты) — чистая экстракция, без рисков, даёт каркас.
2. **Фаза B**: `ChatController` + `ChatListController` (шаги 6/3) — ключевая точка: сюда потом вешаются реактивные фичи (read_by, unread-jump) и тесты.
3. **Фаза C**: фичи из gap list в новых файлах: unread-jump (fix `_firstUnreadAt`), read receipts групп (read_by), реакции, draft, edit-UI, mute/archive.
4. **Фаза D**: остальные экраны мигрируют в `app/`, `profile/`, `settings/` и т.д. по мере необходимости.

## 4. Гарантии и «золотые» файлы

- `chat/chat_controller.dart` и `chats/chat_list_controller.dart` — единственные места, где живёт логика ленты; UI не знает про `_Msg[]` напрямую.
- `data/backend.dart` — НЕ меняется в рамках декомпозиции (только если фича требует).
- Виджеты `core/widgets` — не принимают `VibeBackend` и не зависят от `data/`.
- После Фазы B контроллеры получают unit-тесты (независимы от Flutter-виджетов).
