# RuStore Listing — Vibe 1.7.0

**Package:** `com.vibe.messenger`  
**Version:** 1.7.0+2 (AAB 90MB, 94_364_362 bytes)  
**TargetSdk:** flutter.targetSdkVersion (34), minSdk flutter.minSdkVersion

## Краткое описание (до 80 симв)
Мессенджер с E2E-шифрованием, звонками и бизнес-витринами.

## Полное описание (RuStore, до 4000)
Vibe — быстрый и тактильный мессенджер в духе Telegram++:
- Личные и групповые чаты, каналы, бизнес-пространства
- E2E X25519 + AES-GCM (v2, Double Ratchet), `media-sign` 3600с, RAM-only очередь
- Голосовые (свайп отмена), видеокружки (свайп блок), фото/файлы/гифки, опросы, реакции, цитаты, пересылка
- Звонки 1-1 и групповые через LiveKit (`livekit-token` ACTIVE), `group_call` blur
- Сториз, палитра неона, `VibeGlassSurface` 60fps (RepaintBoundary)
- Контакты `+` → `searchUsers` без телефона, `offline` баннер + кэш
- FCM пуши `send-push` (F-048 без plaintext), `POST_NOTIFICATIONS` по запросу

## Что нового 1.7.0
- Подписанные URL медиа (`media-sign` с проверкой чата, anon 401 чужой 403)
- Бизнес-тарифы `start/micro/growth/scale/enterprise` + `showcases`/`metrics_daily`
- 60fps: `RepaintBoundary` для `VibeGlassSurface`/`Staggered`/`MessageBubble`
- Контакты `+` в шапке чатов, `ChatListDiff` helper
- 25 таблиц RLS (63 политики), 1801 тест, `analyze` 4 info

## Скриншоты (docs/screenshots)
- `phone_main.png` (326KB) — основной
- `phone_icons_fixed.png` / `phone_icons_fixed2.png` — иконки
- `screen1.png` (корень) — доп

## Иконки
- `app/assets/icon.png` 33KB, `logo_v.png` 95KB — адаптивная, 512x512

## Категория
Связь / Мессенджеры, 0+

## Разрешения (обоснование для модерации)
- `POST_NOTIFICATIONS` — пуши о новых сообщениях (запрос в рантайме)
- `CAMERA` — фото/кружки/сториз (по тапу)
- `RECORD_AUDIO`/`MODIFY_AUDIO_SETTINGS` — голосовые/звонки (по тапу)
- `USE_BIOMETRIC` — разблок `passcode` (опционально)

## Контакты
support@vibe.messenger, https://vibe.messenger/privacy (PRIVACY_RUSTORE.md)

## Чек-лист перед загрузкой
- [x] AAB 90MB подписан `vibe-release.jks` (alias vibe, 2724 bytes, 10k дней)
- [x] `version 1.7.0+2` везде (pubspec, msix 1.7.0.0)
- [x] `PRIVACY_RUSTORE.md` + `DATA_SAFETY_RUSTORE.md` готовы
- [ ] Залить AAB в RuStore консоль → Data Safety (таблица mic/camera/contacts) → скрины → отправить на модерацию
