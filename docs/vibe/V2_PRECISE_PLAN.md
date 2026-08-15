# VIBE PRECISE PLAN — Достижение 1:1 паритета с Telegram

> **Правило**: каждая задача — атомарная, с конкретным файлом, строкой и изменением.
> **Порядок**: визуал → механика → техническое → цвет (последним).
> **Статус**: `[ ]` — не сделано, `[x]` — сделано, `[~]` — в процессе.

---

## ФАЗА 1 — РАЗМЕРЫ И ОТСТУПЫ (визуал)

> Цель: точные размеры элементов как в Telegram.

### 1.1 Аватары

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 1.1.1 | Аватар в списке чатов | `chat_list_item.dart:133` | `size: 54` | `size: 48` | `chats/widgets/chat_list_item.dart` |
| 1.1.2 | Аватар в шапке чата | `chat_app_bar.dart:136` | `VibeSizes.avatarMd` (44) | `size: 38` | `chat/widgets/chat_app_bar.dart` |
| 1.1.3 | Аватар в настройках | `profile_screen.dart` | `size: 108` | `size: 90` | `screens/profile_screen.dart` |
| 1.1.4 | story-кольцо | `vibe_avatar.dart` | проверить толщину | `2dp` (неактив), `3dp` (актив) | `core/widgets/vibe_avatar.dart` |

### 1.2 Шрифты

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 1.2.1 | Имя чата в списке | `chat_list_item.dart:124` | `VibeTypography.subtitle` (15sp w500) | `16sp w600` | `chats/widgets/chat_list_item.dart` |
| 1.2.2 | Подзаголовок в шапке | `chat_app_bar.dart:150` | `11sp` | `13sp` | `chat/widgets/chat_app_bar.dart` |
| 1.2.3 | Заголовок экрана | `vibe_typography.dart` | `title: 20sp` | `18sp` (как Telegram header) | `core/theme/vibe_typography.dart` |

### 1.3 Padding и отступы

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 1.3.1 | Bubble text insets | `message_bubble.dart:244-248` | `h:12, v:8` | `h:12, top:6, bottom:5` (как Telegram) | `chat/widgets/message_bubble.dart` |
| 1.3.2 | Chat list contentPadding | `chat_list_item.dart:128` | `horizontal: 16` | `left: 68, right: 8` (как Telegram) | `chats/widgets/chat_list_item.dart` |
| 1.3.3 | Input bar padding | `chat_composer.dart:233` | проверить | `top:6, bottom:6` | `chat/widgets/chat_composer.dart` |

### 1.4 Border Radius

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 1.4.1 | Bubble radius default | `settings_service.dart` | `18.0` | `17.0` | `data/settings_service.dart` |
| 1.4.2 | Button radius | `vibe_spacing.dart` | `button: 14` | `button: 22` | `core/theme/vibe_spacing.dart` |
| 1.4.3 | Card radius | `vibe_spacing.dart` | `card: 16` | `card: 12` | `core/theme/vibe_spacing.dart` |
| 1.4.4 | Input radius | `vibe_spacing.dart` | `input: 20` | `input: 18` | `core/theme/vibe_spacing.dart` |

### 1.5 Кнопки и иконки

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 1.5.1 | FAB size | `vibe_icon_button.dart` / `compose_fab.dart` | `52×52` | `56×56` | `core/widgets/vibe_icon_button.dart` |
| 1.5.2 | Back arrow size | `chat_app_bar.dart:114` | `iconSize: 18` | `iconSize: 22` | `chat/widgets/chat_app_bar.dart` |
| 1.5.3 | Send button size | `chat_composer.dart:380` | `size: 20` | `size: 24` | `chat/widgets/chat_composer.dart` |

---

## ФАЗА 2 — АНИМАЦИИ (визуал + механика)

> Цель: плавность как в Telegram — spring-физика, stroke-draw, staggered.

