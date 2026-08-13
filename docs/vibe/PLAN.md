# PLAN.md — Vibe (execution log)

> Живой план исполнения. Каждая фаза: статус, сделанное, артефакты, проверка (lint/analyze/тесты).

## Phase 1 — Audit & Documentation ✅ (завершена 11.08.2026)

### Сделано
- Запущены 3 параллельных аудита кода (explore-агенты):
  - Backend (`lib/data/backend.dart`, realtime, миграции, env, notification_service)
  - Экраны (35 экранов: chat, chat list, search, stories, onboarding/auth/lock)
  - Профиль/группы/настройки (profile, peer_profile, groups, settings tree, aurion, edit_profile)
- Изучены корневые доки: `docs/MASTER_PLAN.md`, `docs/PRD.md` (извлечены паттерны 2.1–2.7 и статусы фич).
- Написаны 6 источников правды:
  1. `docs/vibe/PRODUCT_BIBLE.md` — формула, слои, факт-архитектура, проблемы, дорожная карта
  2. `docs/vibe/UX_BEHAVIOR_BIBLE.md` — жесты/паттерны PRD 2.x со статусами и путями в коде
  3. `docs/vibe/STATE_MACHINE.md` — сессия, жизненный цикл сообщения, read state, кеши, realtime-каналы
  4. `docs/vibe/ENTITY_ACTION_MODEL.md` — сущности и действия (backend API), gap list
  5. `docs/vibe/NAVIGATION_MAP.md` — 35 экранов, карта переходов, правила, проблемы
  6. `docs/aurion/AURION_INTELLIGENCE_BIBLE.md` — Aurion: факт (UI-превью), vision v2.0, флаги, гигиена, этапы

### Ключевые находки
- `_firstUnreadAt` — UnimplementedError (backend.dart:334).
- Read receipts частичны; read_by в группах нет.
- Реакции, drafts, edit-UI, archive/mute, свайп-жесты, unread-jump, звонки, мультиаккаунты — не реализовано.
- `chat_screen.dart` (4210 стр.) и `chat_list_screen.dart` (1953 стр.) — монолиты.
- Aurion — UI-превью без API.
- Навигация — только императивный push, нет named routes/deep links.

### Проверка
- Статические (Flutter) проверки в этой фазе не требовались — только чтение кода и доков.

## Phase 2 — Проектирование ✅ (завершена 11.08.2026)

### Сделано
- Собраны факты: структура `lib/` (64 файла), зависимости (нет state-менеджмента, чистый setState), размеры монолитов (`chat_screen.dart` 3991, `chat_list_screen.dart` 1877).
- Написаны 3 дизайн-документа:
  1. `docs/vibe/ARCHITECTURE_TARGET.md` — StateEngine (слои состояния), Single Writer, Command/Event-модель, целевая структура пакетов (`app/`, `chat/`, `chats/`, ...), правила именования, критерии готовности
  2. `docs/vibe/REFACTORING_PLAN.md` — пошаговая декомпозиция chat_screen (7 шагов) и chat_list_screen (4 шага), порядок с фазами фич, гарантии
  3. `docs/vibe/OPEN_DECISIONS.md` — 8 открытых решений (D1–D8) с рекомендациями

### Открытые решения (решены 11.08.2026)
- D1 state management: **ValueNotifier + контроллеры** (решено мастером, «реши сам»)
- D2 декомпозиция: **пошагово: виджеты → контроллеры → фичи**
- D3 порядок: **декомпозиция → бэкенд-фиксы**
- D4 реакции: **классические emoji** с панелью 6 быстрых + «+» (решено мастером, «что красивее»)
- D5 read_by в группах: после MVP
- D6 фон чата — после Фаз A/B/C; галерея — после реакций
- D7 Aurion: после стабилизации чата
- D8 локализация: точечно при прикосновении

### Проверка
- Статические проверки не требовались (дизайн-фаза).

## Phase 3 — Реализация: Фаза A декомпозиции ✅ (частично, 11.08.2026)

### Сделано (flutter analyze = 0 после каждого шага)
- `lib/chat/` создан:
  - `chat/models.dart` — `ChatMsg`, `MsgType`, `ChatReaction`, `buildLinkSpans` (публичные, были `_Msg` и др.)
  - `chat/widgets/message_bubble.dart` — `MessageBubble` + bubble-виджеты (text/photo/voice/video/sticker, swipe-reply, double-tap ❤️, реакции, статусы), `EqualizerWave` (public)
  - `chat/widgets/chat_composer.dart` — `SendButton`, `ReplyPanel`, `RollingPill`, `VideoRollPill`, `AttachmentItem`, `ReactionButton`, `ActionRow`
  - `chat/widgets/chat_app_bar.dart` — `ChatAppBar`, `SheetCallTile`
  - `chat/widgets/chat_menu_sheet.dart` — `ChatMenuSheet` (многоуровневое меню: уведомления/mute-на-время)
  - `chat/widgets/message_status_tick.dart`, `message_date_divider.dart`, `jump_down_button.dart`
- `lib/chats/` создан: `chats/widgets/story_circle.dart` (`StoryCircle`), `chats/widgets/compose_fab.dart` (`ComposeFAB`)
- `chat_screen.dart`: **3991 → 1879 строк**; `chat_list_screen.dart`: **1953 → 1829 строк**
- Исправлена порча line-endings после скриптовой правки (нормализация CRLF, analyze чистый)
- Удалены неиспользуемые импорты (dart:math, dart:ui, video_player, gestures, notifications_settings)

### Проверка
- `flutter analyze` — 0 issues
- Поведение 1:1 (чистая экстракция без изменения логики)

### Следующее
- Фаза A остаток: `ChatListItem` (tile) — перенести вместе с `ChatListController` (Фаза B), т.к. tile глубоко связан с состоянием списка
- Фаза B: `ChatController` + `ChatListController` (лента, пагинация, статусы, typing, realtime-подписки) + unit-тесты
- Фаза C: фичи — unread-jump (fix `_firstUnreadAt`), read receipts групп (read_by), реакции emoji, draft, edit-UI, mute/archive в списке
- Aurion: после Фаз A/B/C (D7)

