# UX BEHAVIOR BIBLE — Vibe

> Источник правды о поведении интерфейса. Для каждого паттерна: статус (implemented / partial / not implemented / planned) и место в коде.

## 1. Tap / Double Tap / Long Press

| # (PRD) | Паттерн | Статус | Код |
|---|---|---|---|
| 2.4.1 | Tap: открыть чат, навигация, аватары | implemented | `chat_list_screen.dart:914`, avatar taps в шапках |
| 2.4.2 | Double tap: лайк (chat items, messages) + burst-анимация | implemented (последняя использованная реакция + burst-эффект: большой эмодзи летит в случайную точку с вращением/затуханием, как ReactionsEffectOverlay) | `message_bubble.dart:145-157 (_ReactionBurst)`, `chat_controller.dart:807-853 (heartReact возвращает emoji)` |
| 2.4.3 | Long-press chat: контекст (pin, mute, mark read/unread, delete, archive, hide, folder) | implemented (все TG-действия: pin, mute, archive, hide, mark read/unread, folder, delete с диалогом, select) | `chat_list_screen.dart:166` (`_showChatMenu`, `_confirmDeleteChat`) |
| 2.4.4 | Long-press message: контекст-меню (reply, copy, forward, save, delete, more) | implemented | `chat_screen.dart` (message context menu) |
| 2.4.5 | Long-press media в gallery: share/save/forward/delete | implemented (лонг-пресс по плитке/вьюеру — bottom sheet как в TG: Поделиться/Сохранить/Переслать/Удалить; delete через `controller.deleteMessage`) | `chat_media_gallery_screen.dart` (`_MediaTile` `onLongPress`→`_showMediaActions`, `MediaViewerScreen` long-press) |
| 2.4.6 | Swipe LTR on message: reply | implemented | `message_bubble.dart:146-167` |
| 2.4.7 | Swipe на чате (FullSwipe, как в TG): влево — одно действие из настроек, по умолчанию архив (варианты read/mute/pin/delete), вправо — вернуть из архива; порог 0.45, отмена 200мс, после архива — тост Undo | implemented (полный свайп, одно действие, как в TG Android; верификация по tg-src DialogsActivity SwipeController; настройка — Settings → Свайп по чату; delete с подтверждением) | `chat_list_item.dart` (FullSwipe), `chat_list_screen.dart` (_toggleArchive/_confirmDeleteChat), `chat_settings.dart`, `settings_service.dart` (ChatSwipeAction), `vibe_toast.dart` (Undo) |
| 2.4.8 | Long tap avatar в chat header: профиль контакта | implemented (лонг-тап по шапке открывает профиль, как в TG) | `chat_app_bar.dart:147` (`onLongPress` → `onOpenProfile`), `peer_profile_screen.dart` |
| 2.4.9 | Pull-to-refresh (свайп вниз) списка чатов и ленты | implemented (как в TG: `RefreshIndicator` с `BouncingScrollPhysics`) | `chat_list_screen.dart:513` (`onRefresh: _chat.loadChats()`), `chat_screen.dart:2023` |
| 2.4.10 | Swipe L/R между чатами | implemented (свайп между чатами в `ChatScreen`, как в TG) | `chat_screen.dart:1923` (`_onHorizontalSwipe`, `initialIndex`/`chats`) |
| 2.4.11 | Свайп while typing — временный scroll до дна | implemented (кнопка прыжка вниз + FAB, scroll on typing) | `chat_screen.dart:2353` (`JumpDownButton`), `chat_screen.dart:274` (scroll on new) |
| 2.4.12 | «Пробурить дыру» до первого unread | implemented (плашка «N непрочитанных» + прыжок) | `chat_planks.dart:8` (`UnreadPlank`), `chat_screen.dart:2321` (`unreadJumpIndex`/`jumpToUnread`/`_scrollToEnd`), `chat_controller.dart` (`unreadJumpIndex`) |
| 2.4.13 | Swipe на шапке профиля (avatar+banner единым блоком) | implemented | `profile_screen.dart` (Hero-аватар) |
| 2.4.16/17 | Свайп от правого края экрана → AI-composer (Aurion, как «достать» из любого экрана) | implemented (edge-swipe `32px` + velocity `< -500`, как в TG swipe-back) | `root_shell.dart:187` (`_onEdgeDragStart`/`_onEdgeDragEnd` → `AurionScreen`) |

## 2. Поведение кнопки «назад» (PRD 2.3)

Императивная навигация (`Navigator.push`), системный back — `PopScope` + `Navigator` стек:
- из чата → список чатов ✅ (`ChatAppBar` `onBack` → `pop`, `root_shell.dart:189` `PopScope` → `_openTab(0)`)
- закрытие bottom sheets / панелей / fullscreen media / recorder — штатно по стеку ✅ (`Navigator` каскад, как в TG 2.3.4)
- long-press back (2.3.3) → последние 5 чатов ✅ (`BackHistoryService` 10, `ChatAppBar:147` `onBackLongPress` → bottom sheet, `root_shell.dart:114` `pushChat`/`pushTab`)
- AI-панель (2.3.5): edge-swipe `root_shell.dart:187` → `AurionScreen`, back закрывает как обычный `push` ✅

## 3. Сообщение как объект