### 2.1 Переходы экранов

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 2.1.1 | Page transition duration | `vibe_animations.dart` | `fadeIn: 200ms` | `fadeIn: 300ms` | `core/theme/vibe_animations.dart` |
| 2.1.2 | Slide offset | `chat_list_screen.dart:993` | `begin: Offset(0.05, 0)` | `begin: Offset(0.3, 0)` | `screens/chat_list_screen.dart` |
| 2.1.3 | Interactive swipe-back | `chat_screen.dart` | нет | `WillPopScope` + interactive gesture | `screens/chat_screen.dart` |

### 2.2 Bottom Sheet

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 2.2.1 | Sheet physics | `chat_menu_sheet.dart` и др. | `showModalBottomSheet` | Custom `DraggableScrollableSheet` с spring | `chat/widgets/chat_menu_sheet.dart` |
| 2.2.2 | Backdrop dim | все bottom sheets | стандартный | `Colors.black54` + fade | все файлы с bottom sheets |

### 2.3 Сообщения

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 2.3.1 | Message appear | `message_bubble.dart` | нет анимации | `ScaleTransition` + `FadeTransition` (0→1, 0.95→1) | `chat/widgets/message_bubble.dart` |
| 2.3.2 | Message delete | `message_bubble.dart` | `shake 500ms` | `FadeTransition` + `SizeTransition` (collapse) 800ms | `chat/widgets/message_bubble.dart` |

### 2.4 Checkmark статусы

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 2.4.1 | Checkmark draw-in | `message_status_tick.dart` | статичная иконка | `CustomPainter` с `strokeAnimation` | `chat/widgets/message_status_tick.dart` |
| 2.4.2 | Read color transition | `message_status_tick.dart` | instant grey→blue | `ColorTransition` 200ms | `chat/widgets/message_status_tick.dart` |

### 2.5 Typing indicator

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 2.5.1 | Typing dots | `chat_app_bar.dart:83` | текст "печатает…" | 3 точки с staggered bounce | `chat/widgets/chat_app_bar.dart` |

### 2.6 Online статус

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 2.6.1 | Online dot appear | `vibe_avatar.dart` | show/hide | `ScaleTransition` spring 0.3s | `core/widgets/vibe_avatar.dart` |

### 2.7 FAB

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 2.7.1 | FAB show/hide | `root_shell.dart` | `AnimatedScale` + `AnimatedOpacity` | `SlideTransition` + `ScaleTransition` | `screens/root_shell.dart` |

### 2.8 Context menu

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 2.8.1 | Long-press menu | `message_bubble.dart` | `showModalBottomSheet` | Scale-up from press point + staggered items | `chat/widgets/message_bubble.dart` |

### 2.9 Sticker panel

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 2.9.1 | Panel slide | `emoji_sticker_panel.dart` | `FadeTransition` + `SlideTransition` | Spring slide-up (0.3s) | `screens/emoji_sticker_panel.dart` |

---

## ФАЗА 3 — МЕХАНИКА ЖЕСТОВ (механика)

> Цель: жесты как в Telegram — пороги, velocity, haptic.

### 3.1 Swipe reply

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 3.1.1 | Reply threshold | `message_bubble.dart:138` | `30% screen width` (~108dp) | `80dp` (как Telegram) | `chat/widgets/message_bubble.dart` |
| 3.1.2 | Reply icon position | `message_bubble.dart:196` | `left: -40` | `left: -48` (больше отступ) | `chat/widgets/message_bubble.dart` |
| 3.1.3 | Swipe velocity | `message_bubble.dart:138` | `dx * 0.5` | `dx * 0.6` (быстрее) | `chat/widgets/message_bubble.dart` |

### 3.2 Chat list swipe

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 3.2.1 | Swipe left | `chat_list_item.dart:82` | `DismissDirection.horizontal` | `DismissDirection.startToEnd` (только влево) | `chats/widgets/chat_list_item.dart` |
| 3.2.2 | Swipe right | `chat_list_item.dart:82` | `DismissDirection.horizontal` | `DismissDirection.endToStart` (только вправо) отдельный | `chats/widgets/chat_list_item.dart` |
| 3.2.3 | Swipe velocity threshold | Material default | `~300dp/s` | `400dp/s` (как Telegram) | custom Dismissible |

