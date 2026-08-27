import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';
import 'backend_api.dart';
import 'chat_folder.dart';

/// Действие свайпа по чату в списке (TG: SwipeGestureSettingsView).
enum ChatSwipeAction {
  archive,
  read,
  mute,
  pin,
  delete,
}

class SettingsService {
  SettingsService._();
  static final instance = SettingsService._();

  late SharedPreferences _prefs;
  final _secureStorage = const FlutterSecureStorage();

  // 3.7: зеркало приватности — локальный кеш остаётся главным,
  // облако — best-effort (как закрепы): при изменении пишем целиком,
  // при старте приложения (main) — забираем актуальные значения.
  VibeBackendApi? _privacySyncer;

  @visibleForTesting
  void setPrivacySyncerForTest(VibeBackendApi b) => _privacySyncer = b;

  VibeBackendApi? get _privacyBackend {
    try {
      return _privacySyncer ??= LiveVibeBackend();
    } catch (_) {
      return null;
    }
  }

  // Ключи
  static const _keyTheme = 'vibe_theme';
  static const _keyAccentColor = 'vibe_accent_color';
  static const _keyBubbleRadius = 'vibe_bubble_radius';
  static const _keyFontSize = 'vibe_font_size';
  static const _keyLanguage = 'vibe_language';
  static const _keyStoriesHint = 'vibe_stories_hint';
  static const _keyListDensity = 'vibe_list_density';
  static const _keyBio = 'vibe_bio';

  // Изменение настроек внешнего вида: счётчик, на который можно
  // подписаться, чтобы перерисовать списки/чаты на лету.
  final ValueNotifier<int> appearanceVersion = ValueNotifier<int>(0);

  void _bumpAppearance() => appearanceVersion.value++;

  /// Био профиля (пока локально, синхронизация появится позже).
  final ValueNotifier<String> bio = ValueNotifier<String>('');

  // Уведомления
  static const _keyNotifyPersonal = 'vibe_notify_personal';
  static const _keyNotifyGroups = 'vibe_notify_groups';
  static const _keyInAppSounds = 'vibe_inapp_sounds';
  static const _keyInAppVibration = 'vibe_inapp_vibration';
  static const _keyChatPreview = 'vibe_chat_preview';

  // Приватность
  static const _keyPrivacyPhone = 'vibe_privacy_phone';
  static const _keyPrivacyLastSeen = 'vibe_privacy_last_seen';
  static const _keyPrivacyPhoto = 'vibe_privacy_photo';
  static const _keyPrivacyForward = 'vibe_privacy_forward';
  static const _keyPrivacyCalls = 'vibe_privacy_calls';
  static const _keyPrivacyGroups = 'vibe_privacy_groups';
  static const _keyAutoDelete = 'vibe_auto_delete';
  static const _keyPinnedChats = 'vibe_pinned_chats';
  static const _keyHiddenChats = 'vibe_hidden_chats';
  static const _keyMutedChats = 'vibe_muted_chats';
  static const _keyDeletedChats = 'vibe_deleted_chats';
  static const _keyBlockedUsers = 'vibe_blocked_users';
  static const _keyFolders = 'vibe_folders';
  static const _keyFolderAssign = 'vibe_folder_assign';

  // Уведомления: бейдж и тихие часы
  static const _keyBadgeEnabled = 'vibe_badge_enabled';
  static const _keyQuietHoursEnabled = 'vibe_quiet_hours_enabled';
  static const _keyQuietHoursStart = 'vibe_quiet_hours_start';
  static const _keyQuietHoursEnd = 'vibe_quiet_hours_end';

  // Внешний вид: отправка по Enter, авто-ночь, анимации, шрифт, прозрачность
  static const _keySendByEnter = 'vibe_send_by_enter';
  static const _keyAutoNightEnabled = 'vibe_auto_night_enabled';
  static const _keyAutoNightStart = 'vibe_auto_night_start';
  static const _keyAutoNightEnd = 'vibe_auto_night_end';
  static const _keyAnimationsEnabled = 'vibe_animations_enabled';
  static const _keyMessageFontFamily = 'vibe_message_font_family';
  static const _keyBubbleOpacity = 'vibe_bubble_opacity';
  static const _keyChatBackgroundBlur = 'vibe_chat_background_blur';

