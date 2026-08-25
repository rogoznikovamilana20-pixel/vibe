# TELEGRAM → VIBE MAPPING

Статусы: `NOT IMPLEMENTED` / `PARTIAL` / `FUNCTIONAL` / `VISUAL MISMATCH` / `BEHAVIOR MISMATCH` / `ANIMATION MISMATCH` / `MATCHED`
Источник эталона: https://github.com/DrKLO/Telegram (Android). Правило: анализ, не копирование кода.

Обновлено: 2026-08-21 (PHASE 1 аудит; G1-G9 закрыты; PHASE 2 design audit; секции 1-6 свериены по коду).

---

## 1. ROOT / НАВИГАЦИЯ

| Telegram | VIBE | Файл | Visual | Behavior | Animation | Статус |
|---|---|---|---|---|---|---|
| Splash → Passcode → Main | Splash → passcode/onboarding → Main | splash_screen.dart, lock_screen.dart | ✓ | ✓ | ✓ | MATCHED |
| Onboarding (startup) | onboarding_screen.dart: PageView 3 слайда, точки (pulse), «Пропустить», конфетти, fade → Auth | ✓ | ✓ | ✓ | MATCHED (21.08: аудит — полный) |
| Main tabs (Chats/Calls/Settings) | Tabs: Чаты/Контакты/Настройки/Профиль (glass) | root_shell.dart | ✓ | ✓ | FadeTransition | MATCHED (VIBE раскладка своя, +Профиль вместо Calls) |
| Fragment push/pop | MaterialPageRoute (Cupertino-транзишены глобально) | vibe_theme.dart:94 | ✓ | ✓ | — | MATCHED |
| iOS edge-swipe back | SwipeBackWrapper (maxDrag 280, threshold 50) | swipe_back_wrapper.dart | — | ✓ | ✓ | MATCHED |
| Bottom sheets | TelegramBottomSheet (scale+fade, handle) | telegram_bottom_sheet.dart | ✓ | ✓ | ✓ | MATCHED |

## 2. CHAT LIST

| Telegram | VIBE | Файл | Visual | Behavior | Animation | Статус |
|---|---|---|---|---|---|---|
| Chat row: avatar, title, last msg, time | chat_list_item.dart | ✓ | ✓ | — | MATCHED |
| Unread badge | ✓ | chat_list_item.dart | ✓ | ✓ | — | MATCHED |
| Mute indicator | ✓ | chat_list_item.dart | ✓ | ✓ | — | MATCHED |
| Pinned chats | `_chat.pinned` (Set) + персистенс SettingsService; иконка pin + свайп-анпин | chat_list_controller.dart:44-119, chat_list_item.dart:70-72, 148-150 | ✓ | ✓ | — | MATCHED (21.08: аудит — полный) |
| Draft indicator | «Черновик» в сабтайтле (акцент) из draftFor | chat_list_item.dart:162-186, chat_list_screen.dart:1830 | ✓ | ✓ | — | MATCHED (21.08: аудит — полный) |
| Typing status | «печатает…» в строке списка (6с, per-chat таймеры); в шапке чата — _TypingDots | chat_list_controller.dart (_typing/_onTyping), chat_list_item.dart, backend typingEvents | ✓ | ✓ | — | MATCHED (21.08: реализовано в списке; было PARTIAL) |
| Swipe actions | Полный свайп как в TG (FullSwipe, порог 0.45, отмена 200мс): влево — одно действие из настроек (по умолчанию архив, варианты read/mute/pin/delete), вправо — вернуть из архива; после архива — тост Undo (как UndoView); DND — в long-press меню; настройка — Settings → Свайп по чату (как SwipeGestureSettingsView) | full_swipe.dart, chat_list_item.dart, chat_list_screen.dart (_toggleArchive/_confirmDeleteChat), chat_settings.dart, settings_service.dart (ChatSwipeAction) | ✓ | ✓ | ✓ | MATCHED (21.08: Dismissible → AnchoredSwipe → FullSwipe, TG-паттерн одного действия, верификация по tg-src) |
| Multi-select toolbar | SelectionToolbar | chat_list_header.dart | ✓ | ✓ | — | MATCHED |
| Search in list | Inline search bar в шапке списка (G7) | chat_list_screen.dart + search_screen.dart | ✓ | ✓ | — | MATCHED (21.08: инлайн-бар + экран поиска) |
| Stories row | story_circle.dart | ✓ | ✓ | — | MATCHED |
| Folders | Табы all/personal/groups/channels/business + кастом; экран FoldersScreen из меню и Настроек | chat_list_screen.dart:78, 316-323; folders_screen.dart | ✓ | ✓ | — | MATCHED (21.08: аудит — полный) |
| Compose FAB | compose_fab.dart | ✓ | ✓ | — | MATCHED |
| **Saved Messages** | `_buildSavedTile` → `_openSaved` → `ensureSavedChat` | chat_list_screen.dart:1667 | ✓ | ✓ | — | **IMPLEMENTED** (G1) |
| **Archived chats UI** | `_buildArchiveTile` + `_showArchive`-режим | chat_list_screen.dart:1723, 469 | ✓ | ✓ | — | **IMPLEMENTED** (G2) |
| **Online presence in list** | `peerOnline` → `VibeAvatar(online:)`, пулинг 2с | chat_list_item.dart:129 | ✓ | ✓ | — | **IMPLEMENTED** (G6) |