## Phase 3 — Реализация: Фаза B контроллеров ✅ (12.08.2026)

### Сделано (flutter analyze = 0)
- `lib/chat/chat_controller.dart` — `ChatController` (ChangeNotifier, Single Writer data-plane чата):
  - лента `messages` (reverse: 0 = новое), пагинация (`loadMessages`/`loadOlderIfNeeded`, page 80)
  - realtime-подписки: `stream` (статусы по localId, новые входящие, `newIncoming`), `typingEvents` (`peerTyping`), `msgEvents` (edited/deleted/cleared/reactions)
  - отправка: `send` (текст + ответ/цитата + правка), `sendSticker`, `sendPhoto`, `sendVoice`, `sendVideo`
  - действия: `addReaction`, `heartReact`, `replyToMsg`, `startEdit/cancelEdit`, `setReply`, `deleteMessage`, `setPin`, `jumpToPinned`, `setGroupTitle`, `markRead`
  - `notifyTyping` (throttle 2.5 c), `onScroll`/`jumpToBottom` (atBottom/newIncoming)
- `lib/chat/chat_list_controller.dart` — `ChatListController` (ChangeNotifier, Single Writer data-plane списка):
  - лента `chats` (кэш → сеть), статусы: `pinned/archived/dnd/hidden/read/selected`
  - подписки: `stream` (live-превью), `chatEvents`, `presenceVersion`, `mutedVersion/blockedVersion`, cloud-архив/DND, тикер 20 c
  - действия: `togglePin`, `setMuted`, `setArchived`, `toggleDnd`, `toggleArchived`, `markChatRead`, `markRead`, `markArchived`, `markHidden`, `toggleSelect`, `removeSelected`, `clearSelection`
- `chat_screen.dart`: **1879 → 1377 строк** (лента/события/отправка/реакции/пин/typing → в контроллер; на экране остались ввод, запись, камера, скролл, навигация)
- `chat_list_screen.dart`: **1584 → 1316 строк** (после Фазы B остаток: tile вынесен в `ChatListItem`)
- Исправлена порча line-endings `chat_list_screen.dart` (двойной `\r\r\n` на 1825 строках → CRLF, поведение 1:1)

### Проверка
- `flutter analyze` — 0 issues
- Поведение 1:1: все мутации списков переехали в контроллеры без изменения логики (setState → notifyListeners через ListenableBuilder)

## Phase 3 — Фаза B остаток: DI + unit-тесты + ChatListItem ✅ (12.08.2026)

### Сделано (flutter analyze = 0, flutter test: 40/40)
- `lib/chats/widgets/chat_list_item.dart` — `ChatListItem` (чистый StatelessWidget, контракт: данные + callbacks): Dismissible-свайпы (архив/DND), превью, время-пилюля, pin, DND-иконки, unread-бейдж, мультивыбор, Hero-аватар; swipe-логика и snack-строки остались в экране (было 1584 → 1316 строк)
- `lib/core/widgets/vibe_island.dart` — общая «островная» подложка (`VibeIsland`), используется тайлом и плиткой «Архив»
- **DI-слой**: `lib/data/backend_api.dart` — `VibeBackendApi` (интерфейс: ровно методы/потоки контроллеров) + `LiveVibeBackend` (адаптер поверх `VibeBackend.instance`); `backend.dart` не тронут
- Контроллеры принимают `VibeBackendApi backend` (default `LiveVibeBackend()`), все обращения к синглтону заменены
- **Unit-тесты** (36 новых + 4 существующих icon-теста):
  - `test/fake_vibe_backend.dart` — in-memory фейк: ленты, realtime-эмит, журнал вызовов, флаги ошибок
  - `test/chat_controller_test.dart` (22): загрузка/пагинация (page 80, `hasMoreOlder`), отправка (оптимизм → ack по localId, ответ-цитата, правка, сетевой сбой), стикер/голос, realtime (входящее + `newIncoming`, typing-таймер 4 c через fake_async, edited/deleted/reactions), реакции-переключатели, deleteMessage (для всех/для меня), setPin → SettingsService, typing-троттлинг 2.5 c
  - `test/chat_list_controller_test.dart` (14): load статусы (настройки + облако), кэш→сеть, live-превью, unreadOf, мультивыбор (read/archive/hidden/remove/clear + snack), togglePin/toggleDnd/toggleArchived (сервер + настройки), syncCloudMuted/syncCloudArchive
- `fake_async` добавлен в dev_dependencies (pub get --offline)

### Найденные и исправленные баги (пойманы тестами)
- `ChatMsg.copyWith` терял `stickerEmoji` → стикер ломался после realtime-ack/обновлений (lib/chat/models.dart)
- `ChatListController.removeSelected` — `chats.removeWhere(selected.contains)`: `Set<String>.contains` принимает `Object?`, чаты никогда не удалялись; исправлено на `(c) => selected.contains(c.id)` (lib/chat/chat_list_controller.dart)

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 40/40 passed

### Следующее
- Фаза C: фичи — unread-jump (fix `_firstUnreadAt`), read receipts групп (read_by), draft, «Непрочитанные»-плашка, галерея; в чат-листе — папки (8.3.7), «Сохранённые» (8.3.8)
- Aurion: после Фаз A/B/C (D7)

## Phase 3 — Фаза C (порция 1): draft + unread-jump ✅ (12.08.2026)

