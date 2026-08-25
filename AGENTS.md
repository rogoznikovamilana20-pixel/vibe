# AGENTS.md — рабочие инструкции для агентов в репозитории Vibe

## Репозиторий

- **Проект**: Vibe — Flutter-мессенджер (Vibe Studio).
- **Структура**: `app/` — Flutter-приложение (`lib/`), `supabase/` — миграции/edge-функции, `docs/` — документация.
- **Рабочая копия**: `C:\Users\andre\Documents\Default Project\vibe` (Windows).

## Источники правды (читать перед изменениями)

| Док | Что внутри |
|---|---|
| `docs/PRD.md` | Продуктовое видение, паттерны UX 2.1–2.7 |
| `docs/MASTER_PLAN.md` | Дорожная карта v1.0 «Telegram++», статусы фич |
| `docs/vibe/PRODUCT_BIBLE.md` | Формула продукта, слои, факт-архитектура, проблемы |
| `docs/vibe/STATE_MACHINE.md` | Состояния данных, message lifecycle, realtime, кеши |
| `docs/vibe/UX_BEHAVIOR_BIBLE.md` | Паттерны поведения со статусами и путями в коде |
| `docs/vibe/ENTITY_ACTION_MODEL.md` | Сущности и действия (backend API), gap list |
| `docs/vibe/NAVIGATION_MAP.md` | Карта экранов и переходов |
| `docs/aurion/AURION_INTELLIGENCE_BIBLE.md` | Aurion: факт + vision v2.0 |
| `docs/vibe/PLAN.md` | Журнал исполнения фаз — **обновлять после каждой фазы** |
| `docs/CODE_REVIEW.md` | Результаты ревью кода |

**Референс Telegram**: исходный код Telegram (TDLib/компоненты) — https://github.com/drklo/telegram. Заглядывать для понимания устройства разделов, функционала и механик (при этом Vibe — СВОЙ продукт «Telegram++», не клон: решения адаптировать, код не копировать).

## Правила работы

1. **Existing code first**: расширять работающее, не переписывать. Монолиты `chat_screen.dart` (4210 стр.) и `chat_list_screen.dart` (1953 стр.) декомпозировать только по плану фаз.
2. **No fake features**: не добавлять кнопки/фичи без рабочего бэкенда или честного состояния (degraded/disabled).
3. **Принципы продукта** (из PRODUCT_BIBLE §2): быстрый и тактильный, Дзен, параметры как продукт, сообщение как объект, Aurion — слой не экран.
4. **Точки привязки кода** (проверять при изменениях):
   - Backend-синглтон: `app/lib/data/backend.dart` (`VibeBackend`).
   - Статусы сообщений: `MsgStatus { sending, sent, delivered, read, failed }` (backend.dart:74).
   - Realtime-подписки чата: `chat_screen.dart` (`stream`, `typingEvents`, `msgEvents`).
   - Уведомления: `app/lib/core/services/notification_service.dart`.
   - `_firstUnreadAt` — **UnimplementedError** (backend.dart:334), не вызывать без фикса.
5. **Навигация**: только императивный `Navigator.push`; named routes/deep links не используются. Новые переходы в чат — через существующий паттерн `ChatScreen(chat: chat)`.
6. **Локализация**: не хардкодить строки вне локализованных файлов (точечный аудит — в плане фаз).
7. **Документация**: статусы в доках менять только вместе с кодом (факты, не намерения).

## MCP routing (engineered environment)

Подключено в `opencode.jsonc` (корень воркспейса). Направление задач:

| Задача | MCP-сервер | Что даёт |
|---|---|---|
| Документация Flutter/Dart/пакетов | `context7` | актуальные API, версии, синтаксис (не полагаться на устаревшие знания модели) |
| Flutter/Dart тулинг, тесты, интроспекция | `dart-flutter` | analyze, widget tree, hot reload, pub, DTD |
| Репозиторий/PR/issues/CI/релизы | `github` | официальный GitHub MCP server (локальный бинарник + `GITHUB_PERSONAL_ACCESS_TOKEN` из gh) |
| Браузер/E2E web-поверхностей | `playwright` | chromium-автоматизация, visual/E2E для web/admin |
| Backend/DB Supabase | `supabase` | схема, RLS, SQL, миграции (read-only режим) |
| Сложные многошаговые рассуждения | `sequential-thinking` | декомпозиция/верификация гипотез |
| Долговременное знание проекта | `memory` | ADR, архитектурные решения, лимиты |

Использовать только когда нативные инструменты OpenCode не покрывают задачу. Не включать все MCP в каждый workflow.

Известные ограничения: `ui-color-palette` **отключён** — его схема тула `create_color_harmony` (кортежный `items`) отклоняется провайдером (400). Секреты в конфиге — только через `{env:VAR}` (переменные заданы в user env: `TOKENROUTER_API_KEY`, `SUPABASE_ACCESS_TOKEN`, `GITHUB_PERSONAL_ACCESS_TOKEN`).

## Проверка (если код менялся)

```bash
cd app
flutter analyze      # статический анализ
flutter test         # тесты, если есть
```

## Команды (Windows PowerShell)

- Сборка: `flutter build apk` / `flutter run` из `app/`
- Доки: `docs/` (правка только по факту кода)
