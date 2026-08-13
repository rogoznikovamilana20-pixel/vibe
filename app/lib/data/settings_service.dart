import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._();
  static final instance = SettingsService._();

  late SharedPreferences _prefs;

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
  static const _keyBlockedUsers = 'vibe_blocked_users';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    bio.value = _prefs.getString(_keyBio) ?? '';
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
  int get accentColorValue => _prefs.getInt(_keyAccentColor) ?? 0xFF8B5CF6;

  /// Сигнал об изменении акцентного цвета — тема пересобирается на лету.
  final ValueNotifier<int> accentVersion = ValueNotifier<int>(0);

  Future<void> setAccentColor(int color) async {
    await _prefs.setInt(_keyAccentColor, color);
    accentVersion.value++;
  }

  // Радиус пузырей
  double get bubbleRadius => _prefs.getDouble(_keyBubbleRadius) ?? 18.0;

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
  }

  int get privacyLastSeen => _prefs.getInt(_keyPrivacyLastSeen) ?? 0;
  Future<void> setPrivacyLastSeen(int val) async {
    await _prefs.setInt(_keyPrivacyLastSeen, val);
  }

  int get privacyPhoto => _prefs.getInt(_keyPrivacyPhoto) ?? 0;
  Future<void> setPrivacyPhoto(int val) async {
    await _prefs.setInt(_keyPrivacyPhoto, val);
  }

  int get privacyForward => _prefs.getInt(_keyPrivacyForward) ?? 0;
  Future<void> setPrivacyForward(int val) async {
    await _prefs.setInt(_keyPrivacyForward, val);
  }

  int get privacyCalls => _prefs.getInt(_keyPrivacyCalls) ?? 0;
  Future<void> setPrivacyCalls(int val) async {
    await _prefs.setInt(_keyPrivacyCalls, val);
  }

  int get privacyGroups => _prefs.getInt(_keyPrivacyGroups) ?? 0;
  Future<void> setPrivacyGroups(int val) async {
    await _prefs.setInt(_keyPrivacyGroups, val);
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
}
