import 'package:flutter/material.dart';

class VibeLocalizations {
  VibeLocalizations(this.locale);

  final Locale locale;

  static VibeLocalizations of(BuildContext context) {
    return Localizations.of<VibeLocalizations>(context, VibeLocalizations)!;
  }

  static const _localizedValues = {
    'ru': {
      'settings': 'Настройки',
      'account': 'Аккаунт',
      'username': 'Имя пользователя',
      'uid': 'Числовой идентификатор',
      'bio': 'О себе',
      'appearance': 'Оформление',
      'notifications': 'Уведомления и звуки',
      'privacy': 'Конфиденциальность',
      'data': 'Данные и память',
      'language': 'Язык',
      'support': 'Поддержка',
      'ask_question': 'Задать вопрос',
      'faq': 'Вопросы о Vibe',
      'policy': 'Политика конфиденциальности',
      'logout': 'Выйти',
      'online': 'в сети',
      'copy_success': 'Скопировано',
      'theme': 'Тема',
      'light': 'Светлая',
      'dark': 'Тёмная',
      'system': 'Системная',
      'chat_settings': 'Настройки чата',
      'bubble_radius': 'Скругление пузырей',
      'text_size': 'Размер текста',
      'accent_color': 'Цветовая схема',
      'personal_chats': 'Личные чаты',
      'groups': 'Группы',
      'notifications_from_chats': 'Уведомления из чатов',
      'channels': 'Каналы',
      'in_app': 'В приложении',
      'in_app_sounds': 'Звуки в приложении',
      'vibration': 'Вибрация',
      'chat_preview': 'Превью чатов',
      'reset_notifications': 'Сбросить все уведомления',
      'security': 'Безопасность',
      'two_step': 'Двухэтапная аутентификация',
      'passcode': 'Код-пароль',
      'devices': 'Устройства',
      'phone_number': 'Номер телефона',
      'last_activity': 'Последняя активность',
      'profile_photo': 'Фотография профиля',
      'auto_delete': 'Дополнительно',
      'delete_if_inactive': 'Удалить аккаунт',
      'storage_usage': 'Использование памяти',
      'network_usage': 'Использование сети',
      'auto_media_download': 'Автозагрузка медиа',
      'mobile_network': 'Через мобильную сеть',
      'wi_fi': 'Через Wi-Fi',
      'roaming': 'В роуминге',
      'calls': 'Звонки',
      'data_saver': 'Экономия трафика',
      'active': 'Включено',
      'off': 'Выключено',
      'all': 'Все',
      'contacts': 'Мои контакты',
      'nobody': 'Никто',
      'forwarding': 'Пересылка сообщений',
      'calls_and_groups': 'Звонки и группы',
      'who_can_see_phone': 'Кто может видеть мой номер телефона',
      'who_can_see_last_seen': 'Кто может видеть время моего последнего входа',
      'who_can_see_photo': 'Кто может видеть мою фотографию профиля',
      'who_can_add_to_groups': 'Кто может добавлять меня в группы',
      'who_can_call_me': 'Кто может мне звонить',
      'passcode_lock': 'Код-пароль',
      'set_passcode': 'Установить код-пароль',
      'change_passcode': 'Изменить код-пароль',
      'turn_passcode_off': 'Выключить код-пароль',
      'unlock_with_biometrics': 'Разблокировка биометрией',
      'auto_lock': 'Автоблокировка',
      'sessions': 'Активные сеансы',
      'terminate_all_sessions': 'Завершить все другие сеансы',
      'lock_title': 'Vibe заблокирован',
      'lock_enter_passcode': 'Введите код-пароль',
      'lock_wrong_passcode': 'Неверный код-пароль',
      'lock_too_many_attempts': 'Слишком много неверных попыток. Ввод заблокирован на 30 секунд.',
      'lock_attempts_left': 'Неверный код-пароль. Осталось попыток: ',
      'auto_lock_off': 'Выключено',
      'auto_lock_immediately': 'Сразу',
      'languages_available': 'Доступные сейчас: Русский и English. Остальные — скоро.',
    },
    'en': {
      'settings': 'Settings',
      'account': 'Account',
      'username': 'Username',
      'uid': 'User ID',
      'bio': 'Bio',
      'appearance': 'Appearance',
      'notifications': 'Notifications & Sounds',
      'privacy': 'Privacy & Security',
      'data': 'Data & Storage',
      'language': 'Language',
      'support': 'Support',
      'ask_question': 'Ask a Question',
      'faq': 'Vibe FAQ',
      'policy': 'Privacy Policy',
      'logout': 'Log Out',
      'online': 'online',
      'copy_success': 'Copied',
      'theme': 'Theme',
      'light': 'Light',
      'dark': 'Dark',
      'system': 'System',
      'chat_settings': 'Chat Settings',
      'bubble_radius': 'Bubble Radius',
      'text_size': 'Text Size',
      'accent_color': 'Color Scheme',
      'personal_chats': 'Personal Chats',
      'groups': 'Groups',
      'notifications_from_chats': 'Notifications from chats',
      'channels': 'Channels',
      'in_app': 'In-App',
      'in_app_sounds': 'In-App Sounds',
      'vibration': 'Vibration',
      'chat_preview': 'Chat Preview',
      'reset_notifications': 'Reset All Notifications',
      'security': 'Security',
      'two_step': 'Two-Step Verification',
      'passcode': 'Passcode Lock',
      'devices': 'Devices',
      'phone_number': 'Phone Number',
      'last_activity': 'Last Seen & Online',
      'profile_photo': 'Profile Photo',
      'auto_delete': 'Advanced',
      'delete_if_inactive': 'Delete My Account',
      'storage_usage': 'Storage Usage',
      'network_usage': 'Network Usage',
      'auto_media_download': 'Automatic Media Download',
      'mobile_network': 'When using mobile data',
      'wi_fi': 'When connected on Wi-Fi',
      'roaming': 'When roaming',
      'calls': 'Calls',
      'data_saver': 'Less Data for Calls',
      'active': 'Active',
      'off': 'Off',
      'all': 'Everybody',
      'contacts': 'My Contacts',
      'nobody': 'Nobody',
      'forwarding': 'Forwarded Messages',
      'calls_and_groups': 'Calls & Groups',
      'who_can_see_phone': 'Who can see my phone number',
      'who_can_see_last_seen': 'Who can see my Last Seen time',
      'who_can_see_photo': 'Who can see my profile photos',
      'who_can_add_to_groups': 'Who can add me to groups',
      'who_can_call_me': 'Who can call me',
      'passcode_lock': 'Passcode Lock',
      'set_passcode': 'Set a Passcode',
      'change_passcode': 'Change Passcode',
      'turn_passcode_off': 'Turn Passcode Off',
      'unlock_with_biometrics': 'Unlock with Biometrics',
      'auto_lock': 'Auto-Lock',
      'sessions': 'Active Sessions',
      'terminate_all_sessions': 'Terminate all other sessions',
      'lock_title': 'Vibe is Locked',
      'lock_enter_passcode': 'Enter your passcode',
      'lock_wrong_passcode': 'Wrong passcode',
      'lock_too_many_attempts': 'Too many failed attempts. Input is locked for 30 seconds.',
      'lock_attempts_left': 'Wrong passcode. Attempts left: ',
      'auto_lock_off': 'Disabled',
      'auto_lock_immediately': 'Immediately',
      'languages_available': 'Available now: Russian and English. Others coming soon.',
    },
  };