### Сделано (flutter analyze = 0, flutter test: 47/47)
- **Черновики (draft)**, как в ТГ:
  - `SettingsService`: `draftFor(chatId)` / `setDraft(chatId, text?)` (ключ `vibe_drafts:<chatId>`)
  - `ChatController`: поле `draft` (восстанавливается в `load()` синхронно), `saveDraft(text)` с дебаунсом 400 мс (нет записи в prefs на каждое нажатие), `clearDraft()` при успешной отправке; на `dispose` — сохранение невылитого черновика
  - `chat_screen.dart`: восстановление `_input.text` при входе, `saveDraft` на onChanged
  - `ChatListItem`: превью `Черновик: …` акцентным цветом вместо lastMessage; `chat_list_screen` передаёт `draftFor(id)` и делает `setState` после возврата из чата (`await push`)
- **Unread-jump (8.4.2)**, как в ТГ:
  - `ChatController`: `initialUnread` (из карточки чата), `unreadJumpIndex` (первое непрочитанное в reverse-ленте; плашка скрыта, если непрочитанных нет или первое уже внизу), `jumpToUnread()` — сообщение временно поднимается к низу с подсветкой `unreadFlashId`, через 3 c возвращается на место (паттерн jumpToPinned)
  - `chat_screen.dart`: плашка «Непрочитанные: N» по центру внизу → тап = прыжок + `_scrollToEnd`
- `_firstUnreadAt` в текущем коде отсутствует (был в старом аудите) — серверная часть unread-jump не нужна для клиентской плашки

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 47/47 (добавлено 7: draft x4, unread-jump x3)

### Следующее
- Фаза C (порция 2): read receipts групп (read_by) — серверная часть; draft-индикатор в чат-листе (9.2 виджет-тест); галерея чата
- Фаза C список: папки (8.3.7), «Сохранённые» (8.3.8)
- Aurion: после Фаз A/B/C (D7)

## Phase 3 — Фаза C (порция 2): галерея чата ✅ (12.08.2026)

### Сделано (flutter analyze = 0, flutter test: 49/49)
- `lib/chat/chat_media_gallery_screen.dart` — галерея медиа чата (D6, паттерн ТГ «Медиа»):
  - `ChatMediaItem` (kind photo/video, photoSeed, photoUrl, videoUrl, videoPath); коллекция собирается из ленты контроллера (`MsgType.photo`/`MsgType.video`)
  - `ChatMediaGalleryScreen(controller, chatTitle)` — ListenableBuilder + GridView 3 колонки; плитка: фото через `VibeNetImage` или градиент-сид; видео — play-бейдж; пустое состояние «Пока нет медиа»
  - `MediaViewerScreen(items, initialIndex)` — полноэкранный просмотр: PageView-свайп между элементами, фото — зум `InteractiveViewer` (maxScale 5), видео-кружки — `VideoPlayerController` (networkUrl/file, play/pause по тапу, авто-loop); close-кнопка
- `ChatMenuSheet`: пункт «Медиа» (`onTapMedia`) перед «Поиском в чате»
- `chat_screen.dart`: `_openMedia()` → push `ChatMediaGalleryScreen(controller: _chat, chatTitle: …)` (стр. 459)
- `VibeNetImage.resolveUrl` — статический инжектируемый резолвер пути (дефолт `VibeBackend.instance.mediaUrl`); в тестах подменяется фейком (иначе падение на null-синглтоне)

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 49/49 (добавлено 2: сетка+пустое состояние, тап по плитке → просмотрщик; `pumpAndSettle` в тесте заменён на фиксированные pump — в просмотрщике живой спиннер не оседает)

### Следующее
- Фаза C (порция 3): read receipts групп (read_by) — серверная часть (отложена: нет доступа к SQL/БД); draft-индикатор в чат-листе (9.2 виджет-тест)
- Фаза C список: папки (8.3.7 — уже в коде), «Сохранённые» (8.3.8)
- Aurion: после Фаз A/B/C (D7)

## Phase 3 — Фаза C (порция 3): «Сохранённые» (8.3.8) ✅ (12.08.2026)

### Сделано (flutter analyze = 0, flutter test: 49/49)
- **Единая точка входа**: плитка «Сохранённые» (bookmark-градиент, подпись «Избранные сообщения») — первым элементом списка чатов (только основной список, не архив/скрытые); тап → `_openSaved` (уже был: `ensureSavedChat()` + `chatById` + push `ChatScreen`); слайс-индексы SliverList пересчитаны под `savedExtra`
- **«Сохранить сюда»**: пункт «Сохранить в Избранное» в меню сообщения → `_saveToSaved(msg)`: `ensureSavedChat()` → `forwardMessage(savedId, …)` → snack «Сохранено в Избранное»
- Бэкенд-часть уже существовала: `ensureSavedChat()` (backend.dart:1026, чат kind=pm с собой), входы из FAB-меню «Избранное» и профиля

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 49/49 (регрессия без новых тестов: фича — чисто UI-слой поверх готового API)

### Следующее
- Фаза C (порция 4): read receipts групп (read_by) — серверная часть (отложена: нет доступа к SQL/БД); draft-индикатор в чат-листе (9.2 виджет-тест)
- Aurion: после Фаз A/B/C (D7)

## Phase 3 — Фаза C (порция 4): виджет-тесты чат-листа (9.2) ✅ (12.08.2026)

### Сделано (flutter analyze = 0, flutter test: 55/55)
- `test/chat_list_item_test.dart` (6 тестов) — ChatListItem изолированно (контракт: данные + callbacks):
  - имя/превью/время-пилюля + unread-бейдж «3»
  - черновик: «Черновик: …» акцентным цветом вместо превью, превью отсутствует
  - pin-иконка + DND-иконка (trailing-стек)
  - мультивыбор: галочка `check_circle` + `Dismissible.direction == none`
  - архивный чат: «В архиве» вместо lastMessage
  - тап/длинный тап → callbacks (счётчики)
- Тест требует `SharedPreferences.setMockInitialValues` + `SettingsService.instance.init()` (тема читает accentColorValue)

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 55/55 (+6)

### Следующее
- Фаза C (порция 5): read receipts групп (read_by) — серверная часть (отложена: нет доступа к SQL/БД); виджет-тесты чата (квитанции, ответы, редактирование — 9.2)
- Aurion: после Фаз A/B/C (D7)

