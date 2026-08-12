# NAVIGATION MAP — Vibe

> Карта экранов и переходов. Все переходы — императивные `Navigator.push(MaterialPageRoute(...))`; named routes / deep links не используются. Аудит 11.08.2026.

## 1. Экранный инвентарь (35 экранов)

### Запуск / сессия
- `splash_screen.dart` → init → (no session) `onboarding_screen.dart` → `auth/auth_screen.dart` (login/register) → `profile_setup_screen.dart` → app
- (есть сессия) → `root_shell.dart`; `lock_screen.dart` (passcode) при рестарте

### Root shell (app)
- Вкладки: чаты / контакты / профиль (root_shell.dart; точный состав табов подтвердить при декомпозиции)

### Чаты
- `chat_list_screen.dart` → `chat_screen.dart` (:914), `create_group_screen.dart` (:874), `new_message_screen.dart`, `search_screen.dart` (глобальный), `story_composer_screen.dart` (:1040)
- `create_group_screen.dart` → `chat_screen.dart` (:105, после создания)
- `chat_screen.dart` → `peer_profile_screen.dart` / `group_info_screen.dart` (:1233, :1244, :1277), `chat_search_screen.dart` (:1717), `video_round_recorder.dart` (:2149), forward (:4010)
- `new_message_screen.dart` / `search_screen.dart` → `chat_screen.dart`
- `forward_message_screen.dart` → выбор чата, возврат в исходный чат

### Профиль / контакты
- `profile_screen.dart` → `settings_screen.dart` (:245), `chat_screen.dart` (Saved Messages, :297), `edit_profile_screen.dart` (:502), avatar editor, QR
- `edit_profile_screen.dart` → `aurion_screen.dart` (Автоматизация чатов), avatar editor (:140)
- `contacts_screen.dart` → `peer_profile_screen.dart` / `chat_screen.dart`

### Настройки (settings_screen.dart)
- Notifications → `settings/notifications_settings.dart` (:73)
- Privacy → `settings/privacy_settings.dart` (:81) → `privacy/two_step_verification_screen.dart` (:84), `privacy/passcode_screen.dart` (:94), `privacy/devices_screen.dart` (:104), `privacy/privacy_selector_screen.dart` (:265, :279), прочее (:118–171)
- Data → `settings/data_settings.dart` (:89)
- Language → `settings/language_settings.dart` (:102)
- Appearance → `settings/appearance_settings.dart` (:281)

### Stories
- `story_composer_screen.dart` (создание) / `story_player.dart` (просмотр) — из chat list и chat header

## 2. Правила навигации

1. **Back**: системный back = закрытие экрана (стек). PRD 2.3.3 (long-press back, список последних экранов) и 2.3.4 (каскадная очередь) — не реализованы.
2. **Из чата** back → список чатов (штатно).
3. **Все** переходы без именованных маршрутов — нет deep links, нет `onGenerateRoute`.
4. Открытие чата из любого места — через `ChatScreen(chat: chat)` + push (единая точка входа: `chat_list_screen.dart:914` и повторные вызовы в search/contacts/profile/root_shell).

## 3. Найденные проблемы

- Дублирование навигации в чат: 6+ мест пушят `ChatScreen` сами; нужен единый хелпер (и, позже, названные маршруты для deep links `vibe.me/@username`).
- `root_shell.dart:110` открывает чат прямо из шелла — смешение слоёв.
- Нет guards: переход в чат требует chat-контекста (kind), проверка членства — через RLS на запросах, UI-проверок нет.
- Из-за отсутствия named routes невозможны deep links `vibe.me/@username` (PRD 2.2.1) и «пробурить дыру» до сообщения (2.4.12).