  // Свайп по чату в списке (как TG: одно действие, настраивается в настройках)
  static const _keyChatSwipeAction = 'vibe_chat_swipe_action';

  ChatSwipeAction get chatSwipeAction {
    final name = _prefs.getString(_keyChatSwipeAction);
    if (name == null) return ChatSwipeAction.archive; // TG default
    return ChatSwipeAction.values.firstWhere(
      (a) => a.name == name,
      orElse: () => ChatSwipeAction.archive,
    );
  }

  Future<void> setChatSwipeAction(ChatSwipeAction action) async {
    await _prefs.setString(_keyChatSwipeAction, action.name);
    _bumpAppearance();
  }

  // Приватность: голосовые сообщения, био, день рождения
  static const _keyPrivacyVoiceMessages = 'vibe_privacy_voice_messages';
  static const _keyPrivacyBio = 'vibe_privacy_bio';
  static const _keyPrivacyBirthday = 'vibe_privacy_birthday';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    bio.value = _prefs.getString(_keyBio) ?? '';
    await _migrateProxyPassword();
  }

  /// One-time migration: move proxy password from SharedPreferences to SecureStorage.
  /// F-049: proxy password must not be stored in plaintext SharedPreferences.
  Future<void> _migrateProxyPassword() async {
    final legacyValue = _prefs.getString(_keyProxyPassword);
    if (legacyValue != null && legacyValue.isNotEmpty) {
      await _secureStorage.write(key: _keyProxyPassword, value: legacyValue);
      await _prefs.remove(_keyProxyPassword);
    }
  }

  // Тема
  ThemeMode get themeMode {
    final val = _prefs.getString(_keyTheme);
    if (val == 'dark') return ThemeMode.dark;
    if (val == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_keyTheme, mode.name);
  }

  // Акцентный цвет
  int get accentColorValue => _prefs.getInt(_keyAccentColor) ?? 0xFF8B4DFF;

  /// Сигнал об изменении акцентного цвета — тема пересобирается на лету.
  final ValueNotifier<int> accentVersion = ValueNotifier<int>(0);

  Future<void> setAccentColor(int color) async {
    await _prefs.setInt(_keyAccentColor, color);
    accentVersion.value++;
  }

  // Радиус пузырей
  double get bubbleRadius => _prefs.getDouble(_keyBubbleRadius) ?? 17.0;

  Future<void> setBubbleRadius(double val) async {
    await _prefs.setDouble(_keyBubbleRadius, val);
    _bumpAppearance();
  }

  // Плотность списка чатов: 0 — компактный, 1 — просторный
  double get listDensity => _prefs.getDouble(_keyListDensity) ?? 0.6;

  Future<void> setListDensity(double val) async {
    await _prefs.setDouble(_keyListDensity, val);
    _bumpAppearance();
  }

  // Размер шрифта
  double get fontSizeDelta => _prefs.getDouble(_keyFontSize) ?? 0.0;

  Future<void> setFontSizeDelta(double val) async {
    await _prefs.setDouble(_keyFontSize, val);
    _bumpAppearance();
  }

  // Био профиля
  Future<void> setBio(String val) async {
    await _prefs.setString(_keyBio, val);
    bio.value = val;
  }

  // Язык
  String get languageCode => _prefs.getString(_keyLanguage) ?? 'ru';

  Future<void> setLanguageCode(String code) async {
    await _prefs.setString(_keyLanguage, code);
  }

  // Уведомления
  bool get notifyPersonal => _prefs.getBool(_keyNotifyPersonal) ?? true;
  Future<void> setNotifyPersonal(bool val) async {
    await _prefs.setBool(_keyNotifyPersonal, val);
  }

  bool get notifyGroups => _prefs.getBool(_keyNotifyGroups) ?? true;
  Future<void> setNotifyGroups(bool val) async {
    await _prefs.setBool(_keyNotifyGroups, val);
    _bumpNotifications();
  }

  // Звук/вибрация/превью уведомлений (in-app колбэков, баннеров и системных).
  bool get inAppSounds => _prefs.getBool(_keyInAppSounds) ?? true;
  Future<void> setInAppSounds(bool val) async {
    await _prefs.setBool(_keyInAppSounds, val);
    _bumpNotifications();
  }

  bool get inAppVibration => _prefs.getBool(_keyInAppVibration) ?? true;
  Future<void> setInAppVibration(bool val) async {
    await _prefs.setBool(_keyInAppVibration, val);
    _bumpNotifications();
  }

  /// Превью текста сообщений в уведомлениях/баннерах.
  bool get chatPreview => _prefs.getBool(_keyChatPreview) ?? true;
  Future<void> setChatPreview(bool val) async {
    await _prefs.setBool(_keyChatPreview, val);
    _bumpNotifications();
  }

  // Бейдж-счётчик на иконке
  bool get badgeEnabled => _prefs.getBool(_keyBadgeEnabled) ?? true;
  Future<void> setBadgeEnabled(bool val) async {
    await _prefs.setBool(_keyBadgeEnabled, val);
    _bumpNotifications();
  }

  // Тихие часы (DND)
  bool get quietHoursEnabled => _prefs.getBool(_keyQuietHoursEnabled) ?? false;
  Future<void> setQuietHoursEnabled(bool val) async {
    await _prefs.setBool(_keyQuietHoursEnabled, val);
    _bumpNotifications();
  }

  int get quietHoursStart => _prefs.getInt(_keyQuietHoursStart) ?? 23;
  Future<void> setQuietHoursStart(int hour) async {
    await _prefs.setInt(_keyQuietHoursStart, hour);
    _bumpNotifications();
  }

  int get quietHoursEnd => _prefs.getInt(_keyQuietHoursEnd) ?? 7;
  Future<void> setQuietHoursEnd(int hour) async {
    await _prefs.setInt(_keyQuietHoursEnd, hour);
    _bumpNotifications();
  }

  bool get isQuietHoursNow {
    if (!quietHoursEnabled) return false;
    final now = DateTime.now().hour;
    final s = quietHoursStart;
    final e = quietHoursEnd;
    if (s <= e) {
      return now >= s && now < e;
    } else {
      return now >= s || now < e;
    }
  }

  // Отправка по Enter
  bool get sendByEnter => _prefs.getBool(_keySendByEnter) ?? false;
  Future<void> setSendByEnter(bool val) async {
    await _prefs.setBool(_keySendByEnter, val);
    _bumpAppearance();
  }

  // Авто-ночь
  bool get autoNightEnabled => _prefs.getBool(_keyAutoNightEnabled) ?? false;
  Future<void> setAutoNightEnabled(bool val) async {
    await _prefs.setBool(_keyAutoNightEnabled, val);
    _bumpAppearance();
  }

  int get autoNightStart => _prefs.getInt(_keyAutoNightStart) ?? 22;
  Future<void> setAutoNightStart(int hour) async {
    await _prefs.setInt(_keyAutoNightStart, hour);
    _bumpAppearance();
  }

  int get autoNightEnd => _prefs.getInt(_keyAutoNightEnd) ?? 7;
  Future<void> setAutoNightEnd(int hour) async {
    await _prefs.setInt(_keyAutoNightEnd, hour);
    _bumpAppearance();
  }

  bool get shouldUseDarkBySchedule {
    if (!autoNightEnabled) return false;
    final now = DateTime.now().hour;
    final s = autoNightStart;
    final e = autoNightEnd;
    if (s <= e) {
      return now >= s && now < e;
    } else {
      return now >= s || now < e;
    }
  }

  // AyuGram-глубина: анимации, шрифт сообщений, прозрачность пузырей
  bool get animationsEnabled => _prefs.getBool(_keyAnimationsEnabled) ?? true;
  Future<void> setAnimationsEnabled(bool v) async {
    await _prefs.setBool(_keyAnimationsEnabled, v);
    _bumpAppearance();
  }

  String get messageFontFamily => _prefs.getString(_keyMessageFontFamily) ?? 'Roboto';
  Future<void> setMessageFontFamily(String v) async {
    await _prefs.setString(_keyMessageFontFamily, v);
    _bumpAppearance();
  }

  double get bubbleOpacity => _prefs.getDouble(_keyBubbleOpacity) ?? 1.0;
  Future<void> setBubbleOpacity(double v) async {
    await _prefs.setDouble(_keyBubbleOpacity, v.clamp(0.5, 1.0));
    _bumpAppearance();
  }

  bool get chatBackgroundBlur => _prefs.getBool(_keyChatBackgroundBlur) ?? true;
  Future<void> setChatBackgroundBlur(bool v) async {
    await _prefs.setBool(_keyChatBackgroundBlur, v);
    _bumpAppearance();
  }

  // AyuGram-глубина: ChatList
  static const _keyAvatarSize = 'vibe_avatar_size';
  static const _keyPreviewLines = 'vibe_preview_lines';
  static const _keyShowDate = 'vibe_show_date';
  static const _keyShowStatus = 'vibe_show_status';

  double get avatarSize => _prefs.getDouble(_keyAvatarSize) ?? 52.0;
  Future<void> setAvatarSize(double v) async {
    await _prefs.setDouble(_keyAvatarSize, v.clamp(32, 52));
    _bumpAppearance();
  }

  int get previewLines => _prefs.getInt(_keyPreviewLines) ?? 1;
  Future<void> setPreviewLines(int v) async {
    await _prefs.setInt(_keyPreviewLines, v.clamp(1, 3));
    _bumpAppearance();
  }

  bool get showDate => _prefs.getBool(_keyShowDate) ?? true;
  Future<void> setShowDate(bool v) async {
    await _prefs.setBool(_keyShowDate, v);
    _bumpAppearance();
  }

  bool get showStatus => _prefs.getBool(_keyShowStatus) ?? true;
  Future<void> setShowStatus(bool v) async {
    await _prefs.setBool(_keyShowStatus, v);
    _bumpAppearance();
  }

  // AyuGram-глубина: Messages
  static const _keyBubbleTail = 'vibe_bubble_tail';
  static const _keyShowTicks = 'vibe_show_ticks';
  static const _keyMessageFontSize = 'vibe_message_font_size';

  bool get bubbleTail => _prefs.getBool(_keyBubbleTail) ?? true;
  Future<void> setBubbleTail(bool v) async {
    await _prefs.setBool(_keyBubbleTail, v);
    _bumpAppearance();
  }

  bool get showTicks => _prefs.getBool(_keyShowTicks) ?? true;
  Future<void> setShowTicks(bool v) async {
    await _prefs.setBool(_keyShowTicks, v);
    _bumpAppearance();
  }

  double get messageFontSize => _prefs.getDouble(_keyMessageFontSize) ?? 16.0;
  Future<void> setMessageFontSize(double v) async {
    await _prefs.setDouble(_keyMessageFontSize, v.clamp(12, 18));
    _bumpAppearance();
  }

  // AyuGram-глубина: Navigation
  static const _keyNavigationStyle = 'vibe_navigation_style';
  static const _keyFabVisible = 'vibe_fab_visible';
  static const _keyIconPack = 'vibe_icon_pack';

  String get navigationStyle => _prefs.getString(_keyNavigationStyle) ?? 'bottom';
  Future<void> setNavigationStyle(String v) async {
    await _prefs.setString(_keyNavigationStyle, v);
    _bumpAppearance();
  }

  bool get fabVisible => _prefs.getBool(_keyFabVisible) ?? true;
  Future<void> setFabVisible(bool v) async {
    await _prefs.setBool(_keyFabVisible, v);
    _bumpAppearance();
  }

  String get iconPack => _prefs.getString(_keyIconPack) ?? 'vibe';
  Future<void> setIconPack(String v) async {
    await _prefs.setString(_keyIconPack, v);
    _bumpAppearance();
  }

  // Приватность: голосовые, био, день рождения (0: Все, 1: Контакты, 2: Никто)
  int get privacyVoiceMessages => _prefs.getInt(_keyPrivacyVoiceMessages) ?? 0;
  Future<void> setPrivacyVoiceMessages(int val) async {
    await _prefs.setInt(_keyPrivacyVoiceMessages, val);
    _pushPrivacy();
  }

  int get privacyBio => _prefs.getInt(_keyPrivacyBio) ?? 0;
  Future<void> setPrivacyBio(int val) async {
    await _prefs.setInt(_keyPrivacyBio, val);
    _pushPrivacy();
  }

  int get privacyBirthday => _prefs.getInt(_keyPrivacyBirthday) ?? 0;
  Future<void> setPrivacyBirthday(int val) async {
    await _prefs.setInt(_keyPrivacyBirthday, val);
    _pushPrivacy();
  }

  /// Сигнал об изменении настроек уведомлений — сервис уведомлений
  /// перечитывает их на лету.
  final ValueNotifier<int> notificationsVersion = ValueNotifier<int>(0);
  void _bumpNotifications() => notificationsVersion.value++;

  // Автозагрузка медиа (Данные и память)
  static const _keyAutoMediaMobile = 'vibe_auto_media_mobile';
  static const _keyAutoMediaWifi = 'vibe_auto_media_wifi';
  static const _keyAutoMediaRoaming = 'vibe_auto_media_roaming';

  bool get autoMediaMobile => _prefs.getBool(_keyAutoMediaMobile) ?? true;
  Future<void> setAutoMediaMobile(bool v) async {
    await _prefs.setBool(_keyAutoMediaMobile, v);
  }

  bool get autoMediaWifi => _prefs.getBool(_keyAutoMediaWifi) ?? true;
  Future<void> setAutoMediaWifi(bool v) async {
    await _prefs.setBool(_keyAutoMediaWifi, v);
  }

  bool get autoMediaRoaming => _prefs.getBool(_keyAutoMediaRoaming) ?? false;
  Future<void> setAutoMediaRoaming(bool v) async {
    await _prefs.setBool(_keyAutoMediaRoaming, v);
  }

  // Приватность (0: Все, 1: Мои контакты, 2: Никто)
  int get privacyPhone => _prefs.getInt(_keyPrivacyPhone) ?? 0;
  Future<void> setPrivacyPhone(int val) async {
    await _prefs.setInt(_keyPrivacyPhone, val);
    _pushPrivacy();
  }

  int get privacyLastSeen => _prefs.getInt(_keyPrivacyLastSeen) ?? 0;
  Future<void> setPrivacyLastSeen(int val) async {
    await _prefs.setInt(_keyPrivacyLastSeen, val);
    _pushPrivacy();
  }

  int get privacyPhoto => _prefs.getInt(_keyPrivacyPhoto) ?? 0;
  Future<void> setPrivacyPhoto(int val) async {
    await _prefs.setInt(_keyPrivacyPhoto, val);
    _pushPrivacy();
  }

  int get privacyForward => _prefs.getInt(_keyPrivacyForward) ?? 0;
  Future<void> setPrivacyForward(int val) async {
    await _prefs.setInt(_keyPrivacyForward, val);
    _pushPrivacy();
  }

  int get privacyCalls => _prefs.getInt(_keyPrivacyCalls) ?? 0;
  Future<void> setPrivacyCalls(int val) async {
    await _prefs.setInt(_keyPrivacyCalls, val);
    _pushPrivacy();
  }

  int get privacyGroups => _prefs.getInt(_keyPrivacyGroups) ?? 0;
  Future<void> setPrivacyGroups(int val) async {
    await _prefs.setInt(_keyPrivacyGroups, val);
    _pushPrivacy();
  }

  /// 3.7: синхронизация приватности в облако (best-effort, молча).
  void _pushPrivacy() {
    final b = _privacyBackend;
    if (b == null) return;
    final settings = PrivacySettings(
      lastSeen: privacyLastSeen,
      photo: privacyPhoto,
      forward: privacyForward,
      calls: privacyCalls,
      groups: privacyGroups,
      voiceMessages: privacyVoiceMessages,
      bio: privacyBio,
      birthday: privacyBirthday,
    );
    unawaited(() async {
      try {
        await b.savePrivacy(settings);
      } catch (_) {}
    }());
  }

  /// 3.7: забрать облачные настройки приватности при старте (best-effort);
  /// вызывается из main.dart после init. При недоступности сервера
  /// локальные значения остаются нетронутыми.
  Future<void> loadPrivacyFromServer() async {
    final b = _privacyBackend;
    if (b == null) return;
    try {
      final p = await b.fetchPrivacy();
      if (p == null) return;
      await setPrivacyLastSeen(p.lastSeen);
      await setPrivacyPhoto(p.photo);
      await setPrivacyForward(p.forward);
      await setPrivacyCalls(p.calls);
      await setPrivacyGroups(p.groups);
      await setPrivacyVoiceMessages(p.voiceMessages);
      await setPrivacyBio(p.bio);
      await setPrivacyBirthday(p.birthday);
    } catch (_) {}
  }

  // Автоудаление аккаунта (в месяцах: 1, 3, 6, 12)
  int get autoDeleteMonths => _prefs.getInt(_keyAutoDelete) ?? 6;
  Future<void> setAutoDeleteMonths(int val) async {
    await _prefs.setInt(_keyAutoDelete, val);
  }

  // Закреплённые чаты (id чатов, локально на устройстве)
  List<String> get pinnedChats => _prefs.getStringList(_keyPinnedChats) ?? const [];
  Future<void> setPinnedChats(List<String> ids) async {
    await _prefs.setStringList(_keyPinnedChats, ids);
  }

  // Скрытые чаты (id чатов, локально + защита пасскодом на экране)
  List<String> get hiddenChats =>
      _prefs.getStringList(_keyHiddenChats) ?? const [];

  /// Сигнал об изменении списка скрытых чатов (список чатов обновляет
  /// чип-счётчик и ленту скрытых на лету).
  final ValueNotifier<int> hiddenVersion = ValueNotifier<int>(0);

  Future<void> setHiddenChats(List<String> ids) async {
    await _prefs.setStringList(_keyHiddenChats, ids);
    hiddenVersion.value++;
  }

  // Чаты с выключенным звуком уведомлений («Не беспокоить»), локально
  List<String> get mutedChats => _prefs.getStringList(_keyMutedChats) ?? const [];

  /// Закреплённые сообщения: chatId → список serverId (локальный кеш
  /// облачных закрепов; новые сверху).
  static const _keyChatPins = 'vibe_chat_pins';

  List<String> pinnedMessageIds(String chatId) =>
      _prefs.getStringList('$_keyChatPins:$chatId') ?? const [];

  Future<void> setPinnedMessageIds(String chatId, List<String> ids) async {
    await _prefs.setStringList('$_keyChatPins:$chatId', ids);
  }

  /// Сигнал об изменении списка приглушённых чатов (например, из экрана чата),
  /// чтобы список чатов обновил иконки «без звука» на лету.
  final ValueNotifier<int> mutedVersion = ValueNotifier<int>(0);

  Future<void> setMutedChats(List<String> ids) async {
    await _prefs.setStringList(_keyMutedChats, ids);
    mutedVersion.value++;
  }

  // 8.3.2: удалённые для себя чаты (локально, как в TG — исчезают из ленты,
  // пока не напишет собеседник заново). Серверного deleteChat нет — честная
  // локальная деградация.
  List<String> get deletedChats =>
      _prefs.getStringList(_keyDeletedChats) ?? const [];

  final ValueNotifier<int> deletedVersion = ValueNotifier<int>(0);

  Future<void> setDeletedChats(List<String> ids) async {
    await _prefs.setStringList(_keyDeletedChats, ids);
    deletedVersion.value++;
  }

  // Заблокированные пользователи (id профилей). Локально, как в TG:
  // новые сообщения от них не приходят, чат скрыт до разблокировки.
  List<String> get blockedUsers =>
      _prefs.getStringList(_keyBlockedUsers) ?? const [];

  /// Сигнал об изменении списка заблокированных (список чатов
  /// фильтруется на лету).
  final ValueNotifier<int> blockedVersion = ValueNotifier<int>(0);

  bool isBlocked(String userId) => blockedUsers.contains(userId);

  Future<void> setBlockedUsers(List<String> ids) async {
    await _prefs.setStringList(_keyBlockedUsers, ids);
    blockedVersion.value++;
  }

  Future<void> addBlockedUser(String userId) async {
    final list = blockedUsers;
    if (list.contains(userId)) return;
    list.add(userId);
    await setBlockedUsers(list);
  }

  Future<void> removeBlockedUser(String userId) async {
    final list = blockedUsers;
    list.remove(userId);
    await setBlockedUsers(list);
  }

  // Показывалась ли обучающая подсказка в сторис (только при первом открытии)
  bool get storiesHintShown => _prefs.getBool(_keyStoriesHint) ?? false;
  Future<void> setStoriesHintShown() async {
    await _prefs.setBool(_keyStoriesHint, true);
  }

  // Черновики сообщений: chatId → текст (как в ТГ — «Черновик: …» в списке)
  static const _keyDrafts = 'vibe_drafts';

  String? draftFor(String chatId) => _prefs.getString('$_keyDrafts:$chatId');

  /// Сохранить черновик; `null`/пустой — удалить.
  Future<void> setDraft(String chatId, String? text) async {
    if (text == null || text.trim().isEmpty) {
      await _prefs.remove('$_keyDrafts:$chatId');
    } else {
      await _prefs.setString('$_keyDrafts:$chatId', text);
    }
  }

  // 8.3.7: пользовательские папки чатов (локально, персистентно).
  // Состав папок — ручное назначение: один чат в одной папке
  // («Без папки» — просто отсутствие назначения).
  List<VibeChatFolder> get chatFolders {
    final raw = _prefs.getStringList(_keyFolders);
    if (raw == null) return const [];
    return raw
        .map((s) {
          try {
            return VibeChatFolder.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<VibeChatFolder>()
        .toList();
  }

  /// Сигнал об изменении папок/назначений — лента обновляет чипы на лету.
  final ValueNotifier<int> foldersVersion = ValueNotifier<int>(0);

  Future<void> _saveFolders(List<VibeChatFolder> folders) async {
    await _prefs.setStringList(_keyFolders, [
      for (final f in folders) jsonEncode(f.toJson()),
    ]);
  }

  Future<void> addFolder(String title, {String emoji = '📁', Set<String> filters = const {}}) async {
    final folders = [...chatFolders];
    folders.add(
      VibeChatFolder(
        id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        emoji: emoji,
        filters: filters,
      ),
    );
    await _saveFolders(folders);
    foldersVersion.value++;
  }

  Future<void> renameFolder(
    String id,
    String title, {
    String? emoji,
    Set<String>? filters,
  }) async {
    final folders = [
      for (final f in chatFolders)
        if (f.id == id)
          VibeChatFolder(id: f.id, title: title, emoji: emoji ?? f.emoji, filters: filters ?? f.filters)
        else
          f,
    ];
    await _saveFolders(folders);
    foldersVersion.value++;
  }

  /// Удалить папку: вместе с ней убираются все назначения чатов.
  Future<void> removeFolder(String id) async {
    await _saveFolders(
      chatFolders.where((f) => f.id != id).toList(),
    );
    final stale = _prefs.getKeys().where((k) {
      if (!k.startsWith('$_keyFolderAssign:')) return false;
      return _prefs.getString(k) == id;
    }).toList();
    for (final k in stale) {
      await _prefs.remove(k);
    }
    foldersVersion.value++;
  }

  /// Перетаскивание папок как в TG (ReorderableListView).
  Future<void> reorderFolders(int oldIndex, int newIndex) async {
    final folders = [...chatFolders];
    if (oldIndex < 0 || oldIndex >= folders.length || newIndex < 0 || newIndex > folders.length) return;
    if (newIndex > oldIndex) newIndex--;
    final item = folders.removeAt(oldIndex);
    folders.insert(newIndex, item);
    await _saveFolders(folders);
    foldersVersion.value++;
  }

  /// Папка чата (null — «Без папки»).
  String? folderOf(String chatId) =>
      _prefs.getString('$_keyFolderAssign:$chatId');

  Future<void> setFolderForChat(String chatId, String? folderId) async {
    final key = '$_keyFolderAssign:$chatId';
    if (folderId == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, folderId);
    }
    foldersVersion.value++;
  }

  // ── Обои чата ──
  static const _keyWallpaperType = 'vibe_wallpaper_type'; // 'none' | 'color' | 'gradient'
  static const _keyWallpaperValue = 'vibe_wallpaper_value'; // int color value
  static const _keyWallpaperEndValue = 'vibe_wallpaper_end_value';

  // ── Мультиаккаунт (как в TG: до 3) ──
  static const _keyAccounts = 'vibe_accounts';
  List<String> get accounts => _prefs.getStringList(_keyAccounts) ?? const [];
  Future<void> addAccount(String id) async {
    final list = [...accounts];
    if (list.length >= 3) return;
    if (list.contains(id)) return;
    list.add(id);
    await _prefs.setStringList(_keyAccounts, list);
  }

  Future<void> removeAccount(String id) async {
    final list = [...accounts]..remove(id);
    await _prefs.setStringList(_keyAccounts, list);
  }

  String get wallpaperType => _prefs.getString(_keyWallpaperType) ?? 'none';
  int get wallpaperColor => _prefs.getInt(_keyWallpaperValue) ?? 0xFF1A1A2E;
  int get wallpaperEndColor => _prefs.getInt(_keyWallpaperEndValue) ?? 0xFF16213E;

  Future<void> setWallpaper(String type, {int? color, int? endColor}) async {
    await _prefs.setString(_keyWallpaperType, type);
    if (color != null) await _prefs.setInt(_keyWallpaperValue, color);
    if (endColor != null) await _prefs.setInt(_keyWallpaperEndValue, endColor);
    _bumpAppearance();
  }

  // ── Proxy / VPN ──
  static const _keyProxyEnabled = 'vibe_proxy_enabled';
  static const _keyProxyHost = 'vibe_proxy_host';
  static const _keyProxyPort = 'vibe_proxy_port';
  static const _keyProxyUsername = 'vibe_proxy_username';
  static const _keyProxyPassword = 'vibe_proxy_password';
  static const _keyProxySocks5 = 'vibe_proxy_socks5';

  bool get proxyEnabled => _prefs.getBool(_keyProxyEnabled) ?? false;
  String get proxyHost => _prefs.getString(_keyProxyHost) ?? '';
  int get proxyPort => _prefs.getInt(_keyProxyPort) ?? 0;
  String get proxyUsername => _prefs.getString(_keyProxyUsername) ?? '';
  bool get proxySocks5 => _prefs.getBool(_keyProxySocks5) ?? true;

  Future<String> proxyPassword() async =>
      await _secureStorage.read(key: _keyProxyPassword) ?? '';

  Future<void> setProxyEnabled(bool v) async => _prefs.setBool(_keyProxyEnabled, v);
  Future<void> setProxyHost(String v) async => _prefs.setString(_keyProxyHost, v);
  Future<void> setProxyPort(int v) async => _prefs.setInt(_keyProxyPort, v);
  Future<void> setProxyUsername(String v) async => _prefs.setString(_keyProxyUsername, v);
  Future<void> setProxyPassword(String v) async =>
      await _secureStorage.write(key: _keyProxyPassword, value: v);
  Future<void> setProxySocks5(bool v) async => _prefs.setBool(_keyProxySocks5, v);

  // ── Бизнес (масштабируемо: Старт → Энтерпрайз) ──
  static const _keyBusinessTier = 'vibe_business_tier';
  String get businessTier => _prefs.getString(_keyBusinessTier) ?? 'start';
  Future<void> setBusinessTier(String v) async {
    await _prefs.setString(_keyBusinessTier, v);
    _bumpAppearance();
  }

  /// Лимиты по тиру (витрины/товары/команда/чаты)
  Map<String, int> get businessLimits {
    switch (businessTier) {
      case 'micro':
        return {'showcases': 1, 'products': 50, 'members': 3, 'chats': 2000};
      case 'growth':
        return {'showcases': 5, 'products': 500, 'members': 10, 'chats': 15000};
      case 'scale':
        return {'showcases': 20, 'products': 5000, 'members': 50, 'chats': 100000};
      case 'enterprise':
        return {'showcases': 999999, 'products': 999999, 'members': 999999, 'chats': 999999};
      case 'start':
      default:
        return {'showcases': 1, 'products': 10, 'members': 1, 'chats': 500};
    }
  }

  // ── Сброс всех настроек ──
  Future<void> resetAll() async {
    await _prefs.clear();
    bio.value = '';
    _bumpAppearance();
    _bumpNotifications();
    accentVersion.value++;
    hiddenVersion.value++;
    foldersVersion.value++;
  }
}