## Phase 3 — Фаза C (порция 5): виджет-тесты чата (9.2) ✅ (12.08.2026)

### Сделано (flutter analyze = 0, flutter test: 62/62)
- `test/message_bubble_test.dart` (7 тестов) — MessageBubble изолированно (контракт: ChatMsg + колбэки):
  - текст + время + галочка `check` для sent
  - квитанции: delivered → `done_all`; read → `done_all` синий 0xFF8AB4F8; failed → `error_outline`
  - входящее сообщение — галочек статуса нет
  - replyText → превью ответа «На что я отвечаю»
  - edited → метка «изменено»
  - forwardedFrom → «Переслано от Иван»
  - двойной тап → onHeart (искра); тест прокачивает 950 мс, чтобы погасить `Future.delayed` из `_onDoubleTap`
- Тест требует `SharedPreferences.setMockInitialValues` + `SettingsService.instance.init()`

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 62/62 (+7)

### Следующее
- Фаза C (порция 6): read receipts групп (read_by) — серверная часть (отложена: нет доступа к SQL/БД)
- Aurion: после Фаз A/B/C (D7); Фаза 9: виджет-тесты экранов целиком

## Aurion (D7): сервис, экран, AI_PREVIEW draft-first ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 76/76)
- `lib/core/aurion/aurion_provider.dart` — `AurionProvider` (name, capabilities, configure, ping, complete), `AurionRequest`, `AurionException`
- `lib/core/aurion/aurion_service.dart` — синглтон `AurionService` (ChangeNotifier):
  - статусы `disabled / enabled / degraded` (onset: p404 → degraded)
  - `enable(apiKey)` — secretStorage → ping провайдера → persist; `disable()`
  - `complete(text)` — без ключа/не enabled → `AurionException`; сбой провайдера → degraded + `AurionDegradedException`
  - `providerFactory`, `secretStorage` — инжектируемые (тесты), default `AurionApiProvider` (прототип завершения)
- `lib/screens/aurion_screen.dart` (630 строк) — экран «Aurion» (паттерны UX 2.1–2.7):
  - `VibeCollapsibleScreen` + top bar с бейджем статуса (онлайн/аварийный/выключен)
  - disabled → карточка подключения (поле API-ключа + «Подключить»); невалидный ключ → ошибка в карточке
  - enabled → hero + суггестии (4 шт.) + AI_PREVIEW draft-first: «Ответ Aurion» с кнопками «Вставить в поле» / «Копировать», композер с прогрессом-спиннером, кнопка-стрелка с HapticFeedback
  - сбой провайдера → error-карточка «Aurion временно недоступен» + «Повторить», заголовок окна «аварийный»
- **Тесты** (`test/aurion_service_test.dart` 10, `test/aurion_screen_test.dart` 4):
  - сервис: init без ключа → disabled; enable → ping-флоу; degrade на сбое; complete требует enabled; сохранение ключа в secret storage; disable
  - экран: disabled → карточка; невалидный ключ → ошибка; enabled → суггестии → запрос → AI_PREVIEW → вставка в поле; сбой → ошибка + «Повторить»
  - `FakeAurionProvider` + `InMemorySecretStorage` (вместо real platform channels)

### Исправленные баги (пойманы тестами)
- Ряд кнопок превью (`Row` + TextButton: «Копировать» / «Вставить в поле») переполнялся на 129 px вправо при ширине 360 — тап «Вставить в поле» уходил за экран; заменён на `Wrap` (перенос кнопок на новую строку)
- Тест экрана: SliverList лениво строит элементы — превью/ошибка были ниже вьюпорта; увеличена физическая высота вьюпорта + `ensureVisible` вместо drag/scrollUntilVisible

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 76/76 passed

## Phase 3 — Фаза C (порция 6): виджет-тесты экранов целиком (9.2) ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 89/89)
- DI-шов для тестов экранов (без изменения поведения, default — живой бэкенд):
  - `ChatScreen({chat, backend})`, `ChatListScreen({userName, backend, ...})` — опциональный `VibeBackendApi? backend` → `LiveVibeBackend()` по умолчанию
  - `VibeBackendApi` += `connectivityVersion`, `isOffline`, `listStories()` (нужны в build-путях экранов); `LiveVibeBackend` делегирует, `FakeVibeBackend` реализует
  - `NotificationService`: `FirebaseMessaging` стал ленивым/опциональным (`_messaging` getter с try/catch) — в widget-тестах Firebase нет, FCM-ветки тихо отключаются; production-поведение не изменилось (Firebase инициализирован в приложении)
  - офлайн-баннер в обоих экранах и `_loadStories` читают `_backend` вместо `VibeBackend.instance`; действия (сохранение/пересылка/сториз-аплоад) остались на instance
- `test/chat_screen_test.dart` (8 тестов) — экран целиком: вход (лента + композер), пустой ввод (микрофон), отправка sendText, realtime входящее обновляет ленту, ack исходящего (failed→sent), сетевой сбой (ошибка + повтор), плашка непрочитанных (scrollTo), правка по меню → updateMessage
- `test/chat_list_screen_test.dart` (5 тестов) — экран целиком: лента (названия/превью/непрочитанные), плитка «Сохранённые» (первый элемент), realtime-превью, свайп вправо → архив (setChatArchived), длинное нажатие → меню → «Выбрать чаты» → режим выбора → «Снять выделение»

### Исправленные баги (пойманы тестами)
- `_showMessageActions` (chat_screen): bottom-sheet меню сообщения переполнялось по вертикали (нижние пункты «Редактировать»/«Удалить» недостижимы на низких экранах) — обёрнуто в `SingleChildScrollView`
- `NotificationService._fcm` инициализировался при первом обращении к синглтону и падал без Firebase (widget-тесты) — теперь лениво и с дефолтом null

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 89/89 (+13: 8 chat_screen + 5 chat_list)