## 3. CHAT SCREEN

| Telegram | VIBE | Файл | Visual | Behavior | Animation | Статус |
|---|---|---|---|---|---|---|
| App bar: back, title, online, actions | chat_app_bar.dart | ✓ | ✓ | typing dots | MATCHED |
| Inverted message list | CustomScrollView reverse | chat_screen.dart | ✓ | ✓ | — | MATCHED |
| Date separators | message_date_divider.dart | ✓ | ✓ | — | MATCHED |
| Unread separator | UnreadPlank | chat_planks.dart | ✓ | ✓ | — | MATCHED |
| Bubbles in/out, flat, radius 16 | message_bubble.dart | ✓ | ✓ | — | MATCHED (недавно: без теней/бордеров) |
| Bubble tails (TG: только 2-й в группе, маленький) | `isLastInGroup` → _TailPainter 11×7, зеркалится | message_bubble.dart:305-319 | ✓ | ✓ | — | MATCHED (G8) |
| Timestamp in bubble | ✓ | message_bubble.dart | ✓ | — | — | MATCHED |
| Delivery ticks (✓✓ read) | message_status_tick.dart | ✓ | ✓ | 300/200ms | MATCHED |
| Selection mode + checkmarks | _SelectionCheck | message_bubble.dart | ✓ | ✓ | — | MATCHED |
| Long-press context menu | TelegramContextMenu (reply/copy/pin/forward/select/delete) | telegram_context_menu.dart | ✓ | ✓ | — | MATCHED |
| Reply preview | ReplyPreview | message_bubble.dart | ✓ | ✓ | — | MATCHED |
| Edit message | ✓ | chat_screen.dart | ✓ | ✓ | — | MATCHED |
| Delete (для всех/себя) | ✓ | chat_screen.dart | ✓ | ✓ | — | MATCHED |
| Forward | forward_message_screen.dart | ✓ | ✓ | — | MATCHED |
| Reactions (8 эмодзи в меню; double-tap = последняя) | `_emojiOptions` + `addReaction`; double-tap → `heartReact` (TG: повторяет последнюю, дефолт ❤️) + burst-эффект (большой эмодзи летит в случайную точку, как ReactionsEffectOverlay) | chat_screen.dart:1505-1527, message_bubble.dart (_onDoubleTap/_ReactionBurst), chat_controller.dart:806-853 | ✓ | ✓ | — | MATCHED (21.08: 8 реакций, бэкенд message_reactions + realtime; double-tap — последняя использованная + burst) |
| Polls (create/vote/counter) | ✓ | message_bubble.dart | ✓ | ✓ | — | MATCHED |
| Links tappable | buildLinkSpans (URL + @mentions + #hashtags, как в TG: `TL_messageEntityUrl/Mention/Hashtag`) + `onOpenUrl` с деградацией (URL → `launchUrl`, @ → тост профиль, # → тост поиск) | models.dart (`_linkPattern`), message_bubble.dart, chat_screen.dart (`_openUrl`) | ✓ | ✓ | — | MATCHED (деградация без бэкенда резолва — честно, кликабельно) |
| Long-press media gallery | `_MediaTile` long-press → bottom sheet (Поделиться/Сохранить/Переслать/Удалить) + viewer long-press, как в TG | chat_media_gallery_screen.dart (`ChatMediaItem` + `_showMediaActions`) | ✓ | ✓ | — | MATCHED |
| Composer: attach/emoji внутри поля, camera, send/mic | chat_composer.dart | ✓ | ✓ | — | MATCHED (недавний редизайн) |
| Voice recording + lock | ✓ | chat_composer.dart | ✓ | ✓ | — | MATCHED |
| Video round recorder | video_round_recorder.dart | ✓ | ✓ | — | MATCHED |
| Stickers/GIF/emoji panel | emoji_sticker_panel.dart, gif_search_panel.dart | ✓ | ✓ | — | MATCHED |
| @mentions autocomplete | mentions_autocomplete.dart | ✓ | ✓ | — | MATCHED |
| Scheduled messages | плашка + список | chat_screen.dart | ✓ | ✓ | — | MATCHED |
| Jump-to-bottom pill | jump_down_button.dart | ✓ | ✓ | — | MATCHED |
| Keyboard-safe composer | ✓ | chat_screen.dart | ✓ | ✓ | — | MATCHED |
| **Swipe-to-reply** | `_onHorizontalDragUpdate/End` | message_bubble.dart:146-167 | ✓ | ✓ | — | **IMPLEMENTED** (G3) |
| **Double-tap to react** | `_onDoubleTap` → `onHeart` + burst (эмодзи 44px, полёт/вращение/затухание 900мс) | message_bubble.dart:145-157 | ✓ | ✓ | — | **MATCHED** (21.08: burst по TG-паттерну, C3) |
| **Reply jump on tap** | `jumpToReplyIndex` + `_jumpToReplyFrom` | chat_controller.dart:997, chat_screen.dart:725 | ✓ | ✓ | — | **IMPLEMENTED** (G4) |

## 4. SEARCH

| Telegram | VIBE | Файл | Visual | Behavior | Animation | Статус |
|---|---|---|---|---|---|---|
| Global search (chats+people+msgs) | Чаты (локальный фильтр) + Люди (searchUsers); сообщения — через in-chat search | search_screen.dart | ✓ | ✓ | — | FUNCTIONAL (сообщения вне глобального поиска — как TG, но не по всем чатам) |
| In-chat search with jump | autofocus, prev/next, _jump → animateTo (76px/строка) | chat_search_screen.dart:64-69, 162 | ✓ | ✓ | ✓ | MATCHED (21.08: аудит — полный) |
| Search field animation/автофокус | autofocus + Fade/ScaleTransition (VibeAnimations.fadeIn, easeOut) | search_screen.dart:158 | ✓ | ✓ | ✓ | MATCHED (21.08: автофокус + появление поля scale 0.96→1 + fade; переход экрана уже был fade+slide+springy) |

## 4a. SEARCH — улучшения 21.08 (итерация 2)

| Gap | Статус |
|---|---|
| Секция «Чаты» в поиске (фильтр локального списка) | ✅ IMPLEMENTED (search_screen.dart: `_chatResults` + `_ChatTile` + заголовки `search_chats`/`search_people`) |
| Секция «Люди» отделена от «Чатов» | ✅ IMPLEMENTED (общий `_openChatScreen`-переход для обеих) |
| Хардкод «был(а) в сети {time}» в ActionBar чата | ✅ IMPLEMENTED — локализован (`status_last_seen_at`, chat_app_bar.dart) |

## 5. SETTINGS

| Telegram | VIBE | Файл | Visual | Behavior | Animation | Статус |
|---|---|---|---|---|---|---|
| Settings hub (sections, tiles) | SettingsSection/SettingsTile | settings_screen.dart | ✓ | ✓ | — | MATCHED |
| Appearance (theme, accent, font size, bubble radius) | appearance_settings.dart | ✓ | ✓ | — | MATCHED |
| Notifications | notifications_settings.dart | ✓ | ✓ | — | MATCHED |
| Privacy (32 перехода) | privacy_settings.dart | ✓ | ✓ | — | MATCHED |
| Passcode | passcode_screen.dart | ✓ | ✓ | — | MATCHED |
| Devices/active sessions | devices_screen.dart | ✓ | ✓ | — | MATCHED |
| 2-step verification | two_step_verification_screen.dart | ✓ | ✓ | — | MATCHED |
| Language | language_settings.dart | ✓ | ✓ | — | MATCHED |
| Data/storage | data_settings.dart | ✓ | ✓ | — | MATCHED |
| Proxy | proxy_settings.dart | ✓ | ✓ | — | MATCHED |
| **Folders setup из Settings** | Пункт «Папки» в Настройках → FoldersScreen (chats из listChats/offline) | settings_screen.dart (tile + `_openFolders`) | ✓ | ✓ | — | MATCHED (21.08: пункт добавлен в Основные настройки) |

## 6. MEDIA / CALLS / STORIES

| Telegram | VIBE | Файл | Visual | Behavior | Animation | Статус |
|---|---|---|---|---|---|---|
| Media gallery per chat | chat_media_gallery_screen.dart | ✓ | ✓ | — | MATCHED |
| Photo viewer (fullscreen, zoom) | MediaViewerScreen: PageView + InteractiveViewer (maxScale 5) + видео | chat_media_gallery_screen.dart:199 | ✓ | ✓ | — | MATCHED (21.08: G9 — тап по фото в чате → MediaViewerScreen; ZoomableAvatar остался только для аватара) |
| WebRTC calls | call_screen.dart, incoming_call_screen.dart + WebRtcService (peer connection, ICE, onTrack) | ✓ | ✓ | — | MATCHED |
| Stories (своя фича) | story_player.dart | ✓ | ✓ | — | MATCHED |

## 7. DESIGN SYSTEM (PHASE 2)

Аудит по факту исходников drklo/telegram (локальный клон, `SharedConfig.java`,
`ThemeColors.java`, `ActionBar.java`) — 21.08.2026.

| Токен | Telegram (ground truth из исходников) | VIBE | Статус |
|---|---|---|---|
| Typography | Roboto, 3 начертания (400/500/700) | VibeTypography: Roboto 400/500/700, 30/26/18/15/16/15/12/11 | **MATCHED** (2026-08-20) |
| Bubble radius | **17dp** (`SharedConfig.java:315` `bubbleRadius = 17`) | Дефолт **17.0** в `SettingsService.bubbleRadius` (настраиваемый 4-24); мёртвый токен `VibeRadius.bubble=16` удалён 21.08 | **EXACT** |
| ActionBar height | **56dp portrait / 48dp landscape** (`ActionBar.java:1855-1861`) | VibeSizes.toolbarHeight=56 (21.08: 52→56) | **EXACT** (портрет) |
| Chat list row height | **70dp 2-line / 76dp 3-line** (`DialogsAdapter.getItemHeight`: `useThreeLinesLayout ? 76 : 70` + 1 divider) | ListTile `minTileHeight: 72` (chat_list_item.dart:119); мёртвый токен `rowHeight=60` удалён 21.08 | ~MATCHED (72 vs 70 — 2dp) |
| Spacing | 4-8-12-16 | VibeSpacing xs4 sm8 md12 lg16 … | MATCHED |
| Light bg | **#FFFFFF** (`ThemeColors.java:79 windowBackgroundWhite`) | #FFFFFF | **EXACT** |
| Light toolbar | **#FFFFFF** (`ThemeColors.java:189 actionBarDefault`) | #FFFFFF | **EXACT** |
| Light in-bubble | **#FFFFFF** (`ThemeColors.java:304 chat_inBubble`) | bubbleInLight #FFFFFF | **EXACT** |
| Light out-bubble | **#EFFFDE** (`ThemeColors.java:307 chat_outBubble`) | bubbleOutLight #F0EAFF | BRAND (фиолетовый оттенок вместо зелёного) |
| Dark bg | сток TG **#17212B** (форк drklo использует #222B33 — кастом) | #17212B | **EXACT** (сток) |
| Dark in-bubble | сток TG **#182533** | bubbleInDark #182533 | **EXACT** |
| Dark out-bubble | сток TG #2B5278 (синий) | bubbleOutDark #2D2B5E | BRAND (фиолетовый вместо синего) |
| Online green | сток TG **#4DCD5E** (форк: #4BCB1C, `ThemeColors.java:226 chats_onlineCircle`) | online #4DCD5E | **EXACT** (сток) |
| Accent | сток TG #3390EC | #8B4DFF | BRAND (бренд-правило) |
| Icons | Stroke-based | VibeIcons — кастомный иконо-шрифт (42 иконки) | ✓ | ✓ | — | FUNCTIONAL (бренд-правило: свой шрифт вместо Material/TG) |
| Нотация весов | Только 400/500/700 в UI | w600 убран (57→0), w700 для display | MATCHED |
| Animation tokens | ~150-300ms, easeOut | VibeAnimation micro120/fast150/fade300/fluid350 | MATCHED |

**Вывод**: каркас (spacing, типографика, тёмная база, онлайн-цвет, высоты) совпадает
со стоком Telegram. Намеренные бренд-отклонения только в акценте и цветах пузырей
(фиолетовая палитра VIBE). 21.08: bubble radius дефолт 17 (EXACT, был мёртвый токен 16),
toolbarHeight 52→56 (EXACT portrait). PHASE 2 закрыт.

---

## ПРИОРИТЕТНЫЕ GAPS (для PHASE 3-7)

Статусы обновлены по факту кода 21.08.2026: G1/G2/G3/G5/G6/G8 уже были
реализованы; G4 и G7 реализованы в этой итерации; G9 завершён (тап по фото
в чате открывает MediaViewerScreen с зумом).

| # | Gap | Приоритет | Эффорт | Статус |
|---|---|---|---|---|
| G1 | Saved Messages (Избранное) — раздел в чат-листе | HIGH | Средний | ✅ IMPLEMENTED (`_buildSavedTile` → `_openSaved` → `ensureSavedChat`, chat_list_screen.dart:1667) |
| G2 | Секция/экран Archived chats | HIGH | Средний | ✅ IMPLEMENTED (`_buildArchiveTile` + `_showArchive`-режим списка, chat_list_screen.dart:1723, 469) |
| G3 | Swipe-to-reply в чате | HIGH | Средний | ✅ IMPLEMENTED (`_onHorizontalDragUpdate/End`, message_bubble.dart:146-167) |
| G4 | Reply-jump (тап по reply → прокрутка к сообщению) | HIGH | Малый | ✅ IMPLEMENTED (21.08: `jumpToReplyIndex` chat_controller.dart:997 + `onReplyTap` message_bubble + `_jumpToReplyFrom` chat_screen.dart:725; локальный матч по тексту — reply денатурализован) |
| G5 | Double-tap → реакция (heart) | MEDIUM | Малый | ✅ MATCHED (`_onDoubleTap` → `onHeart` + burst-эффект как в TG, message_bubble.dart) |
| G6 | Online-статус в чат-листе | MEDIUM | Средний | ✅ IMPLEMENTED (`peerOnline` → `VibeAvatar(online:)`, chat_list_item.dart:129; presence-пулинг 2с, chat_list_controller.dart:231) |
| G7 | Inline search в чат-листе (как TG) | MEDIUM | Средний | ✅ IMPLEMENTED (21.08: `_buildSearchBar` в шапке списка, chat_list_screen.dart:933; скрыта в архиве/скрытых; тап → SearchScreen) |
| G8 | Проверка хвоста пузыря (TG: маленький, только 2-й в группе) | MEDIUM | Малый | ✅ IMPLEMENTED (`_TailPainter` 11x7, последнее в группе, зеркало для исходящих, message_bubble.dart:279-296) |
| G9 | Полноценный PhotoViewer (пинч-зум по фото) | MEDIUM | Большой | ✅ IMPLEMENTED (21.08: тап по фото в чате → `_openPhotoViewer` chat_screen.dart → `MediaViewerScreen` (InteractiveViewer maxScale 5, свайп между медиа); gallery: общий хелпер `chatMediaItems`) |

## ВЕРИФИКАЦИЯ (после каждой фазы)
```bash
cd app
flutter analyze    # 0 errors (0 warnings)
flutter test       # 1800/1800
```