  String _get(String key) => _localizedValues[locale.languageCode]![key]!;

  String get settings => _get('settings');
  String get account => _get('account');
  String get username => _get('username');
  String get uid => _get('uid');
  String get bio => _get('bio');
  String get appearance => _get('appearance');
  String get notifications => _get('notifications');
  String get privacy => _get('privacy');
  String get data => _get('data');
  String get language => _get('language');
  String get support => _get('support');
  String get askQuestion => _get('ask_question');
  String get faq => _get('faq');
  String get policy => _get('policy');
  String get logout => _get('logout');
  String get online => _get('online');
  String get copySuccess => _get('copy_success');
  String get theme => _get('theme');
  String get light => _get('light');
  String get dark => _get('dark');
  String get system => _get('system');
  String get chatSettings => _get('chat_settings');
  String get bubbleRadius => _get('bubble_radius');
  String get textSize => _get('text_size');
  String get accentColor => _get('accent_color');
  String get personalChats => _get('personal_chats');
  String get groups => _get('groups');
  String get notificationsFromChats => _get('notifications_from_chats');
  String get channels => _get('channels');
  String get inApp => _get('in_app');
  String get inAppSounds => _get('in_app_sounds');
  String get vibration => _get('vibration');
  String get chatPreview => _get('chat_preview');
  String get resetNotifications => _get('reset_notifications');
  String get security => _get('security');
  String get twoStep => _get('two_step');
  String get passcode => _get('passcode');
  String get devices => _get('devices');
  String get phoneNumber => _get('phone_number');
  String get lastActivity => _get('last_activity');
  String get profilePhoto => _get('profile_photo');
  String get autoDelete => _get('auto_delete');
  String get deleteIfInactive => _get('delete_if_inactive');
  String get storageUsage => _get('storage_usage');
  String get networkUsage => _get('network_usage');
  String get autoMediaDownload => _get('auto_media_download');
  String get mobileNetwork => _get('mobile_network');
  String get wiFi => _get('wi_fi');
  String get roaming => _get('roaming');
  String get calls => _get('calls');
  String get dataSaver => _get('data_saver');
  String get active => _get('active');
  String get off => _get('off');
  String get all => _get('all');
  String get contacts => _get('contacts');
  String get nobody => _get('nobody');
  String get forwarding => _get('forwarding');
  String get callsAndGroups => _get('calls_and_groups');
  String get whoCanSeePhone => _get('who_can_see_phone');
  String get whoCanSeeLastSeen => _get('who_can_see_last_seen');
  String get whoCanSeePhoto => _get('who_can_see_photo');
  String get whoCanAddToGroups => _get('who_can_add_to_groups');
  String get whoCanCallMe => _get('who_can_call_me');
  String get passcodeLock => _get('passcode_lock');
  String get setPasscode => _get('set_passcode');
  String get changePasscode => _get('change_passcode');
  String get turnPasscodeOff => _get('turn_passcode_off');
  String get unlockWithBiometrics => _get('unlock_with_biometrics');
  String get autoLock => _get('auto_lock');
  String get sessions => _get('sessions');
  String get terminateAllSessions => _get('terminate_all_sessions');
  String get lockTitle => _get('lock_title');
  String get lockEnterPasscode => _get('lock_enter_passcode');
  String get lockWrongPasscode => _get('lock_wrong_passcode');
  String get lockTooManyAttempts => _get('lock_too_many_attempts');
  String lockAttemptsLeft(int count) => '${_get('lock_attempts_left')}$count';
  String get autoLockOff => _get('auto_lock_off');
  String get autoLockImmediately => _get('auto_lock_immediately');
  String get languagesAvailable => _get('languages_available');
}

class VibeLocalizationsDelegate extends LocalizationsDelegate<VibeLocalizations> {
  const VibeLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ru', 'en'].contains(locale.languageCode);

  @override
  Future<VibeLocalizations> load(Locale locale) async {
    return VibeLocalizations(locale);
  }

  @override
  bool shouldReload(VibeLocalizationsDelegate old) => false;
}