### 3.3 Swipe between chats

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 3.3.1 | Swipe velocity | `chat_screen.dart:1685` | `300` | `400` | `screens/chat_screen.dart` |
| 3.3.2 | Edge detection | `chat_screen.dart:1685` | нет | `16dp` edge detection (как Telegram) | `screens/chat_screen.dart` |

### 3.4 Haptic feedback

| # | Что | Где | Было | Стало | Файл |
|---|-----|-----|------|-------|------|
| 3.4.1 | Reply trigger | `message_bubble.dart:143` | `mediumImpact` | `heavyImpact` (как Telegram) | `chat/widgets/message_bubble.dart` |
| 3.4.2 | Archive swipe | `chat_list_item.dart` | нет | `mediumImpact` | `chats/widgets/chat_list_item.dart` |
| 3.4.3 | Pin swipe | `chat_list_item.dart` | нет | `mediumImpact` | `chats/widgets/chat_list_item.dart` |

---

## ФАЗА 4 — ФУНКЦИОНАЛ (техническое)

> Цель: добавить отсутствующие фичи Telegram.

### 4.1 Multi-select сообщений

| # | Что | Файлы | Описание |
|---|-----|-------|----------|
| 4.1.1 | Selection state | `chat_controller.dart` | Добавить `Set<String> selectedMsgIds` + `toggleSelect(msgId)` |
| 4.1.2 | Selection toolbar | `chat_screen.dart` | Top bar: Forward / Delete / Copy / Close |
| 4.1.3 | Tap to select | `message_bubble.dart` | Long-press → enter selection, tap → toggle |
| 4.1.4 | Bulk actions | `chat_controller.dart` | `forwardSelected()`, `deleteSelected()`, `copySelected()` |

### 4.2 Reply privately (в группе)

| # | Что | Файлы | Описание |
|---|-----|-------|----------|
| 4.2.1 | Menu item | `message_bubble.dart` / context menu | Добавить "Ответить приватно" для group чатов |
| 4.2.2 | Action | `chat_controller.dart` | Открыть PM чат с автором + reply context |

### 4.3 Copy link to message

| # | Что | Файлы | Описание |
|---|-----|-------|----------|
| 4.3.1 | Menu item | context menu | Добавить "Копировать ссылку" |
| 4.3.2 | Link generation | `backend.dart` | `vibe.me/chat/{chatId}?msg={msgId}` |

### 4.4 Voice playback speed

| # | Что | Файлы | Описание |
|---|-----|-------|----------|
| 4.4.1 | Speed button | `message_bubble.dart` (voice bubble) | Кнопка 0.5x / 1x / 1.5x / 2x |
| 4.4.2 | Speed logic | `message_bubble.dart` | `AudioPlayer.setSpeed()` |

### 4.5 Translate message

| # | Что | Файлы | Описание |
|---|-----|-------|----------|
| 4.5.1 | Menu item | context menu | "Перевести" |
| 4.5.2 | Translation API | `backend.dart` или edge function | Google Translate / DeepL integration |
| 4.5.3 | Display | `message_bubble.dart` | Показать перевод под сообщением |

### 4.6 Forward without quotes

| # | Что | Файлы | Описание |
|---|-----|-------|----------|
| 4.6.1 | Option | `forward_message_screen.dart` | Checkbox "Без цитаты" |
| 4.6.2 | Backend | `backend.dart` | `forwardMessage(stripForward: true)` |

### 4.7 Recent Calls

| # | Что | Файлы | Описание |
|---|-----|-------|----------|
| 4.7.1 | Screen | `screens/recent_calls_screen.dart` | Табы: Все / Пропущенные / Исходящие / Входящие |
| 4.7.2 | Navigation | `profile_screen.dart` or `contacts_screen.dart` | Кнопка "Звонки" |
| 4.7.3 | Data | `backend.dart` | `listCalls()` с Supabase |

### 4.8 Power Saving

| # | Что | Файлы | Описание |
|---|-----|-------|----------|
| 4.8.1 | Screen | `settings/power_saving_screen.dart` | Порог батареи + переключатели |
| 4.8.2 | Logic | `settings_service.dart` | `powerSavingMode`, `disableAnimations` |