- Оптимистичная отправка: мгновенно в ленту, статус `sending`.
- Статусы: `MsgStatus { sending, sent, delivered, read, failed }` (`backend.dart:74`).
- Индикатор `_statusTick` (`chat_screen.dart:2525`): часики → ✓ (sent) → ✓✓ серые (delivered) → синие ✓✓ (read) → красный ⚠ (failed, retry).
- Контекст-меню сообщения: reply, copy, forward, save, delete (+ share/media actions). Открытие — long-press / tap на кнопке «⋯».
- **Реализовано**: реакции (8 эмодзи, меню + double-tap, `chat_controller.dart:806-847`), редактирование в UI (`chat_screen.dart`), закрепление в чате (pin), черновики (draft-индикатор `chat_list_item.dart:162` + sync по сети `chat_controller.dart:312` `backend.saveDraft`/`fetchDraft` + `drafts` таблица), фон чата (2.7.5) — `chat_screen.dart:1239` `wallpaperType` `color`/`gradient` (`_wallpaperDecoration` → `Positioned.fill` `Container` c `LinearGradient`, выбор в `appearance_settings.dart:82`).
- **Не реализовано**: —
- Внешние ссылки `vibe.me/@username` (2.2.1) — обработка запланирована; youtube-ссылки (2.2.2) — не реализовано.

## 4. Лента чата

- `CustomScrollView` с `reverse: true` (новые внизу), пагинация порциями `_pageSize = 80` (`chat_screen.dart`), `_loadOlderIfNeeded` при скролле вверх.
- Разделители по датам (вчера/сегодня).
- Подписки в `ChatScreen`: `stream` (сообщения), `typingEvents` (печатает…), `msgEvents` (edited/deleted/cleared/reactions) — `chat_screen.dart:274–391`.
- Комposer: текст + reply + вложения (фото/видео) + видео-круглый рекордер (`VideoRoundRecorderScreen`, `chat_screen.dart:2149`).
- **Unread-jump бадж**: `UnreadPlank` (`chat_planks.dart:8`) с `unreadJumpIndex` → `jumpToUnread()` + `_scrollToEnd()` (`chat_screen.dart:2321`), плашка «N непрочитанных» внизу — как в TG.

## 5. Список чатов

- `chat_list_screen.dart` (1953 стр., монолит — кандидат на декомпозицию).
- Pinned chats сверху, закрепление через контекст-меню чата.
- Кнопка «новое сообщение» → `NewMessageScreen` (контакты + поиск) и «новая группа» → `CreateGroupScreen` (`chat_list_screen.dart:874`).
- Кнопка stories → `StoryComposerScreen` (`:1040`).
- Поиск → `SearchScreen` (глобальный: люди/сообщения) и `ChatSearchScreen` (внутри чата).
- **Реализовано** (как в TG): archive (`FullSwipe` влево/вправо + `_toggleArchive` + `Undo`), mute per-chat (`toggleDnd` + `mutedVersion`), mark unread/read (`toggleUnread`/`markChatRead`), drafts (`draftFor` + «Черновик:» в `chat_list_item.dart:162`), pinned/drag-reorder (`_reorderChat`), фильтр непрочитанных/папки/архив.

## 6. Профиль (свой)

- `profile_screen.dart`: аватар (фото / emoji+градиент), имя, @username, телефон, био (до 3 строк), «всегда онлайн» (захардкожено зелёным, `:185`), vibe.me-ссылка, QR.
- Действия: копировать телефон/username/ссылку, Saved Messages (реальный чат через `ensureSavedChat`), Настройки, QR, редактор аватара, «Изменить данные» (`EditProfileScreen`), меню (цвет темы, переименовать, копировать ссылку).
- `EditProfileScreen`: name/username/bio (hint «до 70»); «Инфо о пользователе» (дата рождения/город/пол) и «Личный канал» — **заглушки**; «Автоматизация чатов» → `AurionScreen` (реальный).
- «Добавить аккаунт» — заглушка («Мультиаккаунты появятся позже»).

## 7. Профиль собеседника

- `peer_profile_screen.dart`: Hero-аватар, имя (`chat.title`), @username, онлайн-статус (online/recently), био, сетка общих медиа; действия: «Написать» (pop → чат).
- **Заглушки**: аудио/видео звонки (PRD 2.4.8 «медиа контакта» тоже вне).

## 8. Вводные паттерны (PRD 2.1)

Выделение слово-по-слову, перетаскивание границ выделения — `SelectableText`/`TextField` (double-tap word, drag handles, `TextSelectionControls`) — **implemented** (`message_bubble.dart` `SelectableText.rich`, `chat_composer.dart` `TextField`); sticky text input — `Scaffold` `resizeToAvoidBottomInset` + `chat_composer.dart` pinned bottom — **implemented**; кистевой ввод/cursor toggle — **planned** (отложено, нативная клавиатура).

## 9. Настройки как продукт

- Все разделы настроек — реальные экраны с сохранением (`settings_screen.dart` + `settings/*`): уведомления, приватность (passcode, 2FA, devices, селекторы), данные, язык, оформление.
- Приватность: `passcode_screen.dart`, `two_step_verification_screen.dart`, `devices_screen.dart`, `privacy_selector_screen.dart` (кто видит phone/username/last seen и т.п.).
- Автоматизация и AI (PRD 2.5): GigaChat API key как продукт-настройка — см. `AURION_INTELLIGENCE_BIBLE.md`.

## 10. Глобальные состояния UI

- Splash → onboarding → auth → profile_setup → app (root shell: 3 вкладки — чаты/контакты/профиль? проверить root_shell).
- `LockScreen` — passcode lock при входе.
- Keyboard/panels: эмодзи-стикер-панель (`emoji_sticker_panel.dart`), рекордер — закрываются по back штатно.

## Сводка пробелов (кандидаты в фазы)

Реакции, редактирование в UI, drafts, archive/mute/read-unread на чатах, свайп-жесты (2.4.6–2.4.11), unread-jump (fix `_firstUnreadAt`), read receipts для групп (read_by), звонки, мультиаккаунты, геро-декомпозиция чат-списка и chat_screen.