## Phase 3 — Фаза C (порция 7): насыщение тест-покрытия чата (9.3) ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 93/93)
- `chat_screen_test.dart` +4 (12 всего): «Удалить для всех» → deleteMessage + исчезание из ленты; «Удалить для меня» — только локально; «Закрепить» → плашка закреплённого под шапкой + открепление крестиком; «Переслать» → ForwardPickerScreen → выбор чата → forwardMessage в цель
- DI доведён до конца: `_saveToSaved`/`_openForward` используют `_backend` (widget.backend ?? LiveVibeBackend()) вместо `VibeBackend.instance`; `VibeBackendApi` += `myProfileId`, `ensureSavedChat`, `forwardMessage`; `FakeVibeBackend` реализует (журнал forwardCalls)

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 93/93 (+4)

### Следующее
- Фаза 9.4: короткая ссылка — редактирование (UI + бэкенд); Aurion: после Фаз A/B/C (D7)

## Phase 3 — Фаза C (порция 8): короткая ссылка — редактирование (9.4) ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 95/95)
- `edit_profile_screen.dart`: живая проверка ника на занятость с дебаунсом 300 мс (как в Telegram): ошибка «Этот никнейм уже занят» под полем (VibeInput.errorText), сохранение блокируется; свой текущий ник не считается занятым
- Бэкенд-фикс: `isUsernameAvailable` исключает собственный id из проверки (`.neq('id', myProfileId)`), иначе нельзя было сохранить свой же ник
- DI: `EditProfileScreen({backend})`; `VibeBackendApi` += `isUsernameAvailable`, `updateProfile`
- `test/edit_profile_screen_test.dart` (2): занятый ник → live-ошибка + блокировка сохранения; свободный ник → сохранение уходит

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 95/95 (+2)

### Следующее
- Фаза 9.5: короткая ссылка — «мои ссылки» list; Aurion: после Фаз A/B/C (D7)

## Phase 3 — Фаза C (порция 9): короткая ссылка — «Мои ссылки» (9.5) ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 98/98)
- `lib/screens/my_links_screen.dart` — экран «Мои ссылки» (вход: профиль → «Мои ссылки»):
  - список ссылок на профиль: «Ссылка на профиль» (vibe.me/@ник), «Имя пользователя» (@ник), «Телефон» (если указан) — тап по плитке → копировать + snack
  - «QR-код профиля» → шит с QrImageView и «Копировать ссылку»
  - имя/ник берутся из `VibeBackend.myProfileNotifier` (+ userName как фолбэк)
- `test/my_links_screen_test.dart` (3): список с полными значениями; тап по ссылке → «Скопировано: …»; QR-шит открывается (QrImageView + кнопка)
- Хелпер теста: mock `SystemChannels.platform` для Clipboard (без него Clipboard.setData падает в widget-тесте)

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 98/98 (+3)

### Следующее
- Фаза 9.6: расширенная модель правок; Aurion: после Фаз A/B/C (D7)

## Phase 3 — Фаза C (порция 10): расширенная модель правок (9.6) ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 99/99)
- **Сервер**: `supabase/migrate_v1_8_0_message_edits.sql` — таблица `message_edits` (message_id, text, edited_at, индекс, RLS открытая как у messages)
- **Бэкенд**: `updateMessage` пишет снимок старого текста в `message_edits` перед апдейтом (текущий текст живёт в messages, как и раньше); `listMessageEdits(messageId)` — снимки от новых к старым (лимит 50); модель `MessageEdit`; `VibeBackendApi` += `listMessageEdits`
- **UI**: у изменённого сообщения в меню — «История правок» → шит со снимками текста (пусто → «Правок не найдено»; сбой → «Сервер недоступен»)
- `test/chat_screen_test.dart` +1: меню у edited-сообщения → снимки в шите + вызов listMessageEdits

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 99/99 (+1)

### Следующее
- Фаза 9.7: расширенная модель удалений; Aurion: после Фаз A/B/C (D7)

## Phase 3 — Фаза C (порция 11): расширенная модель удалений (9.7) ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 99/99)
- **Сервер**: `supabase/migrate_v1_9_0_hide_message.sql` — колонка `messages.deleted_by uuid[]` («скрыто для меня»)
- **Бэкенд**: `hideMessageForMe(messageId)` добавляет мой id в `deleted_by` (сообщение остаётся у других); `listMessages` фильтрует помеченные для меня (кэш-фолбэк срабатывает только если сервер реально вернул пусто — не затирает скрытие)
- **Контроллер**: `deleteMessage(everyone: false)` теперь не только убирает локально, но и помечает на сервере (сбой сервера не критичен — локально уже скрыто)
- Тест контроллера обновлён: «удалить для меня» → `hiddenMessageIds == ['m1']`

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 99/99

### Следующее
- Фаза 9.8: тесты реального потока сообщений (send/read-confirm/erase/«безопасный UID»); Aurion: после Фаз A/B/C (D7)

## Phase 3 — Фаза C (порция 12): тесты реального потока сообщений (9.8) ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 100/100)
- **Erase (очистить историю) — из заглушки в фичу**:
  - `ChatMenuSheet.onClearHistory` (nullable; без него — прежняя заглушка «в v2.0»)
  - `chat_screen` → диалог подтверждения («Очистить историю?» → «Очистить»/«Отмена») → `ChatController.clearHistory()`: сервер `clearHistory(chatId)` + очистка ленты локально (не жду realtime)
  - `VibeBackendApi` += `clearHistory`; `FakeVibeBackend` журналирует
- **Фикс реального потока (пойман при аудите 9.8)**: при сбое отправки исходящее оставалось `sending` навсегда — теперь `send`/`sendSticker`/`sendVoice`/`sendVideo` помечают сообщение `MsgStatus.failed` (пузырь показывает «повторить»)
- Тесты: `chat_screen_test` +1 «очистить историю» (меню → подтверждение → clearHistory + лента пуста); `chat_controller_test` send-ошибка теперь проверяет `failed`

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 100/100

