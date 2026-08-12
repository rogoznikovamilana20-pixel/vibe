# ENTITY / ACTION MODEL — Vibe

> Источник правды о сущностях и их действиях: что существует в коде, как называется, кто может вызвать, что происходит в UI/БД. Аудит 11.08.2026.

## 1. Сущности

| Сущность | Модель в коде | Хранение | Примечания |
|---|---|---|---|
| User/Auth | Supabase auth + `users` | Postgres, RLS | сессии в `sessions` |
| Profile | `lib/data/*` (Profile) | `profiles` table, RLS owner | фото/emoji-аватар, username, phone, bio |
| Contact | производная | **локальная** (не в БД, PRD 2.6.6) | из PM-чатов, лимит 200 |
| Chat | `Chat` | `chats` table | kinds: pm / group / saved |
| Message | `_Msg` (экран), `Message` (данные) | `messages` table | статусы см. STATE_MACHINE |
| Media | — | `media` table + storage | подписанные URL через `media-sign` |
| Story | Story | stories table | создание/чтение E2E реализовано (MASTER_PLAN 2.7) |
| Reaction | — | reactions (в msgEvents) | **UI нет** (PRD 2.7.3) |
| Session | — | `sessions` | `DevicesScreen` |

## 2. Действия по сущностям (backend API, `lib/data/backend.dart`)

### Auth
| Action | Метод | Примечание |
|---|---|---|
| init / restore JWT | `init()` :411 | + realtime + network monitor |
| login | `login(phone, password)` :730 | телефон → `…@vibe.local` |
| register | `register()` :716 | профиль создаёт серверный триггер |
| logout | `logout()` | online=false, signOut, чистка каналов |

### Profile
| Action | Метод |
|---|---|
| Установить мой профиль | `setMyProfile(...)` |
| Прочитать профиль | `profileById(id)` (кеш 5 мин) |
| Обновить | `updateProfile(...)` |
| Проверка username | `isUsernameAvailable(username)` |
| Свой профиль | getter `myProfile` |

### Контакты / поиск
| Action | Метод |
|---|---|
| Список контактов | `listContacts()` (из PM-чатов, лимит 200) |
| Поиск людей | `searchUsers(q)` (ilike, лимит 20) |

### Чаты
| Action | Метод |
|---|---|
| PM-чат по контакту | `ensurePmChat(userId)` |
| Создать группу | `createGroupChat(ids, title)` |
| Saved messages | `ensureSavedChat()` |
| Участники | `chatMemberIds(chatId)` (кеш 2 мин) |
| Тип чата | `chatKindOf(chatId)` (кеш 2 мин) |
| Участники группы | `groupMembers(chatId)` |
| Переименовать группу | `renameGroup(chatId, title)` |
| Закрепление чатов | pinned (chat list) |

### Сообщения
| Action | Метод | Примечание |
|---|---|---|
| Отправить | `sendMessage(...)` | optimistic upsert |
| Редактировать | RPC edit | UI-поддержка? (MASTER_PLAN: 2.7.1 «реализовано?» — проверить) |
| Переслать | forward flow | `ForwardMessageScreen` — работает (PRD 2.7.2) |
| Удалить / очистить | delete / clear | msgEvents → удаление в лентах |
| Прочитать | mark read RPC | см. STATE_MACHINE §5 (частично) |
| Ответить | reply flow | UI в composer |

### Медиа
| Action | Примечание |
|---|---|
| Загрузить | storage upload, ссылки `media-sign` |
| Доступ | JWT-права (avatar: любой auth; media/stories/messages: участник) |

### Сеть
`startNetworkMonitor()` / `isOffline` / `connectivityVersion`.

## 3. Карта «экран → действия» (основное)

- **Chat list**: open chat (push), create group, new message, story composer, search, pin/delete чат, контекст-меню.
- **Chat**: send/edit/delete/clear/reply/forward/copy/save, attach media, video round recorder, emoji-sticker panel, chat search, peer profile, group info, unread-jump (broken).
- **Contacts**: поиск, открыть PM, создать группу, «добавить аккаунт» (stub).
- **Profile (свой)**: QR, avatar editor, edit data, settings, saved messages, aurion (автоматизация), menu (цвет/rename/копировать ссылку).
- **Peer profile**: написать, (аудио/видео — stub).
- **Settings tree**: notifications / privacy (passcode, 2FA, devices, селекторы who-can-see) / data / language / appearance / aurion.

## 4. Недостающие действия (gap list)

| Действие | Где должно жить | Статус |
|---|---|---|
| Reactions add/remove | msgEvents уже передаёт | нет UI |
| Edit message UI | composer/context | проверить |
| Pinned messages (в чате) | chat header/context | нет |
| Archive / mute / mark unread (чат) | chat list dismissible/context | нет |
| Drafts | composer | нет |
| Read_by (группы) | message footer | нет |
| Calls | peer profile / chat header | stub |
| Мультиаккаунт | profile | stub |
| Infо о пользователе / личный канал | edit_profile | stub |
