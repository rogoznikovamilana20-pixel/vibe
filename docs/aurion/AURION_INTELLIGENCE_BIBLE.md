# AURION INTELLIGENCE BIBLE

> Aurion — персональный AI-ассистент Vibe. Этот документ фиксирует: текущее состояние (факт из кода), целевую архитектуру и дорогу к v2.0. Источники: `app/lib/screens/aurion_screen.dart`, `docs/PRD.md §2.5`, master-промпт (принцип «Aurion — слой, не экран»).

## 1. Состояние сегодня (аудит 11.08.2026): UI-превью

**`AurionScreen`** (`lib/screens/aurion_screen.dart`, 315 строк) — «персональный AI-ассистент (UI-превью)»:

- Вход: «Настройки → Автоматизация чатов» (`edit_profile_screen.dart`) и/или профиль — путь `EditProfileScreen → AurionScreen(userName)`.
- Структура: `VibeCollapsibleScreen` + `VibeTopBar` (title «Aurion», бейдж «онлайн» — **захардкожен зелёным**, не presence), Hero-карточка с градиентом `VibeColors.aurionGradient`, приветствие «Привет, {userName}! 👋», описание роли.
- 4 суггестии: «Перескажи вчерашний чат по работе», «Перепиши позлее 💅», «Сделай из этого список задач», «Идеи для поста в канал» (tap → подставляет в `VibeInput`).
- Composer: `VibeInput` («Спроси Aurion…») + кнопка отправки; `_send()` → `HapticFeedback.mediumImpact()`, очистка поля, snack **«Aurion отвечает — в v2.0»**.
- **Нет** API-интеграции, настроек, ключей, истории, состояний фич.

## 2. Целевая архитектура (vision v2.0)

**Aurion — слой, а не экран** (принцип master-промпта): живёт внутри composer чата, контекстного меню сообщения, поиска — не отдельный чат/экран.

Слои целевой реализации (`lib/core/aurion/*`, фаза планирования):

| Слой | Модуль | Ответственность |
|---|---|---|
| Providers | `providers/*` | GigaChat (обязательный), позже Claude/Gemini/Local |
| Intent Router | `intent_router.dart` | парсит намерение → инструменты: summarize, rewrite, checklist, translate, extract, generate |
| Permission Manager | `permission_manager.dart` | доступ к контексту чата: с кем можно делиться перепиской; запрос и ревокация |
| Tool Registry | `tool_registry.dart` | инструменты, доступные интентам (chat context, media, calendar...) |
| Feature Flags | `feature_flags.dart` | состояния флага AI-фичи (см. §4) |
| AI Hygiene | `ai_hygiene.dart` | журнал взаимодействий, очистка данных/истории |
| Memory | `memory/` | (2027) on-device локальная модель, история |

## 3. Настройки как продукт (PRD 2.5.1–2.5.2)

- **GigaChat API key — «настройка продукта»**: hardcoded URL к GigaChat, сменяемый ключ и модель.
- Первичное подключение: intro → on/off → поле API key (сейф-хранение, keyring).
- «Параметры должны быть не кнопкой, а продуктом»: статус подключения, тест ключа, диагностика.

## 4. Состояния AI-фичи (PRD 2.5.3)

```
introspection ──→ enabled ──→ degraded ──→ disabled
(первый запуск, (ключ валиден, (частичный сбой, (ключ нет/невалиден
мастер-настройка)  провайдер жив)    fallback-режим)   или пользователь off)
```

- `introspection` — экран первичного подключения.
- `enabled` — полный функционал.
- `degraded` — провайдер недоступен/лимиты; UI показывает честный статус, простые интенты работают локально (checklist, rewrite).
- `disabled` — UI скрывает AI-элементы (нет «мёртвых кнопок» — принцип No fake features).

## 5. AI-гигиена и приватность (PRD 2.5.4–2.5.5)

- Clear data (журнал взаимодействий) и Clear history — обязательные настройки, работают всегда и сохраняются.
- Privacy-модель: off-device через провайдер; (2027) on-device локальная модель (TinyLlama 20K и т.п.) — обсуждение, не обязательство.
- Permission Manager: контекст чата делится с AI только с явного согласия; журнал согласий.

## 6. Дорога к v2.0 (этапы)

1. **AurionCore (backend-интеграция)**: `AurionProvider` (GigaChat, ключ из настроек, hardcoded URL, timeout/retry), генерация ответа, стриминг.
2. **Feature flags + гигиена**: состояния по §4, журнал, clear data/history.
3. **Intent Router v1**: summarize / rewrite / checklist / translate / extract-tasks с контекстом активного чата (тот самый «вчерашний чат»).
4. **Встраивание в слой**: AI-комposer в чате, AI-действия в контекстном меню сообщения (PRD 2.4.16/17 — свайп-жесты доступа к composer), единый UX.
5. **Permission Manager + память** (2027).

## 7. Нельзя делать

- Не делать второй «чат с ботом» внутри Vibe (Aurion — слой).
- Не публиковать «мёртвые» AI-кнопки без состояния (degraded/disabled честно показываются).
- Не хранить API-ключ в открытом виде (keyring/secure storage, env для сервисных ключей — PRD 2.6.1).
- Не отправлять контекст чата в AI без явного разрешения (permission manager).