### Следующее
- Фаза 9.9: логика и фиксы (навигация по чатам, вложенные ответы >50, стейт-менеджмент); Aurion: после Фаз A/B/C (D7)

## Phase 3 — Фаза C (порция 13): логика и фиксы 9.9 ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 102/102)
- **Навигация по чатам**: `ChatListScreen` теперь прокидывает свой backend в `ChatScreen(chat: chat, backend: _backend)` (было `ChatScreen(chat: chat)` — в тестах чат открывался на живом бэкенде). Новый тест: тап по чату → ChatScreen рендерит сообщения через тот же fake → назад → лента цела.
- **Вложенные ответы (>50 симв.)**: `_ReplyQuote` уже ограничивает `maxLines: 2` + ellipsis; добавлен защитный widget-тест с ответом >50 симв. (нет exception, цитата видна).
- **Стейт-менеджмент (промежуточные состояния)**: в 9.8 зафиксирован статус `failed` при сбое отправки; в этой порции — покрытие тестами.

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 102/102

### Следующее
- Фаза 9.10: аудит строк (хардкод/интернационализация) + неработающего кода (заглушки) к prod

## Phase 3 — Фаза C (порция 14): аудит строк и заглушек 9.10 ✅ (13.08.2026)

### Аудит (flutter analyze = 0, flutter test: 102/102)
- **Заглушки (9 шт.)** — все с честным degraded-состоянием (snack «— в v2.0»/«— скоро»): звонки (chat_screen, peer_profile), сведения о чате, стикеры, инфо о пользователе, создание канала, добавление контакта, сброс уведомлений. Соответствуют правилу «No fake features» — оставлены, перенос в локализацию — вместе с полной локализацией чата (known gap).
- **Хардкод-строки**: найдена и исправлена подпись в локализованном экране `language_settings` («Доступные сейчас: …») → новый ключ `languagesAvailable` (ru/en). (Локализованы: онбординг, настройки, профиль, лок-экран; чат — на русском, локализация чата — known gap, вне этой фазы.)
- **`_firstUnreadAt` (UnimplementedError)** — нигде не вызывается (требование AGENTS соблюдено).
- Прочий неиспользуемый/мёртвый код в рамках экранов чата не найден (fallback `«Очистить историю — в v2.0»` в ChatMenuSheet остаётся как честный degraded-путь при отсутствии колбэка).

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 102/102

### Следующее
- Фаза 9.11: мелочи перед prod + финальные прогоны; локализация чата — отдельный флайт (known gap)

## Phase 3 — Фаза C (порция 15): мелочи перед prod + финальные прогоны (9.11) ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 102/102)
- **Release-прогон**: `flutter build apk --release` успешно (65.9MB, Gradle 8.13 / Kotlin 2.1.20 — предупреждения о будущем drop, не блокируют)
- **Prod-мусор**: в lib/ только `debugPrint` (no-op в release), `print(`/`kDebugMode`-артефактов нет
- Строки/версия: `vibe_app` 1.6.3+1

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 102/102; `flutter build apk --release` — OK

### Следующее
- По master-списку далее: фазы 9.12–9.13 (определения в master-промпте) + официальные пункты MASTER_PLAN: 9.3 Golden-тесты тем, 9.4 integration-тесты, 9.5 CI, 9.6 PERF, 9.7 TASKS; Aurion — после Фаз A/B/C (D7)

## Phase 3 — Фаза C (порция 16): Golden-тесты тем (9.3 MASTER_PLAN) ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 104/104)
- `test/theme_contrast_test.dart` — программный «золотой контракт» контрастов тем (WCAG 2.x, не пиксельные снимки — стабильно на любой платформе):
  - **Гарантии** (падение = дефект): onSurface/фон ≥4.5, onSurfaceVariant/фон ≥4.5 (это bodyMedium!), tertiary/фон ≥3.0, карточки/elevated ≥4.5, inverse ≥4.5 — обе темы зелёные
  - **Золото** (эталон 13.08.2026, расхождение >0.15 падает): зафиксированы 9 пар на тему (17.91…2.83)