### 4.9 Proxy settings

| # | Что | Файлы | Описание |
|---|-----|-------|----------|
| 4.9.1 | Screen | `settings/proxy_settings_screen.dart` | SOCKS5 / MTProto proxy |
| 4.9.2 | Logic | `backend.dart` | Proxy configuration |

### 4.10 Wallpaper per-chat

| # | Что | Файлы | Описание |
|---|-----|-------|----------|
| 4.10.1 | Data model | `backend.dart` | `chatWallpaper` field in VibeChat |
| 4.10.2 | UI | `chat_screen.dart` | Background image from chat settings |
| 4.10.3 | Picker | `settings/wallpaper_picker.dart` | Gallery + built-in patterns |

---

## ФАЗА 5 — НАСТРОЙКИ (структура)

> Цель: количество разделов и опций как в Telegram.

### 5.1 Уведомления (расширить)

| # | Что | Файл | Описание |
|---|-----|------|----------|
| 5.1.1 | Channels toggle | `notification_settings.dart` | Добавить переключатель каналов |
| 5.1.2 | Calls section | `notification_settings.dart` | Рингтоны, вибрация |
| 5.1.3 | Stories section | `notification_settings.dart` | Уведомления о stories |
| 5.1.4 | Badge counter | `notification_settings.dart` | Показывать/скрывать счётчик |
| 5.1.5 | Scheduled notifications | `notification_settings.dart` | Тихие часы |

### 5.2 Конфиденциальность (расширить)

| # | Что | Файл | Описание |
|---|-----|------|----------|
| 5.2.1 | Voice Messages privacy | `privacy_settings.dart` | Кто может отправлять |
| 5.2.2 | Bio privacy | `privacy_settings.dart` | Кто видит biography |
| 5.2.3 | Birthday privacy | `privacy_settings.dart` | Кто видит дату рождения |
| 5.2.4 | Exception lists | `privacy_selector_screen.dart` | "Кроме..." — список исключений |

### 5.3 Внешний вид (расширить)

| # | Что | Файл | Описание |
|---|-----|------|----------|
| 5.3.1 | Wallpaper | `appearance_settings.dart` | Выбор обоев |
| 5.3.2 | Bubble corners slider | `appearance_settings.dart` | Уже есть (проверить range 4-24) |
| 5.3.3 | Auto-night mode | `appearance_settings.dart` | По расписанию / закат / ручной |
| 5.3.4 | Send by Enter | `appearance_settings.dart` | Переключатель |
| 5.3.5 | In-App Browser | `appearance_settings.dart` | Открывать в Telegram / внешний |

### 5.4 Данные (расширить)

| # | Что | Файл | Описание |
|---|-----|------|----------|
| 5.4.1 | Auto-play media | `data_settings.dart` | GIF, видео, стикеры |
| 5.4.2 | Save to Gallery | `data_settings.dart` | Личные / Группы / Каналы |
| 5.4.3 | Storage usage detail | `data_settings.dart` | Размер кэша по чатам |
| 5.4.4 | Usage statistics | `data_settings.dart` | Трафик по чатам |
| 5.4.5 | Streaming threshold | `data_settings.dart` | Порог автозагрузки |

---

## ФАЗА 6 — КОНТЕКСТ-МЕНЮ СООБЩЕНИЙ (расширение)

> Цель: количество опций как в Telegram.

| # | Что | Файл | Описание |
|---|-----|------|----------|
| 6.1 | Select mode | `message_bubble.dart` | Добавить "Выбрать" в контекст-меню |
| 6.2 | Report message | `message_bubble.dart` | "Пожаловаться" для входящих |
| 6.3 | Show in chat | `message_bubble.dart` | "Показать в чате" (для пересланных) |
| 6.4 | Save to downloads | `message_bubble.dart` | "Скачать" для медиа |
| 6.5 | Copy selected text | `message_bubble.dart` | Частичное выделение текста |

---

## ФАЗА 7 — АНИМАЦИИ CHECKMARK И СТАТУСОВ (визуал)

> Цель: stroke-draw анимацию как в Telegram.

