# UX BEHAVIOR BIBLE — Vibe

> Источник правды о поведении интерфейса. Для каждого паттерна: статус (implemented / partial / not implemented / planned) и место в коде.

## 1. Tap / Double Tap / Long Press

| # (PRD) | Паттерн | Статус | Код |
|---|---|---|---|
| 2.4.1 | Tap: открыть чат, навигация, аватары | implemented | `chat_list_screen.dart:914`, avatar taps в шапках |
| 2.4.2 | Double tap: лайк (chat items, messages) | not implemented | — |
| 2.4.3 | Long-press chat: контекст (pin, mute, mark read/unread, delete) | partial (pin/delete есть; archive/mute частично) | `chat_list_screen.dart` |
| 2.4.4 | Long-press message: контекст-меню (reply, copy, forward, save, delete, more) | implemented | `chat_screen.dart` (message context menu) |
| 2.4.5 | Long-press media в gallery: share/edit/delete | n/a (галереи нет) | — |
| 2.4.6 | Swipe LTR on message: reply | not implemented | — |
| 2.4.7 | Swipe на чате (Dismissible): archive/read/mute/delete | not implemented | — |
| 2.4.8 | Long tap avatar в chat header: медиа контакта | not implemented | — |
| 2.4.9 | Swipe LTR top bar: refresh chat | not implemented | — |
| 2.4.10 | Swipe L/R между чатами | **not implemented** (PRD помечено) | — |
| 2.4.11 | Свайп while typing — временный scroll до дна | not implemented | — |
| 2.4.12 | «Пробурить дыру» до первого unread | not implemented (`_firstUnreadAt` — заглушка) | `backend.dart:334` |
| 2.4.13 | Swipe на шапке профиля (avatar+banner единым блоком) | implemented | `profile_screen.dart` (Hero-аватар) |
| 2.4.16/17 | Свайп до края экрана / «достать» AI-composer из любого экрана | **not implemented** (PRD помечено) | — |

## 2. Поведение кнопки «назад» (PRD 2.3)

Императивная навигация (`Navigator.push`), поэтому системный back работает естественно:
- из чата → список чатов ✅
- закрытие bottom sheets / панелей / fullscreen media / recorder — штатно по стеку ✅
- **не реализовано**: long-press back (список последних N экранов, 2.3.3), каскадная очередь закрытия (2.3.4), спец-обработка back в AI-панели (2.3.5) — в комposer AI-панели пока нет.

## 3. Сообщение как объект

- Оптимистичная отправка: мгновенно в ленту, статус `sending`.
- Статусы: `MsgStatus { sending, sent, delivered, read, failed }` (`backend.dart:74`).
- Индикатор `_statusTick` (`chat_screen.dart:2525`): часики → ✓ (sent) → ✓✓ серые (delivered) → синие ✓✓ (read) → красный ⚠ (failed, retry).
- Контекст-меню сообщения: reply, copy, forward, save, delete (+ share/media actions). Открытие — long-press / tap на кнопке «⋯».
- **Не реализовано**: реакции (2.7.3), редактирование в UI (RPC есть, UI? — см. STATE_MACHINE), закрепление в чате (2.7.7), фон чата (2.7.5), drafts.
- Внешние ссылки `vibe.me/@username` (2.2.1) — обработка запланирована; youtube-ссылки (2.2.2) — не реализовано.

## 4. Лента чата

- `CustomScrollView` с `reverse: true` (новые внизу), пагинация порциями `_pageSize = 80` (`chat_screen.dart`), `_loadOlderIfNeeded` при скролле вверх.
- Разделители по датам (вчера/сегодня).
- Подписки в `ChatScreen`: `stream` (сообщения), `typingEvents` (печатает…), `msgEvents` (edited/deleted/cleared/reactions) — `chat_screen.dart:274–391`.
- Комposer: текст + reply + вложения (фото/видео) + видео-круглый рекордер (`VideoRoundRecorderScreen`, `chat_screen.dart:2149`).
- **Unread-jump бадж** в шапке: показывает первое непрочитанное, но `_firstUnreadAt` бросает `UnimplementedError` — фича не готова.

## 5. Список чатов

- `chat_list_screen.dart` (1953 стр., монолит — кандидат на декомпозицию).
- Pinned chats сверху, закрепление через контекст-меню чата.
- Кнопка «новое сообщение» → `NewMessageScreen` (контакты + поиск) и «новая группа» → `CreateGroupScreen` (`chat_list_screen.dart:874`).
- Кнопка stories → `StoryComposerScreen` (`:1040`).
- Поиск → `SearchScreen` (глобальный: люди/сообщения) и `ChatSearchScreen` (внутри чата).
- **Не реализовано**: archive, mute per-chat, mark unread, drafts, фильтр непрочитанных.

## 6. Профиль (свой)

- `profile_screen.dart`: аватар (фото / emoji+градиент), имя, @username, телефон, био (до 3 строк), «всегда онлайн» (захардкожено зелёным, `:185`), vibe.me-ссылка, QR.
- Действия: копировать телефон/username/ссылку, Saved Messages (реальный чат через `ensureSavedChat`), Настройки, QR, редактор аватара, «Изменить данные» (`EditProfileScreen`), меню (цвет темы, переименовать, копировать ссылку).
- `EditProfileScreen`: name/username/bio (hint «до 70»); «Инфо о пользователе» (дата рождения/город/пол) и «Личный канал» — **заглушки**; «Автоматизация чатов» → `AurionScreen` (реальный).
- «Добавить аккаунт» — заглушка («Мультиаккаунты появятся позже»).

## 7. Профиль собеседника

- `peer_profile_screen.dart`: Hero-аватар, имя (`chat.title`), @username, онлайн-статус (online/recently), био, сетка общих медиа; действия: «Написать» (pop → чат).
- **Заглушки**: аудио/видео звонки (PRD 2.4.8 «медиа контакта» тоже вне).

## 8. Вводные паттерны (PRD 2.1)

Выделение слово-по-слову, перетаскивание границ выделения, кистевой ввод, cursor toggle, sticky text input — **всё not implemented** (отложено).

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
