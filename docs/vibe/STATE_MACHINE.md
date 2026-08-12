# STATE MACHINE — Vibe Backend & Message Lifecycle

> Источник правды о состояниях данных, синхронизации и realtime. Аудит 11.08.2026.

## 1. Слои состояния

| Слой | Кто держит | Примеры |
|---|---|---|
| Сервер (Supabase) | Postgres + RLS | профили, чаты, сообщения, медиа, сессии |
| Realtime | каналы supabase | `user:{id}`, chat `stream`/`typingEvents`/`msgEvents` |
| Backend-синглтон | `VibeBackend` | JWT-сессия, кеши, сетевое состояние |
| Экранный стейт | StatefulWidget | лента сообщений `_Msg[]`, composer, selection mode |

## 2. Жизненный цикл сессии

```
splash → init():
  restore JWT (auth.getUser)
    ├─ нет сессии → onboarding → auth (login/register)
    └─ есть сессия → realtime-каналы + network monitor → root shell
logout():
  online=false в профиле → signOut → очистка каналов
lock/passcode: LockScreen поверх после рестарта (если passcode установлен)
```

- `login(phone, password)` (`backend.dart:730`): телефон → email `…@vibe.local` → `signInWithPassword`.
- `register()` (`:716`): создание аккаунта; профиль создаёт серверный триггер.
- Сессии: таблица `sessions` + RPC `auth_logout` (серверная инвалидация).

## 3. Состояние сети

- `startNetworkMonitor` / `isOffline` / `connectivityVersion` (`backend.dart`) — оффлайн-детекция.
- **Нет** оффлайн-очереди и автоматического retry для исходящих (PRD 2.7.4 — не реализовано). При оффлайне отправка помечается `failed`? — уточнить поведение `_statusTick` (есть «повторить» у failed-сообщений).

## 4. Жизненный цикл сообщения

```
user taps send
  → _Msg создаётся локально (sending)
  → VibeBackend.sendMessage (upsert в БД, optimistic)
  → realtime подтверждение (stream) → sent
  → получатель доставил → delivered
  → получатель прочитал → read
  → ошибка → failed (пользователь может retry/удалить)
```

- Статусы: `MsgStatus { sending, sent, delivered, read, failed }` (`backend.dart:74`).
- UI-статус держит **экранный** `_Msg`, не БД — БД хранит фактические поля (delivered_at, read_at и т.п.).
- Realtime-события: `msgEvents` = edited / deleted / cleared / reactions; `stream` = новые сообщения; `typingEvents` = индикатор печати (throttle).

## 5. Read state (частично)

- Миграция `supabase/migrations/migrate_v1_7_0_read_state.sql` существует (план PRD 2.7.8: mark_read RPC, batched отправка read-признаков после ~0.5s тишины).
- `_firstUnreadAt` (`backend.dart:334`) — **UnimplementedError**, unread-jump не работает.
- Групповые read receipts (список `read_by`, PRD 2.7.8.3–4) — нет в UI.
- delivered проставляется вручную при доставке; в комментарии кода отмечено, что ручная проставка может нарушать RLS-политики (голосовая почта).

## 6. Кеши и инвалидация

| Кеш | TTL | Место |
|---|---|---|
| `profileById` | 5 мин | `VibeBackend` |
| `chatMemberIds` | 2 мин | `VibeBackend` |
| `chatKindOf` | 2 мин | `VibeBackend` |

Инвалидация — по realtime-событиям и явным вызовам после мутаций.

## 7. Каналы realtime

- Личный канал `user:{id}`: новые чаты (входящие), presence, системные события → `NotificationService` (баннер foreground / локальное уведомление background).
- Канал чата: `stream` (сообщения, бандлы), `typingEvents`, `msgEvents` (edit/delete/clear/reactions).
- Подписки создаются в `ChatScreen.initState`/`didChangeDependencies` и отписываются при dispose.

## 8. Состояния фич (feature flags)

- Aurion AI: состояния `introspection / disabled / enabled / degraded` (PRD 2.5.3) — детали в `AURION_INTELLIGENCE_BIBLE.md`.
- Сетевые/медиа-состояния: подписанные URL через edge-функцию `media-sign` (JWT-права: avatar — любой auth; stories/media/messages — участник чата).

## 9. Найденные проблемы

1. `_firstUnreadAt` → UnimplementedError (упадёт, если вызвать).
2. Нет offline-очереди для сообщений.
3. Read state в группах неполный (нет read_by в UI).
4. «В сети» захардкожено (`profile_screen.dart:185`) — нет зависимости от presence.
5. Chat list и ChatScreen — монолиты; стейт смешан с виджетами (декомпозиция: Фазы 5–6).