| # | Что | Файл | Описание |
|---|-----|------|----------|
| 7.1 | CustomPainter checkmark | `message_status_tick.dart` | Path-based checkmark с stroke animation |
| 7.2 | Draw duration | `message_status_tick.dart` | 300ms single, +150ms delay double |
| 7.3 | Color transition | `message_status_tick.dart` | Grey→Blue за 200ms с scale pulse |
| 7.4 | Clock spinning | `message_status_tick.dart` | Rotating animation для "отправляется" |

---

## ФАЗА 8 — SPRING-ФИЗИКА (механика)

> Цель: spring-анимации для natural feel.

| # | Что | Файл | Описание |
|---|-----|------|----------|
| 8.1 | Spring curve constant | `vibe_animations.dart` | `Curves.elasticOut` (0.22, 1.15, 0.36, 1.0) — уже есть как `springy` |
| 8.2 | Bottom sheet spring | все bottom sheets | Использовать `springy` curve |
| 8.3 | Page transition spring | `vibe_animations.dart` | Использовать `springy` для slide |
| 8.4 | Badge spring | `vibe_island.dart` | Уже есть `elasticOut` — проверить |
| 8.5 | FAB spring | `root_shell.dart` | Scale + slide с spring |

---

## ФАЗА 9 — INTERACTIVE SWIPE-BACK (механика)

> Цель: интерактивный жест "назад" как на iOS.

| # | Что | Файл | Описание |
|---|-----|------|----------|
| 9.1 | Gesture detector | `chat_screen.dart` | `GestureDetector` на edge с `onHorizontalDragUpdate` |
| 9.2 | Rubber-band effect | `chat_screen.dart` | От offset зависит opacity предыдущего экрана |
| 9.3 | Threshold | `chat_screen.dart` | `16dp` min, `200dp` max, `0.35` factor |
| 9.4 | Velocity-based dismiss | `chat_screen.dart` | `primaryVelocity > 500` → pop, иначе snap-back |

---

## ФАЗА 10 — ЦВЕТ (последний)

> Цель: переход на фирменный фиолетовый Vibe.

| # | Что | Файл | Описание |
|---|-----|------|----------|
| 10.1 | Primary color | `vibe_colors.dart` | `#3390EC` → фиолетовый |
| 10.2 | Accent surfaces | `vibe_colors.dart` | Обновить `primaryLight`, `primaryDark` |
| 10.3 | Gradient | `vibe_colors.dart` | `brandGradient`, `avatarGradient` |
| 10.4 | Bubble out (dark) | `vibe_colors.dart` | `#2B5278` → фиолетовый оттенок |
| 10.5 | Bubble out (light) | `vibe_colors.dart` | `#EFFDDE` → фиолетовый оттенок |
| 10.6 | Unread badge | `vibe_colors.dart` | `unreadBlue` → фиолетовый |
| 10.7 | Story ring | `vibe_avatar.dart` | Градиент → фиолетовый |
| 10.8 | Glow effects | `vibe_colors.dart` | `glowPrimary`, `glowVivid` |
| 10.9 | Button fills | все файлы с `context.vibePrimary` | Автоматически через theme |

---

## ПОРЯДОК ВЫПОЛНЕНИЯ

```
Фаза 1 (размеры) → Фаза 2 (анимации) → Фаза 3 (жесты) →
Фаза 4 (функционал) → Фаза 5 (настройки) → Фаза 6 (меню) →
Фаза 7 (checkmark) → Фаза 8 (spring) → Фаза 9 (swipe-back) →
Фаза 10 (цвет)
```

**Каждая фаза**: `flutter analyze` → сборка → установка на устройство → тестирование.

---

## ОЖИДАЕМЫЙ РЕЗУЛЬТАТ

После всех фаз:
- Визуал: размеры, отступы, radius — 1:1 с Telegram
- Анимации: spring-физика, stroke-draw, staggered — как в Telegram
- Механика: swipe пороги, haptic, velocity — как в Telegram
- Функционал: multi-select, reply private, translate, calls — как в Telegram
- Цвет: фирменный фиолетовый Vibe (вместо синего Telegram)