- **Найден дефект дизайн-системы**: текст ошибок на светлой теме — контраст 2.83 (ниже 3:1, AA для мелкого текста 4.5). Dark — 6.47 (ok). Улучшение: отдельный дизайн-флайт («error» на светлой → темнее, напр. #E5484D-диапазон).
- Компромиссы под AA (зафиксированы золотом, не красные): accent/фон light 3.94 (крупный текст/UI), onPrimary на accent 4.23 (крупный текст кнопок).

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 104/104 (+2)

### Следующее
- По master-списку: следующий пункт (9.12/9.13) или MASTER_PLAN 9.4 integration-тесты; далее: 9.5 CI, 9.6 PERF, 9.7 TASKS, Aurion D7

## Phase 3 — Фаза C (порция 17): integration-тесты (9.4 MASTER_PLAN) 🚧 blocked-env (13.08.2026)

### Сделано
- Инфраструктура: `integration_test` (SDK-зависимость в pubspec) + `integration_test/app_boot_test.dart` — smoke-boot реального приложения: сплэш → онбординг без сети, без падений, с проверкой жизни (скролл онбординга). Запуск:
  `flutter test integration_test/app_boot_test.dart -d windows --dart-define=SUPABASE_URL=http://127.0.0.1:9 --dart-define=SUPABASE_ANON_KEY=test-anon-key`

### Блокировка окружения (не код)
- **Windows desktop**: `flutter_secure_storage_windows` требует `atlbase.h` — в Visual Studio Build Tools 2022 не установлен компонент ATL/MFC (C1083). Фикс: установить workload «C++ ATL».
- **Chrome**: «Web devices are not supported for integration tests yet».
- **Android**: AVD `vibe35` не стартует («emulator exited with code 1», гипервизор/backend).
- Как только окружение починено — прогон команды выше = проверка 9.4 (`flutter analyze`/`flutter test` при этом 104/104, без регрессий).

### Следующее
- 9.5 CI (GitHub Actions: analyze+test+apk — не зависит от эмулятора), 9.6 PERF, 9.7 TASKS, Aurion D7

## Phase 3 — Фаза C (порция 18): CI (9.5 MASTER_PLAN) ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 104/104)
- **Локальный гейт** `app/tool/verify.ps1` (PS 5.1, ASCII-only): analyze (0 issues) → полный flutter test → детект временных файлов тестов (test_out/test_full/integ_out/golden_tmp — за пределами build/) → опционально `-Apk` release-сборка. Прогнан: **CI gate passed (EXIT=0)**.
- **GitHub Actions** `.github/workflows/vibe.yml` (push main / PR): checkout → flutter stable → pub get → analyze → test → build apk debug → upload-artifact. Репозиторий пока без remote — workflow готов к первому пушу.
- Попутно: из индекса удалён случайно закоммиченный `app/test_full.txt` (повторный след 9.3).

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 104/104

### Следующее
- 9.6 PERF-аудит (рис), 9.7 TASKS

## Phase 3 — Фаза C (порция 19): PERF-бенчмарки (9.6 MASTER_PLAN) + реестр TASKS (9.7) ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 107/107)
- **`test/perf_performance_test.dart`** — PERF-регрессионная сетка (widget-тесты, бюджеты 8s):
  - старт ленты: 300 чатов — **~0.7s**
  - скролл: 5 fling по 300 чатам — **~3.2s** (ловит O(n²)/деградации)
  - чат со 150 сообщениями: **~0.25s**
- **`docs/TASKS.md` (9.7)** — реестр задач: статус всех фаз 8–9, тестовый щит (0 issues / 107/107 / release apk / CI-гейт), known gaps, следующие пункты.
- MASTER_PLAN: 9.6 и 9.7 → [x].

### Проверка
- `flutter analyze` — 0 issues; `flutter test` — 107/107 (+3 PERF)

### Следующее
- Следующие пункты мастера: после фаз 8–9 фиксы/фичи v1.0 (Phase 4–18), Aurion D7

## Phase 3 — Фаза C (порция 20): баги Фазы 2 + PIN 1.6 ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 112/112, CI-гейт EXIT=0)
- **2.8 исправлен**: шапка секции настроек использовала ключ `settings` и дублировала заголовок «Настройки» → новый ключ `generalSettings` («Основные настройки»/«General Settings»); `test/settings_screen_test.dart` (2 теста: ru/en, единственный «Настройки» и «Settings» на экране + секции в UPPER CASE).
- **1.6 подтверждён + закреплён тестами**: PasscodeService уже полный (sha256+random salt в SecureStorage, maxAttempts=5, блокировка 30s, авто-лок, биометрия) — MASTER_PLAN 1.6 → [x]; `test/passcode_service_test.dart` (3 теста через mock MethodChannel secure_storage): пароль нигде не лежит открыто, верный код сбрасывает попытки, 5 ошибок → блокировка (даже верный код отклоняется).
- **2.10 аудит**: демо-сториз закрыты `showDemoStories = false` (ветка за флагом) — пункт закрыт.

### Проверка
- CI-гейт `verify.ps1` — passed; analyze 0; 112/112 (+5: settings 2, passcode 3)

### Следующее
- Фаза 2: остался 2.11 (кликабельная аватарка в profile_setup); 1.7/1.8 крипто; 3.x персистентность; 5.x скорость; 8.x UX

## Phase 3 — Фаза C (порция 21): кликабельная аватарка (2.11) ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 115/115, CI-гейт EXIT=0)
- **2.11**: аватарка в `ProfileSetupScreen` стала рабочей (была заглушка `onTap: () {}`):
  - новый общий виджет `AvatarActionSheet` (core/widgets) — шит «Выбрать из галереи / Сделать фото / Удалить аватар»; из `profile_screen` дубль `_AvatarSheet` удалён (DRY)
  - в profile_setup: тап → шит → `pickAndEdit`/`takeAndEdit` (editor) → `ProfileAvatar.save` + `uploadAvatar` (сбой синка — честный snack «без синхронизации»); `del` → `remove` + `removeRemoteAvatar`
  - аватарка рендерит фото из `ProfileAvatar.myPhoto` (или эмодзи), рамка толще при фото
- `test/profile_setup_screen_test.dart` (3): шит открывается/закрывается, выбор эмодзи обновляет аватар, фото показывается
- Попутно починен assert: ListTile в DecoratedBox без Material (было бы видно и в профиле на debug-сборках) — обёртка `Material(type: transparency)`

### Проверка
- analyze 0; `verify.ps1` passed; 115/115 (+3)

### Следующее
- Фаза 2 закрыта полностью. Далее: 3.x (персистентность), 5.x (скорость), 1.7/1.8 (крипто), 8.x UX

## Phase 3 — Фаза C (порция 22): 3.5 множественные закрепы в облаке ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 120/120, CI-гейт EXIT=0)
- **SQL** `supabase/migrate_v1_10_0_chat_pins.sql`: таблица `chat_pins(chat_id, message_id, pinned_by, created_at)` PK (chat_id, message_id), индекс, RLS (стиль проекта: все-политика, принадлежность проверяет клиент).
- **Backend** (`backend.dart`): `fetchChatPins` (сортировка created_at desc — новые сверху), `pinMessage`, `unpinMessage`; realtime `pinEvents` (postgres_changes insert/delete на chat_pins, чужие пины, проверка `_isMyChat`); тип `PinChanged`; проброс в `VibeBackendApi`/`LiveVibeBackend`.
- **Controller** (`chat_controller.dart`): `pins` (список, новые сверху) + getter `pinMsgId` (совместим со старым контрактом экрана); `setPin(null)` снимает верхний; повторный пин того же — открепить; облако — best-effort (сбой → локальный список, не фейк); `_refreshPinsFromServer` не перетирает локальные пины, сделанные во время запроса; локальный кеш в SettingsService переведён на список (`pinnedMessageIds`).
- **UI** (`chat_screen.dart`): баннер показывает верхний закреп + «ещё N»; тап при >1 — шит «Закреплённые сообщения» (прыжок к сообщению / откреп по строке); меню сообщения «Открепить» — по факту принадлежности списку.
- Тесты +5: мульти-пины/порядок/облако, повторный пин и null, замена локального кеша облаком, деградация без таблицы, realtime применения, баннер «ещё 1» + шит + откреп.

### Проверка
- analyze 0; verify.ps1 passed; 120/120 (+5)

### Следующее
- 3.4 скрытые чаты; 5.x (скорость: инвалидация, пагинация по скроллу); 1.7/1.8 крипто; 8.3.5 шторка

## Phase 3 — Фаза C (порция 23): 3.4 скрытые чаты ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 125/125, CI-гейт EXIT=0)
- **Персистентность**: `SettingsService.hiddenChats` + `hiddenVersion`; контроллер загружает при старте, `markHidden`/`setHidden` сохраняют, `syncHidden` синхронизирует между экранами. (Раньше скрытие жило только в памяти — терялось при перезапуске.)
- **Замок**: папка «Скрытые чаты» открывается только после ввода пасскода (`LockScreen`, биометрия тоже работает через него). Без ПИНа — диалог с переходом в `PasscodeSettingsScreen`. Разблокировка живёт сессией экрана и сбрасывается при сворачивании приложения (WidgetsBindingObserver).
- **Меню чата**: «Скрыть чат» / «Показать чат» (long-press), описание подпункта.
- **Приватность пушей**: сообщения скрытых чатов не дают уведомлений (`notification_service`).
- Тесты +5: персистентность между сессиями контроллера, setHidden-туда/обратно, syncHidden, виджет-гейт без ПИНа (диалог), виджет-гейт с ПИНом (LockScreen → папка).

### Проверка
- analyze 0; verify.ps1 passed; 125/125 (+5)

### Следующее
- 3.7 приватность → сервер; 5.x скорость; 1.7/1.8 крипто; 8.3.5 шторка

## Phase 3 — Фаза C (порция 24): 3.8 отмена отправки 5 сек ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 129/129, CI-гейт EXIT=0)
- **Undo-окно** в `ChatController`: после успешной отправки (текст/стикер/фото/голосовое/видео) включается окно `undoWindow` (5 с); `undoAvailable` + `undoLastSend()` — удаляет сообщение для всех (`backend.deleteMessage`) и, для текста, возвращает текст в композер (`draft` + `draftRestoreVersion`, экран подхватывает в `_input`).
- **UI**: пилюля «Отменить отправку» (Material + InkWell, иконка undo) под последним пузырём — появляется только внутри окна, исчезает сама по таймеру.
- **Попутный фикс**: эхо-подтверждение своей отправки теперь забирает `serverId` (+`stickerEmoji`; `ChatMsg.copyWith` расширен) — раньше свежеотправленные сообщения нельзя было удалить/править до перезагрузки.
- Тесты +4: окно открывается и закрывается через 5 с (fakeAsync), undoLastSend (удаление + возврат текста + версия), no-op без окна, виджет-пилюля (появление, тап → удаление + текст в поле).

### Проверка
- analyze 0; verify.ps1 passed; 129/129 (+4)

### Следующее
- 3.7 приватность → сервер; 3.9 scheduled; 3.10 свёртка цепочек; 5.x скорость; 1.7/1.8 крипто

## Phase 3 — Фаза C (порция 25): 3.10 свёртка цепочек ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 133/133, CI-гейт EXIT=0)
- **Группирование**: соседние сообщения одного автора (incoming) с разницей <= 7 минут (`ChatController.groupWindow`) — одна группа. `ChatController.inSameGroup` / `isFirstInGroup` / `isLastInGroup` — статические, без дат — не группируются.
- **Визуал** (`MessageBubble`): внутри группы вертикальный отступ 1px (снаружи 3px), радиусы «срастаются» — полные углы только у верхнего (первого) и нижнего (последнего, с направленным «хвостом») сообщения группы; средние — плоские (min(r, 4)).
- Тесты +4: unit — границы окна 7 мин / разрыв по автору / края группы в reverse-списке / стык авторов; widget — флаги групп у пузырей в chat_screen.

### Проверка
- analyze 0; verify.ps1 passed; 133/133 (+4)

### Следующее
- 3.7 приватность → сервер; 3.9 scheduled; 4.x Cloud Pinning рефактор; 5.x скорость; 1.7/1.8 крипто

## Phase 3 — Фаза C (порция 26): 2.12 сведения о чате ✅ (13.08.2026)

### Сделано (flutter analyze = 0, flutter test: 134/134, CI-гейт EXIT=0)
- **«Сведения о чате»** в меню чата (`ChatMenuSheet` → `onChatInfo`) вместо заглушки «в v2.0»: шит с аватаром, названием, типом (`Личный чат`/`Группа`/`Канал` по `chat.kind`), участником (для PM) и счётчиком сообщений из загруженной истории. Только локальные данные — без фейков.
- **Фаза 2 полностью закрыта** (в MASTER_PLAN все 2.x отмечены).
- Тест +1: виджет — меню → шит с типом, участником и счётчиком.

### Проверка
- analyze 0; verify.ps1 passed; 134/134 (+1)

### Следующее
- 3.7 приватность → сервер; 3.9 scheduled; 4.x Cloud Pinning рефактор; 5.x скорость; 1.7/1.8 крипто

## Следующие фазы (из master-промпта)

- **Phase 3 (продолжение)** — Фаза B: контроллеры; Фаза C: фичи из gap list
- **Phase 4–18** — реализация по плану (фичи, Aurion v2.0)

---
*Формат пунктов: [x] — готово; [ ] — в работе. Обновляется по завершении каждой фазы.*
