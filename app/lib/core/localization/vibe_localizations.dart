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
      'general_settings': 'Основные настройки',
      'tooltip_back': 'Назад',
      'tooltip_clear': 'Очистить',
      'tooltip_cancel': 'Отмена',
      'tooltip_send': 'Отправить',
      'tooltip_search': 'Поиск',
      'tooltip_call': 'Позвонить',
      'tooltip_more': 'Ещё',
      'tooltip_next': 'Следующее',
      'error_server_unavailable': 'Сервер недоступен',
      'error_search_unavailable': 'Поиск недоступен — проверьте сеть',
      'search_title': 'Поиск',
      'search_enter_query': 'Введите запрос',
      'search_messages_hint': 'Поиск сообщений',
      'search_messages_not_found': 'Сообщения не найдены',
      'search_nothing_found': 'Ничего не найдено',
      'search_hint': 'Поиск',
      'search_by_nick_hint': 'Поиск по никнейму или телефону...',
      'search_global_title': 'Глобальный поиск',
      'search_global_subtitle': 'Введите @никнейм или номер телефона, чтобы найти человека в Vibe.',
      'new_message_title': 'Новое сообщение',
      'new_message_subtitle': 'Начните переписку или позвоните',
      'new_contact_title': 'Новый контакт',
      'new_contact_hint': 'Имя или @ник',
      'new_contact_find': 'Найти',
      'new_contact_invite_friend': 'Пригласить друга',
      'action_write': 'Написать',
      'date_today': 'Сегодня',
      'date_yesterday': 'Вчера',
      'message_forwarded_from': 'Переслано от',
      'message_edited': 'изменено',
      'message_photo_to_chat': 'Фото к чату',
      'message_no_voice': 'Нет голосового',
      'message_location': 'Локация',
      'message_open_in_maps': 'Открыть в картах',
      'message_contact_default': 'Собеседник',
      'file_sending': 'Отправка…',
      'file_saved': 'Сохранено: ',
      'file_download_failed': 'Не удалось скачать файл',
      'file_default_name': 'файл',
      'file_unknown_size': 'Неизвестно',
      'poll_default_question': 'Вопрос',
      'poll_votes_zero': '0 голосов',
      'chat_status_group': 'Группа',
      'status_online': 'в сети',
      'status_recently': 'был(а) недавно',
      'chat_menu_notifications': 'Уведомления',
      'chat_menu_sound_off': 'Звук выключен',
      'chat_menu_dnd': 'Не беспокоить',
      'chat_menu_media': 'Медиа',
      'chat_menu_search': 'Поиск в чате',
      'chat_menu_chat_info': 'Сведения о чате',
      'chat_menu_archive': 'Архивировать',
      'chat_menu_delete_chat': 'Удалить чат',
      'chat_menu_clear_history': 'Очистить историю',
      'chat_menu_mute_sound': 'Выключить звук',
      'chat_menu_mute_for_a_while': 'Выключить на время',
      'chat_menu_configure': 'Настроить',
      'mute_duration_1_hour': '1 час',
      'mute_duration_8_hours': '8 часов',
      'mute_duration_1_day': '1 день',
      'mute_duration_2_days': '2 дня',
      'mute_duration_1_week': '1 неделя',
      'composer_reply_to': 'Ответ',
      'composer_cancel_reply': 'Отменить ответ',
      'chat_swipe_unpin': 'Открепить',
      'chat_swipe_archive': 'Архив',
      'chat_swipe_from_archive': 'Из архива',
      'chat_swipe_dnd': 'Не беспокоить',
      'chat_swipe_enable_notifications': 'Включить уведомления',
      'chat_draft_label': 'Черновик: ',
      'chat_in_archive': 'В архиве',
      'chat_new': 'Новый',
      'invite_text': 'Заходи в Vibe — мой мессенджер. Жду тебя!',
      'invite_copied': 'Приглашение скопировано — отправьте его другу',
      'folders_title': 'Папки',
      'folders_new_folder': 'Новая папка',
      'folders_empty_title': 'Папок пока нет',
      'folders_empty_subtitle': 'Разложите чаты по темам: работа, учёба, свои',
      'folders_create_folder': 'Создать папку',
      'folders_delete_folder': 'Удалить папку',
      'folders_save': 'Сохранить',
      'folders_name_required': 'Назовите папку',
      'folders_name_hint': 'Название папки',
      'folders_emoji_label': 'Эмодзи папки',
      'folders_no_chats': 'Чатов пока нет — напишите кому-нибудь',
      'links_title': 'Мои ссылки',
      'links_profile_link': 'Ссылка на профиль',
      'links_username': 'Имя пользователя',
      'links_phone': 'Телефон',
      'links_copy_link': 'Копировать ссылку',
      'links_qr_code': 'QR-код профиля',
      'links_copied': 'Ссылка скопирована',
      'recording_too_short': 'Запись слишком короткая',
      'recording_camera_unavailable': 'Камера недоступна',
      'recording_swipe_to_lock': 'Свайп вверх — зафиксировать',
      'two_step_create_password': 'Придумайте пароль',
      'two_step_password_description': 'Этот пароль будет запрашиваться при входе на новом устройстве в дополнение к коду из SMS.',
      'two_step_confirm_password': 'Повторите пароль',
      'two_step_hint': 'Подсказка для пароля',
      'two_step_hint_description': 'Вы можете оставить подсказку, которая поможет вспомнить пароль.',
      'two_step_password_too_short': 'Пароль слишком короткий',
      'two_step_passwords_dont_match': 'Пароли не совпадают',
      'two_step_enabled': 'Двухэтапная аутентификация включена',
      'two_step_save_error': 'Ошибка при сохранении',
      'chat_screen_action_reply': 'Ответить',
      'chat_screen_action_copy': 'Копировать',
      'chat_screen_action_copy_link': 'Копировать ссылку',
      'chat_screen_action_forward': 'Переслать',
      'chat_screen_action_edit': 'Редактировать',
      'chat_screen_action_edit_history': 'История правок',
      'chat_screen_action_delete': 'Удалить',
      'chat_screen_action_pin': 'Закрепить',
      'chat_screen_action_unpin': 'Открепить',
      'chat_screen_input_hint': 'Сообщение…',
      'chat_screen_copied': 'Скопировано',
      'chat_screen_link_copied': 'Ссылка скопирована',
      'chat_screen_saved_to_gallery': 'Сохранено в галерею',
      'chat_screen_download_error': 'Ошибка скачивания',
      'chat_screen_edit_history': 'История правок',
      'chat_screen_no_edits': 'Правок не найдено',
      'settings_privacy_voice_messages': 'Голосовые сообщения',
      'settings_privacy_biography': 'Биография',
      'settings_privacy_birthday': 'День рождения',
      'settings_privacy_blocked': 'Заблокированные',
      'settings_data_clear_cache_confirm': 'Очистить кэш?',
      'settings_data_clear_all': 'Очистить всё',
      'settings_data_clear_cache': 'Очистить кэш',
      'settings_appearance_reset_confirm': 'Сбросить настройки?',
      'settings_appearance_reset_description': 'Все настройки внешнего вида будут сброшены к значениям по умолчанию.',
      'settings_appearance_reset': 'Сбросить',
      'settings_appearance_auto_night': 'Авто-ночь',
      'settings_appearance_enter_to_send': 'Отправка по Enter',
      'settings_appearance_chat_wallpaper': 'Обои чата',
      'settings_appearance_reset_defaults': 'Сбросить к умолчаниям',
      'settings_notifications_badge_quiet_hours': 'Badge и тихие часы',
      'settings_notifications_quiet_hours': 'Тихие часы',
      'profile_logout_confirm': 'Вы уверены, что хотите выйти из аккаунта?',
      'dialog_cancel': 'Отмена',
      'dialog_delete': 'Удалить',
      'dialog_save': 'Сохранить',
      'dialog_close': 'Закрыть',
      'onboarding_security_title': 'Защита сообщений',
      'onboarding_business_title': 'Бизнес прямо в чатах',
      'onboarding_vibe_title': 'Своя экономика и вайб',
      'gif_search_hint': 'Поиск GIF…',
      'story_publish_label': 'Опубликовать',
      'story_retry_label': 'Повторить',
      'story_photo_failed': 'Не удалось сделать фото',
      'aurion_hint': 'Спроси Aurion…',
      'aurion_connect': 'Подключить',
      'aurion_copied': 'Скопировано',
      'forward_hint': 'Поиск',
      'profile_screen_phone': 'Телефон',
      'profile_screen_username': 'Имя пользователя',
      'profile_screen_my_links': 'Мои ссылки',
      'profile_screen_saved': 'Сохранённое',
      'profile_screen_settings': 'Настройки',
      'profile_screen_logout': 'Выйти',
      'profile_screen_number_copied': 'Номер скопирован',
      'profile_screen_color_updated': 'Цвет профиля обновлён',
      'profile_screen_name_updated': 'Имя обновлено',
      'profile_screen_name_hint': 'Имя и фамилия',
      'profile_screen_nick_hint': 'Имя пользователя (@ник)',
      'profile_screen_bio_hint': 'О себе (до 70 символов)',
      'profile_setup_avatar_hint': 'Выбери аватарку',
      'profile_setup_name_hint': 'Как тебя зовут?',
      'profile_setup_nick_hint': 'Никнейм (например, alex_vibe)',
      'group_info_rename': 'Переименовать',
      'group_info_leave': 'Выйти из группы',
      'group_info_no_members': 'Пока нет участников',
      'group_info_name_hint': 'Введите название',
      'contacts_add_soon': 'Добавление контакта — скоро',
      'contacts_load_failed': 'Не удалось загрузить контакты',
      'create_group_hint': 'Поиск по имени или @нику',
      'create_group_load_failed': 'Не удалось загрузить контакты',
      'create_group_create_failed': 'Не удалось создать группу',
      'chat_list_new_message': 'Новое сообщение',
      'chat_list_story_published': 'История опубликована, синхронизирована',
      'chat_list_story_publish_failed': 'Не удалось опубликовать',
      'chat_list_block_tooltip': 'Заблокировать',
      'chat_list_deselect': 'Снять выделение',
      'chat_list_mark_read': 'Прочитано',
      'chat_list_to_archive': 'В архив',
      'chat_list_hide_tooltip': 'Скрыть',
      'chat_list_delete_tooltip': 'Удалить',
      'chat_list_done_tooltip': 'Готово',
      'chat_list_menu_tooltip': 'Меню чатов',
      'voice_recorder_locked_hint': 'Зафиксировано — тап по кнопке: отправить',
      'voice_recorder_swipe_hint': 'Свайп вверх — зафиксировать · влево — отменить',
      'video_recorder_locked_hint': 'Зафиксировано',
      'video_recorder_swipe_hint': 'Свайп вверх — зафиксировать · влево — отмена',
      'peer_profile_message': 'Сообщение',
      'peer_profile_audio': 'Аудио',
      'peer_profile_video': 'Видео',
      'settings_report_hint': 'Опишите вопрос или проблему…',
      'settings_report_sent': 'Вопрос отправлен команде Vibe',
      'settings_send': 'Отправить',
      'settings_close': 'Закрыть',
      'chat_pin_chat': 'Закрепить чат',
      'chat_unpin_chat': 'Открепить чат',
      'chat_enable_notifications': 'Включить уведомления',
      'chat_do_not_disturb': 'Не беспокоить',
      'chat_unarchive': 'Разархивировать',
      'chat_archive_to': 'В архив',
      'chat_show_chat': 'Показать чат',
      'chat_hide_chat': 'Скрыть чат',
      'chat_hide_subtitle': 'Прячет чат из списка; доступ по пасскоду',
      'chat_mark_read': 'Отметить прочитанным',
      'chat_mark_unread': 'Отметить непрочитанным',
      'chat_reordered': 'Порядок чатов обновлён',
      'msg_translate': 'Перевести',
      'msg_translated': 'Переведено',
      'chat_menu_export': 'Экспорт чата',
      'chat_export_done': 'Экспорт готов',
      'proxy_title': 'Прокси',
      'proxy_connection': 'Подключение',
      'proxy_enable': 'Включить прокси',
      'proxy_connected': 'Подключено',
      'proxy_disabled': 'Выключено',
      'proxy_server': 'Сервер',
      'proxy_host': 'Хост',
      'proxy_host_hint': 'proxy.example.com',
      'proxy_port': 'Порт',
      'proxy_port_hint': '1080',
      'proxy_type': 'Тип',
      'proxy_auth': 'Авторизация',
      'proxy_username': 'Имя пользователя',
      'proxy_username_hint': 'Необязательно',
      'proxy_password': 'Пароль',
      'proxy_password_hint': 'Необязательно',
      'proxy_test': 'Проверить соединение',
      'proxy_testing': 'Проверка...',
      'proxy_test_ok': 'Соединение установлено',
      'proxy_test_fail': 'Не удалось подключиться',
      'chat_move_to_folder': 'В папку',
      'chat_folder_hint': 'Разложите чаты по своим папкам',
      'chat_select_chats': 'Выбрать чаты',
      'folder_all': 'Все',
      'folder_personal': 'Личные',
      'folder_groups': 'Группы',
      'folder_channels': 'Каналы',
      'folder_business': 'Бизнес',
      'folder_no_folder': 'Без папки',
      'folder_empty_hint': 'Папок пока нет — создайте их на экране «Папки»',
      'folder_manage': 'Управление папками',
      'chat_title': 'Чаты',
      'action_lock': 'Заблокировать',
      'action_chats_menu': 'Меню чатов',
      'action_clear_selection': 'Снять выделение',
      'action_read': 'Прочитано',
      'action_archive': 'В архив',
      'action_hide': 'Скрыть',
      'action_delete': 'Удалить',
      'action_done': 'Готово',
      'theme_day_mode': 'Дневной режим',
      'theme_night_mode': 'Ночной режим',
      'action_create_group': 'Создать группу',
      'action_saved': 'Избранное',
      'greeting_night': 'Доброй ночи',
      'greeting_morning': 'Доброе утро',
      'greeting_day': 'Добрый день',
      'greeting_evening': 'Добрый вечер',
      'story_my_story': 'Моя история',
      'story_friend': 'Друг',
      'story_published': 'История опубликована · синхронизирована',
      'story_publish_failed': 'Не удалось опубликовать',
      'archive_empty': 'Архив пуст',
      'hidden_empty': 'Скрытых чатов нет',
      'chat_empty': 'Нет чатов',
      'hidden_empty_subtitle': 'Здесь будут чаты, которые вы спрячете сюда',
      'chat_empty_subtitle': 'Начните переписку — это самый быстрый способ попробовать Vibe',
      'action_new_message': 'Новое сообщение',
      'archive_title': 'Архив',
      'hidden_title': 'Скрытые',
      'action_back_to_chats': 'К чатам →',
      'hidden_protection_title': 'Защита скрытых чатов',
      'hidden_protection_body': 'Скрытые чаты охраняются код-паролем. Настройте его в «Настройки → Конфиденциальность».',
      'action_later': 'Позже',
      'action_set': 'Установить',
      'aurion_card_subtitle': 'Твой встроенный ИИ-ассистент',
      'profile_saved_messages': 'Избранные сообщения',
      'chat_pinned': 'Закреплённые',
      'archive_subtitle': 'Чаты с выключенными уведомлениями',
      'schedule_title': 'Отложить отправку',
      'schedule_in_1_hour': 'Через 1 час',
      'schedule_tomorrow_9am': 'Завтра в 09:00',
      'schedule_pick_datetime': 'Выбрать дату и время…',
      'schedule_scheduled': 'Запланировано на',
      'schedule_list_title': 'Запланированные сообщения',
      'schedule_cancelled': 'Отправка отменена',
      'schedule_cancel_send': 'Отменить отправку',
      'error_gif_send_failed': 'Не удалось отправить гифку',
      'error_no_mic_permission': 'Нет разрешения на микрофон',
      'error_record_start_failed': 'Не удалось начать запись',
      'error_too_short_recording': 'Слишком короткая запись',
      'action_private_reply_soon': 'Приватный ответ — скоро',
      'error_no_media_to_download': 'Нет медиа для скачивания',
      'error_link_fetch_failed': 'Не удалось получить ссылку',
      'media_saved_to_gallery': 'Сохранено в галерею',
      'media_download_error': 'Ошибка скачивания',
      'report_title': 'Жалоба на сообщение',
      'report_select_reason': 'Выберите причину',
      'report_spam': 'Спам',
      'report_violence': 'Насилие',
      'report_cp': 'Детская порнография',
      'report_personal': 'Личные данные',
      'report_incitement': 'Призывы к насилию',
      'report_other': 'Другое',
      'report_submitted': 'Жалоба отправлена',
      'msg_delete_title': 'Удалить сообщение',
      'msg_delete_for_everyone': 'Удалить для всех',
      'msg_delete_for_me': 'Удалить для меня',
      'chat_no_text_messages': 'В чате пока нет текстовых сообщений',
      'group_renamed': 'Группа переименована',
      'group_rename_failed': 'Не удалось переименовать',
      'call_audio': 'Аудиозвонок',
      'call_via_vibe': 'Через Vibe',
      'call_audio_soon': 'Аудиозвонок — в v2.0',
      'call_video': 'Видеозвонок',
      'call_video_soon': 'Видеозвонок — в v2.0',
      'chat_archived_snack': 'Чат в архиве',
      'chat_delete_title': 'Удалить чат?',
      'chat_delete_body': 'Чат исчезнет из вашего списка. Сообщения будут удалены.',
      'chat_kind_pm': 'Личный чат',
      'chat_kind_group': 'Группа',
      'chat_kind_channel': 'Канал',
      'chat_kind_chat': 'Чат',
      'chat_member': 'Участник',
      'chat_messages_count': 'Сообщений',
      'chat_clear_history_title': 'Очистить историю?',
      'chat_clear_history_body': 'Все сообщения этого чата будут удалены у всех участников.',
      'action_clear': 'Очистить',
      'attachment_title': 'Вложение',
      'attachment_photo': 'Фото',
      'attachment_voice': 'Голос',
      'attachment_media': 'Медиа',
      'attachment_file': 'Файл',
      'attachment_location': 'Локация',
      'attachment_contact': 'Контакт',
      'attachment_poll': 'Опрос',
      'action_pick_file': 'Выберите файл',
      'location_title': 'Локация',
      'location_latitude': 'Широта (например 55.7558)',
      'location_longitude': 'Долгота (например 37.6173)',
      'location_label': 'Подпись (необяз.)',
      'location_invalid_coords': 'Введите валидные координаты',
      'action_send': 'Отправить',
      'contact_empty': 'Контактов пока нет — добавьте их на вкладке «Контакты»',
      'poll_title': 'Опрос',
      'poll_question': 'Вопрос',
      'poll_option': 'Вариант',
      'poll_add_option': 'Добавить вариант',
      'poll_validation': 'Нужны вопрос и минимум 2 варианта',
      'action_publish': 'Опубликовать',
      'error_chat_open_failed': 'Не удалось открыть чат',
      'attachment_list_title': 'Вложения',
      'attachment_empty': 'В этом чате пока нет вложений',
      'msg_actions': 'Действия',
      'msg_reply': 'Ответить',
      'msg_reply_privately': 'Ответить приватно',
      'msg_copy': 'Копировать',
      'msg_copied': 'Скопировано',
      'msg_copy_link': 'Копировать ссылку',
      'msg_link_copied': 'Ссылка скопирована',
      'msg_show_in_chat': 'Показать в чате',
      'msg_save_to_saved': 'Сохранить в Избранное',
      'msg_forward': 'Переслать',
      'msg_select': 'Выбрать',
      'msg_download': 'Скачать',
      'msg_report': 'Пожаловаться',
      'msg_unpin': 'Открепить',
      'msg_pin': 'Закрепить',
      'msg_edit': 'Редактировать',
      'msg_edit_history': 'История правок',
      'msg_no_edits': 'Правок не найдено',
      'msg_saved_to_saved': 'Сохранено в Избранное',
      'msg_forwarded': 'Переслано',
      'msg_forward_failed': 'Не удалось переслать',
      'error_open_link_failed': 'Не удалось открыть ссылку',
      'action_undo_send': 'Отменить отправку',
      'msg_deleted': 'Удалено',
      'chat_more_pins': 'ещё',
      'chat_pinned_message': 'Закреплённое сообщение',
      'chat_pinned_messages': 'Закреплённые сообщения',
      'chat_editing': 'Редактирование',
      'chat_you': 'Вы',
      'chat_message_hint': 'Сообщение…',
      'chat_emoji_stickers': 'Эмодзи и стикеры',
      'search_result_of': 'из',
      'status_last_seen': 'был(а) в сети',
      'group_leave_title': 'Выйти из группы?',
      'group_leave_body': 'Вы перестанете получать сообщения этой группы.',
      'group_leave_confirm': 'Выйти из группы',
      'group_leave_failed': 'Не удалось выйти',
      'group_info_title': 'Инфо группы',
      'group_loading': 'Загружаем…',
      'group_member_count': 'участник(а)',
      'group_members': 'Участники',
      'group_no_members': 'Пока нет участников',
      'group_name_title': 'Название группы',
      'group_create_failed': 'Не удалось создать группу',
      'group_new': 'Новая группа',
      'group_search_hint': 'Поиск по имени или @нику',
      'group_no_contacts_to_add': 'Пока нет контактов для добавления',
      'group_select_members': 'Выберите участников',
      'group_create_with_count': 'Создать группу',
      'contact_add': 'Добавить контакт',
      'contact_title': 'Контакты',
      'contact_search_hint': 'Поиск по имени или @нику',
      'contact_empty_list': 'Пока нет контактов',
      'profile_enter_name': 'Введите имя',
      'profile_username_taken': 'Этот никнейм уже занят',
      'profile_saved_synced': 'Данные сохранены и синхронизированы',
      'profile_save_failed': 'Не удалось сохранить — проверьте соединение',
      'profile_default_name': 'Пользователь',
      'profile_edit_data': 'Изменить данные',
      'profile_info': 'Инфо о пользователе',
      'profile_info_subtitle': 'Дата рождения, город, пол',
      'profile_info_soon': 'Инфо о пользователе — скоро',
      'profile_personal_channel': 'Личный канал',
      'profile_channel_subtitle': 'Рассказывай о себе подписчикам',
      'profile_channel_soon': 'Создание канала — скоро',
      'profile_automation': 'Автоматизация чатов',
      'profile_aurion_subtitle': 'Aurion — твой AI-ассистент',
      'action_saving': 'Сохраняем…',
      'profile_avatar_removed': 'Аватар удалён',
      'profile_avatar_updated': 'Аватар обновлён · синхронизирован',
      'profile_avatar_updated_local': 'Аватар обновлён (без синхронизации)',
      'profile_setup_title': 'Твой профиль',
      'profile_setup_subtitle': 'Никнейм нужен, чтобы тебя могли найти в Vibe',
      'profile_pick_avatar': 'Выбери аватарку',
      'profile_start_chatting': 'Начать общение',
      'profile_qr_code': 'QR-код профиля',
      'profile_qr_subtitle': 'Покажи этот код — по нему найдут твой профиль',
      'action_more': 'Ещё',
      'profile_misc': 'Разное',
      'profile_other': 'Прочее',
      'profile_pick_photo': 'Выбрать фото',
      'profile_add_account': 'Добавить аккаунт',
      'profile_multi_soon': 'Мультиаккаунты появятся позже',
      'action_logout': 'Выйти',
      'profile_change_color': 'Изменить цвет профиля',
      'profile_change_name': 'Изменить имя',
      'profile_copy_link': 'Копировать ссылку',
      'profile_color_updated': 'Цвет профиля обновлён',
      'profile_name_updated': 'Имя обновлено',
      'profile_name_update_failed': 'Не удалось обновить имя',
      'profile_link_copied': 'Ссылка скопирована',
      'error_profile_save_failed': 'Ошибка сохранения профиля. Проверьте БД.',
      'aurion_suggestion1': 'Перескажи вчерашний чат по работе',
      'aurion_suggestion2': 'Перепиши позлее',
      'aurion_suggestion3': 'Сделай из этого список задач',
      'aurion_suggestion4': 'Идеи для поста в канал',
      'aurion_connect_failed': 'Не удалось подключиться: проверьте ключ доступа.',
      'aurion_unavailable': 'Aurion временно недоступен.',
      'aurion_try_asking': 'Попробуй спросить',
      'aurion_input_hint': 'Спроси Aurion…',
      'aurion_greeting': 'Привет! Я Aurion — твой персональный AI-ассистент.',
      'aurion_hero_text': 'Я могу помочь с текстами, переводом, задачами и идеями.',
      'aurion_connect_title': 'Подключите Aurion',
      'aurion_connect_body': 'Введите персональный ключ GigaChat для подключения.',
      'aurion_api_key_hint': 'API-ключ',
      'aurion_status_online': 'онлайн',
      'aurion_status_degraded': 'аварийный',
      'aurion_status_off': 'выключен',
      'aurion_answer': 'Ответ Aurion',
      'aurion_insert_to_field': 'Вставить в поле',
      'onboarding_security_text': 'Сообщения шифруются end-to-end. Никто, кроме вас и собеседника, не может их прочитать.',
      'onboarding_business_text': 'Витрина, заказы и AI-менеджер прямо в мессенджере.',
      'onboarding_economy_title': 'Своя экономика и вайб',
      'onboarding_economy_text': 'Искры, студия креатора и репутация — всё внутри.',
      'action_skip': 'Пропустить',
      'action_start': 'Начать',
      'action_next': 'Дальше',
      'profile_blocked': 'Пользователь заблокирован',
      'profile_unblocked': 'Пользователь разблокирован',
      'profile_title': 'Профиль',
      'action_message': 'Сообщение',
      'action_audio': 'Аудио',
      'action_video': 'Видео',
      'media_title': 'Медиа',
      'media_empty': 'Пока нет общих медиа',
      'action_unblock': 'Разблокировать',
      'action_block': 'Заблокировать',
      'composer_locked_hint': 'Зафиксировано — тап по кнопке: отправить',
      'composer_swipe_hint': 'Свайп вверх — зафиксировать · влево — отменить',
      'composer_locked': 'Зафиксировано',
      'composer_swipe_hint_video': 'Свайп вверх — зафиксировать · влево — отмена',
      'faq_q1': 'Как войти в Vibe?',
      'faq_q2': 'Как найти друга?',
      'faq_q3': 'Меня нет в списке чатов?',
      'faq_q4': 'Фото не синхронизируется?',
      'policy_text': 'Vibe заботится о вашей приватности. Мы не продаём данные третьим лицам.',
      'data_other': 'Другое',
      'data_video_gif': 'Видео/GIF',
      'data_photo': 'Фото',
      'data_voice': 'Голосовые',
      'data_gif': 'GIF',
      'data_bytes': 'Б',
      'data_kb': 'КБ',
      'data_mb': 'МБ',
      'data_gb': 'ГБ',
      'data_clear_cache_title': 'Очистить кэш?',
      'data_total_size': 'Общий размер:',
      'data_cache_cleared': 'Кэш очищен',
      'data_clear_failed': 'Ошибка очистки',
      'data_clear_cache': 'Очистить кэш',
      'data_mobile_desc': 'Фото, Видео (до 10 МБ)',
      'data_wifi_desc': 'Все файлы',
      'appearance_wallpaper_title': 'Обои чата',
      'appearance_none': 'Нет',
      'appearance_gradient': 'Градиент',
      'appearance_reset_title': 'Сбросить настройки?',
      'appearance_reset_body': 'Все настройки внешнего вида будут сброшены к значениям по умолчанию.',
      'appearance_reset_done': 'Настройки сброшены',
      'appearance_auto_night': 'Авто-ночь',
      'appearance_auto_night_enable': 'Включить по расписанию',
      'appearance_auto_night_start': 'Начало',
      'appearance_auto_night_end': 'Конец',
      'appearance_send_by_enter': 'Отправка по Enter',
      'appearance_send_by_enter_desc': 'Enter — отправить, Shift+Enter — перенос',
      'appearance_default': 'По умолчанию',
      'appearance_color': 'Цвет',
      'appearance_list_density': 'Плотность списка',
      'appearance_compact': 'Компактный',
      'appearance_spacious': 'Просторный',
      'appearance_medium': 'Средний',
      'appearance_reset_defaults': 'Сбросить к умолчаниям',
      'notifications_badge_and_quiet_hours': 'Badge и тихие часы',
      'notifications_badge': 'Счётчик на иконке',
      'notifications_show_badge': 'Показывать',
      'notifications_badge_hidden': 'Скрыт',
      'notifications_quiet_hours': 'Тихие часы',
      'notifications_quiet_start': 'Начало',
      'notifications_quiet_end': 'Конец',
      'support_question_hint': 'Опишите вопрос или проблему…',
      'support_question_sent': 'Вопрос отправлен команде Vibe',
      'error_save_failed': 'Не удалось сохранить',
      'msg_original_from': 'Оригинал',
      'unread_count': 'Непрочитанные',
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
      'general_settings': 'General Settings',
      'tooltip_back': 'Back',
      'tooltip_clear': 'Clear',
      'tooltip_cancel': 'Cancel',
      'tooltip_send': 'Send',
      'tooltip_search': 'Search',
      'tooltip_call': 'Call',
      'tooltip_more': 'More',
      'tooltip_next': 'Next',
      'error_server_unavailable': 'Server unavailable',
      'error_search_unavailable': 'Search unavailable — check your connection',
      'search_title': 'Search',
      'search_enter_query': 'Enter query',
      'search_messages_hint': 'Search messages',
      'search_messages_not_found': 'No messages found',
      'search_nothing_found': 'Nothing found',
      'search_hint': 'Search',
      'search_by_nick_hint': 'Search by nickname or phone...',
      'search_global_title': 'Global Search',
      'search_global_subtitle': 'Enter @nickname or phone number to find someone on Vibe.',
      'new_message_title': 'New Message',
      'new_message_subtitle': 'Start a conversation or make a call',
      'new_contact_title': 'New Contact',
      'new_contact_hint': 'Name or @username',
      'new_contact_find': 'Find',
      'new_contact_invite_friend': 'Invite a friend',
      'action_write': 'Write',
      'date_today': 'Today',
      'date_yesterday': 'Yesterday',
      'message_forwarded_from': 'Forwarded from',
      'message_edited': 'edited',
      'message_photo_to_chat': 'Photo for chat',
      'message_no_voice': 'No voice message',
      'message_location': 'Location',
      'message_open_in_maps': 'Open in Maps',
      'message_contact_default': 'Contact',
      'file_sending': 'Sending…',
      'file_saved': 'Saved: ',
      'file_download_failed': 'Failed to download file',
      'file_default_name': 'file',
      'file_unknown_size': 'Unknown',
      'poll_default_question': 'Question',
      'poll_votes_zero': '0 votes',
      'chat_status_group': 'Group',
      'status_online': 'online',
      'status_recently': 'last seen recently',
      'chat_menu_notifications': 'Notifications',
      'chat_menu_sound_off': 'Sound off',
      'chat_menu_dnd': 'Do not disturb',
      'chat_menu_media': 'Media',
      'chat_menu_search': 'Search in chat',
      'chat_menu_chat_info': 'Chat info',
      'chat_menu_archive': 'Archive',
      'chat_menu_delete_chat': 'Delete chat',
      'chat_menu_clear_history': 'Clear history',
      'chat_menu_mute_sound': 'Mute',
      'chat_menu_mute_for_a_while': 'Mute for a while',
      'chat_menu_configure': 'Configure',
      'mute_duration_1_hour': '1 hour',
      'mute_duration_8_hours': '8 hours',
      'mute_duration_1_day': '1 day',
      'mute_duration_2_days': '2 days',
      'mute_duration_1_week': '1 week',
      'composer_reply_to': 'Reply',
      'composer_cancel_reply': 'Cancel reply',
      'chat_swipe_unpin': 'Unpin',
      'chat_swipe_archive': 'Archive',
      'chat_swipe_from_archive': 'From archive',
      'chat_swipe_dnd': 'Do not disturb',
      'chat_swipe_enable_notifications': 'Enable notifications',
      'chat_draft_label': 'Draft: ',
      'chat_in_archive': 'In archive',
      'chat_new': 'New',
      'invite_text': 'Come to Vibe — my messenger. I\'m waiting for you!',
      'invite_copied': 'Invitation copied — send it to your friend',
      'folders_title': 'Folders',
      'folders_new_folder': 'New Folder',
      'folders_empty_title': 'No folders yet',
      'folders_empty_subtitle': 'Organize chats by topics: work, school, personal',
      'folders_create_folder': 'Create Folder',
      'folders_delete_folder': 'Delete Folder',
      'folders_save': 'Save',
      'folders_name_required': 'Name the folder',
      'folders_name_hint': 'Folder name',
      'folders_emoji_label': 'Folder emoji',
      'folders_no_chats': 'No chats yet — write to someone',
      'links_title': 'My Links',
      'links_profile_link': 'Profile Link',
      'links_username': 'Username',
      'links_phone': 'Phone',
      'links_copy_link': 'Copy Link',
      'links_qr_code': 'QR Code',
      'links_copied': 'Link copied',
      'recording_too_short': 'Recording too short',
      'recording_camera_unavailable': 'Camera unavailable',
      'recording_swipe_to_lock': 'Swipe up to lock',
      'two_step_create_password': 'Create a password',
      'two_step_password_description': 'This password will be required when logging in on a new device in addition to the SMS code.',
      'two_step_confirm_password': 'Confirm password',
      'two_step_hint': 'Password hint',
      'two_step_hint_description': 'You can leave a hint to help remember the password.',
      'two_step_password_too_short': 'Password too short',
      'two_step_passwords_dont_match': 'Passwords do not match',
      'two_step_enabled': 'Two-step verification enabled',
      'two_step_save_error': 'Error saving',
      'chat_screen_action_reply': 'Reply',
      'chat_screen_action_copy': 'Copy',
      'chat_screen_action_copy_link': 'Copy Link',
      'chat_screen_action_forward': 'Forward',
      'chat_screen_action_edit': 'Edit',
      'chat_screen_action_edit_history': 'Edit History',
      'chat_screen_action_delete': 'Delete',
      'chat_screen_action_pin': 'Pin',
      'chat_screen_action_unpin': 'Unpin',
      'chat_screen_input_hint': 'Message…',
      'chat_screen_copied': 'Copied',
      'chat_screen_link_copied': 'Link copied',
      'chat_screen_saved_to_gallery': 'Saved to gallery',
      'chat_screen_download_error': 'Download error',
      'chat_screen_edit_history': 'Edit History',
      'chat_screen_no_edits': 'No edits found',
      'settings_privacy_voice_messages': 'Voice Messages',
      'settings_privacy_biography': 'Biography',
      'settings_privacy_birthday': 'Birthday',
      'settings_privacy_blocked': 'Blocked Users',
      'settings_data_clear_cache_confirm': 'Clear cache?',
      'settings_data_clear_all': 'Clear All',
      'settings_data_clear_cache': 'Clear Cache',
      'settings_appearance_reset_confirm': 'Reset settings?',
      'settings_appearance_reset_description': 'All appearance settings will be reset to defaults.',
      'settings_appearance_reset': 'Reset',
      'settings_appearance_auto_night': 'Auto-Night',
      'settings_appearance_enter_to_send': 'Send by Enter',
      'settings_appearance_chat_wallpaper': 'Chat Wallpaper',
      'settings_appearance_reset_defaults': 'Reset to Defaults',
      'settings_notifications_badge_quiet_hours': 'Badge & Quiet Hours',
      'settings_notifications_quiet_hours': 'Quiet Hours',
      'profile_logout_confirm': 'Are you sure you want to log out?',
      'dialog_cancel': 'Cancel',
      'dialog_delete': 'Delete',
      'dialog_save': 'Save',
      'dialog_close': 'Close',
      'onboarding_security_title': 'Message Protection',
      'onboarding_business_title': 'Business right in chats',
      'onboarding_vibe_title': 'Your own economy and vibe',
      'gif_search_hint': 'Search GIF…',
      'story_publish_label': 'Publish',
      'story_retry_label': 'Retry',
      'story_photo_failed': 'Failed to take photo',
      'aurion_hint': 'Ask Aurion…',
      'aurion_connect': 'Connect',
      'aurion_copied': 'Copied',
      'forward_hint': 'Search',
      'profile_screen_phone': 'Phone',
      'profile_screen_username': 'Username',
      'profile_screen_my_links': 'My Links',
      'profile_screen_saved': 'Saved',
      'profile_screen_settings': 'Settings',
      'profile_screen_logout': 'Log Out',
      'profile_screen_number_copied': 'Number copied',
      'profile_screen_color_updated': 'Profile color updated',
      'profile_screen_name_updated': 'Name updated',
      'profile_screen_name_hint': 'Full name',
      'profile_screen_nick_hint': 'Username (@handle)',
      'profile_screen_bio_hint': 'About you (up to 70 characters)',
      'profile_setup_avatar_hint': 'Choose an avatar',
      'profile_setup_name_hint': 'What\'s your name?',
      'profile_setup_nick_hint': 'Nickname (e.g. alex_vibe)',
      'group_info_rename': 'Rename',
      'group_info_leave': 'Leave Group',
      'group_info_no_members': 'No members yet',
      'group_info_name_hint': 'Enter name',
      'contacts_add_soon': 'Adding contacts — coming soon',
      'contacts_load_failed': 'Failed to load contacts',
      'create_group_hint': 'Search by name or @handle',
      'create_group_load_failed': 'Failed to load contacts',
      'create_group_create_failed': 'Failed to create group',
      'chat_list_new_message': 'New Message',
      'chat_list_story_published': 'Story published, synced',
      'chat_list_story_publish_failed': 'Failed to publish story',
      'chat_list_block_tooltip': 'Block',
      'chat_list_deselect': 'Deselect',
      'chat_list_mark_read': 'Mark as read',
      'chat_list_to_archive': 'To Archive',
      'chat_list_hide_tooltip': 'Hide',
      'chat_list_delete_tooltip': 'Delete',
      'chat_list_done_tooltip': 'Done',
      'chat_list_menu_tooltip': 'Chat Menu',
      'voice_recorder_locked_hint': 'Locked — tap button to send',
      'voice_recorder_swipe_hint': 'Swipe up to lock · left to cancel',
      'video_recorder_locked_hint': 'Locked',
      'video_recorder_swipe_hint': 'Swipe up to lock · left to cancel',
      'peer_profile_message': 'Message',
      'peer_profile_audio': 'Audio',
      'peer_profile_video': 'Video',
      'settings_report_hint': 'Describe your question or problem…',
      'settings_report_sent': 'Question sent to Vibe team',
      'settings_send': 'Send',
      'settings_close': 'Close',
      'chat_pin_chat': 'Pin chat',
      'chat_unpin_chat': 'Unpin chat',
      'chat_enable_notifications': 'Enable notifications',
      'chat_do_not_disturb': 'Do not disturb',
      'chat_unarchive': 'Unarchive',
      'chat_archive_to': 'Archive',
      'chat_show_chat': 'Show chat',
      'chat_hide_chat': 'Hide chat',
      'chat_hide_subtitle': 'Hides chat from the list; access via passcode',
      'chat_mark_read': 'Mark as read',
      'chat_mark_unread': 'Mark as unread',
      'chat_reordered': 'Chat order updated',
      'msg_translate': 'Translate',
      'msg_translated': 'Translated',
      'chat_menu_export': 'Export Chat',
      'chat_export_done': 'Export ready',
      'proxy_title': 'Proxy',
      'proxy_connection': 'Connection',
      'proxy_enable': 'Enable proxy',
      'proxy_connected': 'Connected',
      'proxy_disabled': 'Disabled',
      'proxy_server': 'Server',
      'proxy_host': 'Host',
      'proxy_host_hint': 'proxy.example.com',
      'proxy_port': 'Port',
      'proxy_port_hint': '1080',
      'proxy_type': 'Type',
      'proxy_auth': 'Authentication',
      'proxy_username': 'Username',
      'proxy_username_hint': 'Optional',
      'proxy_password': 'Password',
      'proxy_password_hint': 'Optional',
      'proxy_test': 'Test connection',
      'proxy_testing': 'Testing...',
      'proxy_test_ok': 'Connection established',
      'proxy_test_fail': 'Connection failed',
      'chat_move_to_folder': 'Move to folder',
      'chat_folder_hint': 'Organize chats into your folders',
      'chat_select_chats': 'Select chats',
      'folder_all': 'All',
      'folder_personal': 'Personal',
      'folder_groups': 'Groups',
      'folder_channels': 'Channels',
      'folder_business': 'Business',
      'folder_no_folder': 'No folder',
      'folder_empty_hint': 'No folders yet — create them on the Folders screen',
      'folder_manage': 'Manage folders',
      'chat_title': 'Chats',
      'action_lock': 'Lock',
      'action_chats_menu': 'Chat menu',
      'action_clear_selection': 'Clear selection',
      'action_read': 'Read',
      'action_archive': 'Archive',
      'action_hide': 'Hide',
      'action_delete': 'Delete',
      'action_done': 'Done',
      'theme_day_mode': 'Day mode',
      'theme_night_mode': 'Night mode',
      'action_create_group': 'Create group',
      'action_saved': 'Saved',
      'greeting_night': 'Good night',
      'greeting_morning': 'Good morning',
      'greeting_day': 'Good afternoon',
      'greeting_evening': 'Good evening',
      'story_my_story': 'My story',
      'story_friend': 'Friend',
      'story_published': 'Story published · synced',
      'story_publish_failed': 'Failed to publish',
      'archive_empty': 'Archive is empty',
      'hidden_empty': 'No hidden chats',
      'chat_empty': 'No chats',
      'hidden_empty_subtitle': 'Chats you hide will appear here',
      'chat_empty_subtitle': 'Start a conversation — it\'s the quickest way to try Vibe',
      'action_new_message': 'New message',
      'archive_title': 'Archive',
      'hidden_title': 'Hidden',
      'action_back_to_chats': 'Back to chats →',
      'hidden_protection_title': 'Hidden chats protection',
      'hidden_protection_body': 'Hidden chats are protected by a passcode. Set it in Settings → Privacy.',
      'action_later': 'Later',
      'action_set': 'Set',
      'aurion_card_subtitle': 'Your built-in AI assistant',
      'profile_saved_messages': 'Saved messages',
      'chat_pinned': 'Pinned',
      'archive_subtitle': 'Chats with notifications off',
      'schedule_title': 'Schedule send',
      'schedule_in_1_hour': 'In 1 hour',
      'schedule_tomorrow_9am': 'Tomorrow at 09:00',
      'schedule_pick_datetime': 'Pick date and time…',
      'schedule_scheduled': 'Scheduled for',
      'schedule_list_title': 'Scheduled messages',
      'schedule_cancelled': 'Send cancelled',
      'schedule_cancel_send': 'Cancel send',
      'error_gif_send_failed': 'Failed to send GIF',
      'error_no_mic_permission': 'No microphone permission',
      'error_record_start_failed': 'Failed to start recording',
      'error_too_short_recording': 'Recording too short',
      'action_private_reply_soon': 'Private reply — coming soon',
      'error_no_media_to_download': 'No media to download',
      'error_link_fetch_failed': 'Failed to fetch link',
      'media_saved_to_gallery': 'Saved to gallery',
      'media_download_error': 'Download error',
      'report_title': 'Report message',
      'report_select_reason': 'Select a reason',
      'report_spam': 'Spam',
      'report_violence': 'Violence',
      'report_cp': 'Child pornography',
      'report_personal': 'Personal data',
      'report_incitement': 'Incitement to violence',
      'report_other': 'Other',
      'report_submitted': 'Report submitted',
      'msg_delete_title': 'Delete message',
      'msg_delete_for_everyone': 'Delete for everyone',
      'msg_delete_for_me': 'Delete for me',
      'chat_no_text_messages': 'No text messages in this chat yet',
      'group_renamed': 'Group renamed',
      'group_rename_failed': 'Failed to rename',
      'call_audio': 'Audio call',
      'call_via_vibe': 'Via Vibe',
      'call_audio_soon': 'Audio call — in v2.0',
      'call_video': 'Video call',
      'call_video_soon': 'Video call — in v2.0',
      'chat_archived_snack': 'Chat archived',
      'chat_delete_title': 'Delete chat?',
      'chat_delete_body': 'The chat will be removed from your list. Messages will be deleted.',
      'chat_kind_pm': 'Private chat',
      'chat_kind_group': 'Group',
      'chat_kind_channel': 'Channel',
      'chat_kind_chat': 'Chat',
      'chat_member': 'Member',
      'chat_messages_count': 'Messages',
      'chat_clear_history_title': 'Clear history?',
      'chat_clear_history_body': 'All messages in this chat will be deleted for all members.',
      'action_clear': 'Clear',
      'attachment_title': 'Attachment',
      'attachment_photo': 'Photo',
      'attachment_voice': 'Voice',
      'attachment_media': 'Media',
      'attachment_file': 'File',
      'attachment_location': 'Location',
      'attachment_contact': 'Contact',
      'attachment_poll': 'Poll',
      'action_pick_file': 'Pick a file',
      'location_title': 'Location',
      'location_latitude': 'Latitude (e.g. 55.7558)',
      'location_longitude': 'Longitude (e.g. 37.6173)',
      'location_label': 'Caption (optional)',
      'location_invalid_coords': 'Enter valid coordinates',
      'action_send': 'Send',
      'contact_empty': 'No contacts yet — add them on the Contacts tab',
      'poll_title': 'Poll',
      'poll_question': 'Question',
      'poll_option': 'Option',
      'poll_add_option': 'Add option',
      'poll_validation': 'Need a question and at least 2 options',
      'action_publish': 'Publish',
      'error_chat_open_failed': 'Failed to open chat',
      'attachment_list_title': 'Attachments',
      'attachment_empty': 'No attachments in this chat yet',
      'msg_actions': 'Actions',
      'msg_reply': 'Reply',
      'msg_reply_privately': 'Reply privately',
      'msg_copy': 'Copy',
      'msg_copied': 'Copied',
      'msg_copy_link': 'Copy link',
      'msg_link_copied': 'Link copied',
      'msg_show_in_chat': 'Show in chat',
      'msg_save_to_saved': 'Save to Saved',
      'msg_forward': 'Forward',
      'msg_select': 'Select',
      'msg_download': 'Download',
      'msg_report': 'Report',
      'msg_unpin': 'Unpin',
      'msg_pin': 'Pin',
      'msg_edit': 'Edit',
      'msg_edit_history': 'Edit history',
      'msg_no_edits': 'No edits found',
      'msg_saved_to_saved': 'Saved to Saved',
      'msg_forwarded': 'Forwarded',
      'msg_forward_failed': 'Failed to forward',
      'error_open_link_failed': 'Failed to open link',
      'action_undo_send': 'Undo send',
      'msg_deleted': 'Deleted',
      'chat_more_pins': 'more',
      'chat_pinned_message': 'Pinned message',
      'chat_pinned_messages': 'Pinned messages',
      'chat_editing': 'Editing',
      'chat_you': 'You',
      'chat_message_hint': 'Message…',
      'chat_emoji_stickers': 'Emoji & stickers',
      'search_result_of': 'of',
      'status_last_seen': 'last seen',
      'group_leave_title': 'Leave group?',
      'group_leave_body': 'You will stop receiving messages from this group.',
      'group_leave_confirm': 'Leave group',
      'group_leave_failed': 'Failed to leave',
      'group_info_title': 'Group info',
      'group_loading': 'Loading…',
      'group_member_count': 'member(s)',
      'group_members': 'Members',
      'group_no_members': 'No members yet',
      'group_name_title': 'Group name',
      'group_create_failed': 'Failed to create group',
      'group_new': 'New group',
      'group_search_hint': 'Search by name or @handle',
      'group_no_contacts_to_add': 'No contacts to add yet',
      'group_select_members': 'Select members',
      'group_create_with_count': 'Create group',
      'contact_add': 'Add contact',
      'contact_title': 'Contacts',
      'contact_search_hint': 'Search by name or @handle',
      'contact_empty_list': 'No contacts yet',
      'profile_enter_name': 'Enter name',
      'profile_username_taken': 'This username is already taken',
      'profile_saved_synced': 'Data saved and synced',
      'profile_save_failed': 'Failed to save — check your connection',
      'profile_default_name': 'User',
      'profile_edit_data': 'Edit data',
      'profile_info': 'User info',
      'profile_info_subtitle': 'Birthday, city, gender',
      'profile_info_soon': 'User info — coming soon',
      'profile_personal_channel': 'Personal channel',
      'profile_channel_subtitle': 'Tell your subscribers about yourself',
      'profile_channel_soon': 'Channel creation — coming soon',
      'profile_automation': 'Chat automation',
      'profile_aurion_subtitle': 'Aurion — your AI assistant',
      'action_saving': 'Saving…',
      'profile_avatar_removed': 'Avatar removed',
      'profile_avatar_updated': 'Avatar updated · synced',
      'profile_avatar_updated_local': 'Avatar updated (no sync)',
      'profile_setup_title': 'Your profile',
      'profile_setup_subtitle': 'A username helps others find you on Vibe',
      'profile_pick_avatar': 'Choose an avatar',
      'profile_start_chatting': 'Start chatting',
      'profile_qr_code': 'Profile QR code',
      'profile_qr_subtitle': 'Show this code — people can find your profile with it',
      'action_more': 'More',
      'profile_misc': 'Misc',
      'profile_other': 'Other',
      'profile_pick_photo': 'Pick a photo',
      'profile_add_account': 'Add account',
      'profile_multi_soon': 'Multi-account coming later',
      'action_logout': 'Log out',
      'profile_change_color': 'Change profile color',
      'profile_change_name': 'Change name',
      'profile_copy_link': 'Copy link',
      'profile_color_updated': 'Profile color updated',
      'profile_name_updated': 'Name updated',
      'profile_name_update_failed': 'Failed to update name',
      'profile_link_copied': 'Link copied',
      'error_profile_save_failed': 'Profile save error. Check the database.',
      'aurion_suggestion1': 'Summarize yesterday\'s work chat',
      'aurion_suggestion2': 'Rewrite it in a more assertive tone',
      'aurion_suggestion3': 'Turn this into a to-do list',
      'aurion_suggestion4': 'Ideas for a channel post',
      'aurion_connect_failed': 'Failed to connect: check your access key.',
      'aurion_unavailable': 'Aurion is temporarily unavailable.',
      'aurion_try_asking': 'Try asking',
      'aurion_input_hint': 'Ask Aurion…',
      'aurion_greeting': 'Hi! I\'m Aurion — your personal AI assistant.',
      'aurion_hero_text': 'I can help with texts, translation, tasks, and ideas.',
      'aurion_connect_title': 'Connect Aurion',
      'aurion_connect_body': 'Enter your personal GigaChat access key to connect.',
      'aurion_api_key_hint': 'API key',
      'aurion_status_online': 'online',
      'aurion_status_degraded': 'degraded',
      'aurion_status_off': 'off',
      'aurion_answer': 'Aurion answer',
      'aurion_insert_to_field': 'Insert into field',
      'onboarding_security_text': 'Messages are end-to-end encrypted. No one but you and the recipient can read them.',
      'onboarding_business_text': 'Storefront, orders, and AI manager right in the messenger.',
      'onboarding_economy_title': 'Your own economy and vibe',
      'onboarding_economy_text': 'Sparks, creator studio, and reputation — all inside.',
      'action_skip': 'Skip',
      'action_start': 'Start',
      'action_next': 'Next',
      'profile_blocked': 'User blocked',
      'profile_unblocked': 'User unblocked',
      'profile_title': 'Profile',
      'action_message': 'Message',
      'action_audio': 'Audio',
      'action_video': 'Video',
      'media_title': 'Media',
      'media_empty': 'No shared media yet',
      'action_unblock': 'Unblock',
      'action_block': 'Block',
      'composer_locked_hint': 'Locked — tap button to send',
      'composer_swipe_hint': 'Swipe up to lock · left to cancel',
      'composer_locked': 'Locked',
      'composer_swipe_hint_video': 'Swipe up to lock · left to cancel',
      'faq_q1': 'How to sign in to Vibe?',
      'faq_q2': 'How to find a friend?',
      'faq_q3': 'I\'m not in the chat list?',
      'faq_q4': 'Photo not syncing?',
      'policy_text': 'Vibe cares about your privacy. We do not sell data to third parties.',
      'data_other': 'Other',
      'data_video_gif': 'Video/GIF',
      'data_photo': 'Photos',
      'data_voice': 'Voice',
      'data_gif': 'GIF',
      'data_bytes': 'B',
      'data_kb': 'KB',
      'data_mb': 'MB',
      'data_gb': 'GB',
      'data_clear_cache_title': 'Clear cache?',
      'data_total_size': 'Total size:',
      'data_cache_cleared': 'Cache cleared',
      'data_clear_failed': 'Clear failed',
      'data_clear_cache': 'Clear cache',
      'data_mobile_desc': 'Photos, Videos (up to 10 MB)',
      'data_wifi_desc': 'All files',
      'appearance_wallpaper_title': 'Chat wallpaper',
      'appearance_none': 'None',
      'appearance_gradient': 'Gradient',
      'appearance_reset_title': 'Reset settings?',
      'appearance_reset_body': 'All appearance settings will be reset to defaults.',
      'appearance_reset_done': 'Settings reset',
      'appearance_auto_night': 'Auto-Night',
      'appearance_auto_night_enable': 'Enable on schedule',
      'appearance_auto_night_start': 'Start',
      'appearance_auto_night_end': 'End',
      'appearance_send_by_enter': 'Send by Enter',
      'appearance_send_by_enter_desc': 'Enter — send, Shift+Enter — new line',
      'appearance_default': 'Default',
      'appearance_color': 'Color',
      'appearance_list_density': 'List density',
      'appearance_compact': 'Compact',
      'appearance_spacious': 'Spacious',
      'appearance_medium': 'Medium',
      'appearance_reset_defaults': 'Reset to defaults',
      'notifications_badge_and_quiet_hours': 'Badge & Quiet Hours',
      'notifications_badge': 'Badge on icon',
      'notifications_show_badge': 'Show',
      'notifications_badge_hidden': 'Hidden',
      'notifications_quiet_hours': 'Quiet Hours',
      'notifications_quiet_start': 'Start',
      'notifications_quiet_end': 'End',
      'support_question_hint': 'Describe your question or problem…',
      'support_question_sent': 'Question sent to the Vibe team',
      'error_save_failed': 'Failed to save',
      'msg_original_from': 'Original',
      'unread_count': 'Unread',
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
  String get generalSettings => _get('general_settings');
  String get tooltipBack => _get('tooltip_back');
  String get tooltipClear => _get('tooltip_clear');
  String get tooltipCancel => _get('tooltip_cancel');
  String get tooltipSend => _get('tooltip_send');
  String get tooltipSearch => _get('tooltip_search');
  String get tooltipCall => _get('tooltip_call');
  String get tooltipMore => _get('tooltip_more');
  String get tooltipNext => _get('tooltip_next');
  String get errorServerUnavailable => _get('error_server_unavailable');
  String get errorSearchUnavailable => _get('error_search_unavailable');
  String get searchTitle => _get('search_title');
  String get searchEnterQuery => _get('search_enter_query');
  String get searchMessagesHint => _get('search_messages_hint');
  String get searchMessagesNotFound => _get('search_messages_not_found');
  String get searchNothingFound => _get('search_nothing_found');
  String get searchHint => _get('search_hint');
  String get searchByNickHint => _get('search_by_nick_hint');
  String get searchGlobalTitle => _get('search_global_title');
  String get searchGlobalSubtitle => _get('search_global_subtitle');
  String get newMessageTitle => _get('new_message_title');
  String get newMessageSubtitle => _get('new_message_subtitle');
  String get newContactTitle => _get('new_contact_title');
  String get newContactHint => _get('new_contact_hint');
  String get newContactFind => _get('new_contact_find');
  String get newContactInviteFriend => _get('new_contact_invite_friend');
  String get actionWrite => _get('action_write');
  String get dateToday => _get('date_today');
  String get dateYesterday => _get('date_yesterday');
  String messageForwardedFrom(String name) => '${_get('message_forwarded_from')} $name';
  String get messageEdited => _get('message_edited');
  String get messagePhotoToChat => _get('message_photo_to_chat');
  String get messageNoVoice => _get('message_no_voice');
  String get messageLocation => _get('message_location');
  String get messageOpenInMaps => _get('message_open_in_maps');
  String get messageContactDefault => _get('message_contact_default');
  String get fileSending => _get('file_sending');
  String fileSaved(String name) => '${_get('file_saved')}$name';
  String get fileDownloadFailed => _get('file_download_failed');
  String get fileDefaultName => _get('file_default_name');
  String get fileUnknownSize => _get('file_unknown_size');
  String get pollDefaultQuestion => _get('poll_default_question');
  String get pollVotesZero => _get('poll_votes_zero');
  String get chatStatusGroup => _get('chat_status_group');
  String get statusOnline => _get('status_online');
  String get statusRecently => _get('status_recently');
  String get chatMenuNotifications => _get('chat_menu_notifications');
  String get chatMenuSoundOff => _get('chat_menu_sound_off');
  String get chatMenuDnd => _get('chat_menu_dnd');
  String get chatMenuMedia => _get('chat_menu_media');
  String get chatMenuSearch => _get('chat_menu_search');
  String get chatMenuChatInfo => _get('chat_menu_chat_info');
  String get chatMenuArchive => _get('chat_menu_archive');
  String get chatMenuDeleteChat => _get('chat_menu_delete_chat');
  String get chatMenuClearHistory => _get('chat_menu_clear_history');
  String get chatMenuMuteSound => _get('chat_menu_mute_sound');
  String get chatMenuMuteForAWhile => _get('chat_menu_mute_for_a_while');
  String get chatMenuConfigure => _get('chat_menu_configure');
  String get muteDuration1Hour => _get('mute_duration_1_hour');
  String get muteDuration8Hours => _get('mute_duration_8_hours');
  String get muteDuration1Day => _get('mute_duration_1_day');
  String get muteDuration2Days => _get('mute_duration_2_days');
  String get muteDuration1Week => _get('mute_duration_1_week');
  String composerReplyTo(String author) => '${_get('composer_reply_to')} $author';
  String get composerCancelReply => _get('composer_cancel_reply');
  String get chatSwipeUnpin => _get('chat_swipe_unpin');
  String get chatSwipeArchive => _get('chat_swipe_archive');
  String get chatSwipeFromArchive => _get('chat_swipe_from_archive');
  String get chatSwipeDnd => _get('chat_swipe_dnd');
  String get chatSwipeEnableNotifications => _get('chat_swipe_enable_notifications');
  String get chatDraftLabel => _get('chat_draft_label');
  String get chatInArchive => _get('chat_in_archive');
  String get chatNew => _get('chat_new');
  String get inviteText => _get('invite_text');
  String get inviteCopied => _get('invite_copied');
  String get foldersTitle => _get('folders_title');
  String get foldersNewFolder => _get('folders_new_folder');
  String get foldersEmptyTitle => _get('folders_empty_title');
  String get foldersEmptySubtitle => _get('folders_empty_subtitle');
  String get foldersCreateFolder => _get('folders_create_folder');
  String get foldersDeleteFolder => _get('folders_delete_folder');
  String get foldersSave => _get('folders_save');
  String get foldersNameRequired => _get('folders_name_required');
  String get foldersNameHint => _get('folders_name_hint');
  String get foldersEmojiLabel => _get('folders_emoji_label');
  String get foldersNoChats => _get('folders_no_chats');
  String get linksTitle => _get('links_title');
  String get linksProfileLink => _get('links_profile_link');
  String get linksUsername => _get('links_username');
  String get linksPhone => _get('links_phone');
  String get linksCopyLink => _get('links_copy_link');
  String get linksQrCode => _get('links_qr_code');
  String get linksCopied => _get('links_copied');
  String get recordingTooShort => _get('recording_too_short');
  String get recordingCameraUnavailable => _get('recording_camera_unavailable');
  String get recordingSwipeToLock => _get('recording_swipe_to_lock');
  String get twoStepCreatePassword => _get('two_step_create_password');
  String get twoStepPasswordDescription => _get('two_step_password_description');
  String get twoStepConfirmPassword => _get('two_step_confirm_password');
  String get twoStepHint => _get('two_step_hint');
  String get twoStepHintDescription => _get('two_step_hint_description');
  String get twoStepPasswordTooShort => _get('two_step_password_too_short');
  String get twoStepPasswordsDontMatch => _get('two_step_passwords_dont_match');
  String get twoStepEnabled => _get('two_step_enabled');
  String get twoStepSaveError => _get('two_step_save_error');
  String get chatScreenActionReply => _get('chat_screen_action_reply');
  String get chatScreenActionCopy => _get('chat_screen_action_copy');
  String get chatScreenActionCopyLink => _get('chat_screen_action_copy_link');
  String get chatScreenActionForward => _get('chat_screen_action_forward');
  String get chatScreenActionEdit => _get('chat_screen_action_edit');
  String get chatScreenActionEditHistory => _get('chat_screen_action_edit_history');
  String get chatScreenActionDelete => _get('chat_screen_action_delete');
  String get chatScreenActionPin => _get('chat_screen_action_pin');
  String get chatScreenActionUnpin => _get('chat_screen_action_unpin');
  String get chatScreenInputHint => _get('chat_screen_input_hint');
  String get chatScreenCopied => _get('chat_screen_copied');
  String get chatScreenLinkCopied => _get('chat_screen_link_copied');
  String get chatScreenSavedToGallery => _get('chat_screen_saved_to_gallery');
  String get chatScreenDownloadError => _get('chat_screen_download_error');
  String get chatScreenEditHistory => _get('chat_screen_edit_history');
  String get chatScreenNoEdits => _get('chat_screen_no_edits');
  String get settingsPrivacyVoiceMessages => _get('settings_privacy_voice_messages');
  String get settingsPrivacyBiography => _get('settings_privacy_biography');
  String get settingsPrivacyBirthday => _get('settings_privacy_birthday');
  String get settingsPrivacyBlocked => _get('settings_privacy_blocked');
  String get settingsDataClearCacheConfirm => _get('settings_data_clear_cache_confirm');
  String get settingsDataClearAll => _get('settings_data_clear_all');
  String get settingsDataClearCache => _get('settings_data_clear_cache');
  String get settingsAppearanceResetConfirm => _get('settings_appearance_reset_confirm');
  String get settingsAppearanceResetDescription => _get('settings_appearance_reset_description');
  String get settingsAppearanceReset => _get('settings_appearance_reset');
  String get settingsAppearanceAutoNight => _get('settings_appearance_auto_night');
  String get settingsAppearanceEnterToSend => _get('settings_appearance_enter_to_send');
  String get settingsAppearanceChatWallpaper => _get('settings_appearance_chat_wallpaper');
  String get settingsAppearanceResetDefaults => _get('settings_appearance_reset_defaults');
  String get settingsNotificationsBadgeQuietHours => _get('settings_notifications_badge_quiet_hours');
  String get settingsNotificationsQuietHours => _get('settings_notifications_quiet_hours');
  String get profileLogoutConfirm => _get('profile_logout_confirm');
  String get dialogCancel => _get('dialog_cancel');
  String get dialogDelete => _get('dialog_delete');
  String get dialogSave => _get('dialog_save');
  String get dialogClose => _get('dialog_close');
  String get onboardingSecurityTitle => _get('onboarding_security_title');
  String get onboardingBusinessTitle => _get('onboarding_business_title');
  String get onboardingVibeTitle => _get('onboarding_vibe_title');
  String get gifSearchHint => _get('gif_search_hint');
  String get storyPublishLabel => _get('story_publish_label');
  String get storyRetryLabel => _get('story_retry_label');
  String get storyPhotoFailed => _get('story_photo_failed');
  String get aurionHint => _get('aurion_hint');
  String get aurionConnect => _get('aurion_connect');
  String get aurionCopied => _get('aurion_copied');
  String get forwardHint => _get('forward_hint');
  String get profileScreenPhone => _get('profile_screen_phone');
  String get profileScreenUsername => _get('profile_screen_username');
  String get profileScreenMyLinks => _get('profile_screen_my_links');
  String get profileScreenSaved => _get('profile_screen_saved');
  String get profileScreenSettings => _get('profile_screen_settings');
  String get profileScreenLogout => _get('profile_screen_logout');
  String get profileScreenNumberCopied => _get('profile_screen_number_copied');
  String get profileScreenColorUpdated => _get('profile_screen_color_updated');
  String get profileScreenNameUpdated => _get('profile_screen_name_updated');
  String get profileScreenNameHint => _get('profile_screen_name_hint');
  String get profileScreenNickHint => _get('profile_screen_nick_hint');
  String get profileScreenBioHint => _get('profile_screen_bio_hint');
  String get profileSetupAvatarHint => _get('profile_setup_avatar_hint');
  String get profileSetupNameHint => _get('profile_setup_name_hint');
  String get profileSetupNickHint => _get('profile_setup_nick_hint');
  String get groupInfoRename => _get('group_info_rename');
  String get groupInfoLeave => _get('group_info_leave');
  String get groupInfoNoMembers => _get('group_info_no_members');
  String get groupInfoNameHint => _get('group_info_name_hint');
  String get contactsAddSoon => _get('contacts_add_soon');
  String get contactsLoadFailed => _get('contacts_load_failed');
  String get createGroupHint => _get('create_group_hint');
  String get createGroupLoadFailed => _get('create_group_load_failed');
  String get createGroupCreateFailed => _get('create_group_create_failed');
  String get chatListNewMessage => _get('chat_list_new_message');
  String get chatListStoryPublished => _get('chat_list_story_published');
  String get chatListStoryPublishFailed => _get('chat_list_story_publish_failed');
  String get chatListBlockTooltip => _get('chat_list_block_tooltip');
  String get chatListDeselect => _get('chat_list_deselect');
  String get chatListMarkRead => _get('chat_list_mark_read');
  String get chatListToArchive => _get('chat_list_to_archive');
  String get chatListHideTooltip => _get('chat_list_hide_tooltip');
  String get chatListDeleteTooltip => _get('chat_list_delete_tooltip');
  String get chatListDoneTooltip => _get('chat_list_done_tooltip');
  String get chatListMenuTooltip => _get('chat_list_menu_tooltip');
  String get voiceRecorderLockedHint => _get('voice_recorder_locked_hint');
  String get voiceRecorderSwipeHint => _get('voice_recorder_swipe_hint');
  String get videoRecorderLockedHint => _get('video_recorder_locked_hint');
  String get videoRecorderSwipeHint => _get('video_recorder_swipe_hint');
  String get peerProfileMessage => _get('peer_profile_message');
  String get peerProfileAudio => _get('peer_profile_audio');
  String get peerProfileVideo => _get('peer_profile_video');
  String get settingsReportHint => _get('settings_report_hint');
  String get settingsReportSent => _get('settings_report_sent');
  String get settingsSend => _get('settings_send');
  String get settingsClose => _get('settings_close');
  String get chatPinChat => _get('chat_pin_chat');
  String get chatUnpinChat => _get('chat_unpin_chat');
  String get chatEnableNotifications => _get('chat_enable_notifications');
  String get chatDoNotDisturb => _get('chat_do_not_disturb');
  String get chatUnarchive => _get('chat_unarchive');
  String get chatArchiveTo => _get('chat_archive_to');
  String get chatShowChat => _get('chat_show_chat');
  String get chatHideChat => _get('chat_hide_chat');
  String get chatHideSubtitle => _get('chat_hide_subtitle');
  String get chatMarkRead => _get('chat_mark_read');
  String get chatMarkUnread => _get('chat_mark_unread');
  String get chatReordered => _get('chat_reordered');
  String get msgTranslate => _get('msg_translate');
  String get msgTranslated => _get('msg_translated');
  String get chatMenuExport => _get('chat_menu_export');
  String get chatExportDone => _get('chat_export_done');
  String get proxyTitle => _get('proxy_title');
  String get proxyConnection => _get('proxy_connection');
  String get proxyEnable => _get('proxy_enable');
  String get proxyConnected => _get('proxy_connected');
  String get proxyDisabled => _get('proxy_disabled');
  String get proxyServer => _get('proxy_server');
  String get proxyHost => _get('proxy_host');
  String get proxyHostHint => _get('proxy_host_hint');
  String get proxyPort => _get('proxy_port');
  String get proxyPortHint => _get('proxy_port_hint');
  String get proxyType => _get('proxy_type');
  String get proxyAuth => _get('proxy_auth');
  String get proxyUsername => _get('proxy_username');
  String get proxyUsernameHint => _get('proxy_username_hint');
  String get proxyPassword => _get('proxy_password');
  String get proxyPasswordHint => _get('proxy_password_hint');
  String get proxyTest => _get('proxy_test');
  String get proxyTesting => _get('proxy_testing');
  String get proxyTestOk => _get('proxy_test_ok');
  String get proxyTestFail => _get('proxy_test_fail');
  String get chatMoveToFolder => _get('chat_move_to_folder');
  String get chatFolderHint => _get('chat_folder_hint');
  String get chatSelectChats => _get('chat_select_chats');
  String get folderAll => _get('folder_all');
  String get folderPersonal => _get('folder_personal');
  String get folderGroups => _get('folder_groups');
  String get folderChannels => _get('folder_channels');
  String get folderBusiness => _get('folder_business');
  String get folderNoFolder => _get('folder_no_folder');
  String get folderEmptyHint => _get('folder_empty_hint');
  String get folderManage => _get('folder_manage');
  String get chatTitle => _get('chat_title');
  String get actionLock => _get('action_lock');
  String get actionChatsMenu => _get('action_chats_menu');
  String get actionClearSelection => _get('action_clear_selection');
  String get actionRead => _get('action_read');
  String get actionArchive => _get('action_archive');
  String get actionHide => _get('action_hide');
  String get actionDelete => _get('action_delete');
  String get actionDone => _get('action_done');
  String get themeDayMode => _get('theme_day_mode');
  String get themeNightMode => _get('theme_night_mode');
  String get actionCreateGroup => _get('action_create_group');
  String get actionSaved => _get('action_saved');
  String get greetingNight => _get('greeting_night');
  String get greetingMorning => _get('greeting_morning');
  String get greetingDay => _get('greeting_day');
  String get greetingEvening => _get('greeting_evening');
  String get storyMyStory => _get('story_my_story');
  String get storyFriend => _get('story_friend');
  String get storyPublished => _get('story_published');
  String get storyPublishFailed => _get('story_publish_failed');
  String get archiveEmpty => _get('archive_empty');
  String get hiddenEmpty => _get('hidden_empty');
  String get chatEmpty => _get('chat_empty');
  String get hiddenEmptySubtitle => _get('hidden_empty_subtitle');
  String get chatEmptySubtitle => _get('chat_empty_subtitle');
  String get actionNewMessage => _get('action_new_message');
  String get archiveTitle => _get('archive_title');
  String get hiddenTitle => _get('hidden_title');
  String get actionBackToChats => _get('action_back_to_chats');
  String get hiddenProtectionTitle => _get('hidden_protection_title');
  String get hiddenProtectionBody => _get('hidden_protection_body');
  String get actionLater => _get('action_later');
  String get actionSet => _get('action_set');
  String get aurionCardSubtitle => _get('aurion_card_subtitle');
  String get profileSavedMessages => _get('profile_saved_messages');
  String get chatPinned => _get('chat_pinned');
  String get archiveSubtitle => _get('archive_subtitle');
  String get scheduleTitle => _get('schedule_title');
  String get scheduleIn1Hour => _get('schedule_in_1_hour');
  String get scheduleTomorrow9am => _get('schedule_tomorrow_9am');
  String get schedulePickDatetime => _get('schedule_pick_datetime');
  String get scheduleScheduled => _get('schedule_scheduled');
  String get scheduleListTitle => _get('schedule_list_title');
  String get scheduleCancelled => _get('schedule_cancelled');
  String get scheduleCancelSend => _get('schedule_cancel_send');
  String get errorGifSendFailed => _get('error_gif_send_failed');
  String get errorNoMicPermission => _get('error_no_mic_permission');
  String get errorRecordStartFailed => _get('error_record_start_failed');
  String get errorTooShortRecording => _get('error_too_short_recording');
  String get actionPrivateReplySoon => _get('action_private_reply_soon');
  String get errorNoMediaToDownload => _get('error_no_media_to_download');
  String get errorLinkFetchFailed => _get('error_link_fetch_failed');
  String get mediaSavedToGallery => _get('media_saved_to_gallery');
  String get mediaDownloadError => _get('media_download_error');
  String get reportTitle => _get('report_title');
  String get reportSelectReason => _get('report_select_reason');
  String get reportSpam => _get('report_spam');
  String get reportViolence => _get('report_violence');
  String get reportCp => _get('report_cp');
  String get reportPersonal => _get('report_personal');
  String get reportIncitement => _get('report_incitement');
  String get reportOther => _get('report_other');
  String get reportSubmitted => _get('report_submitted');
  String get msgDeleteTitle => _get('msg_delete_title');
  String get msgDeleteForEveryone => _get('msg_delete_for_everyone');
  String get msgDeleteForMe => _get('msg_delete_for_me');
  String get chatNoTextMessages => _get('chat_no_text_messages');
  String get groupRenamed => _get('group_renamed');
  String get groupRenameFailed => _get('group_rename_failed');
  String get callAudio => _get('call_audio');
  String get callViaVibe => _get('call_via_vibe');
  String get callAudioSoon => _get('call_audio_soon');
  String get callVideo => _get('call_video');
  String get callVideoSoon => _get('call_video_soon');
  String get chatArchivedSnack => _get('chat_archived_snack');
  String get chatDeleteTitle => _get('chat_delete_title');
  String get chatDeleteBody => _get('chat_delete_body');
  String get chatKindPm => _get('chat_kind_pm');
  String get chatKindGroup => _get('chat_kind_group');
  String get chatKindChannel => _get('chat_kind_channel');
  String get chatKindChat => _get('chat_kind_chat');
  String get chatMember => _get('chat_member');
  String get chatMessagesCount => _get('chat_messages_count');
  String get chatClearHistoryTitle => _get('chat_clear_history_title');
  String get chatClearHistoryBody => _get('chat_clear_history_body');
  String get actionClear => _get('action_clear');
  String get attachmentTitle => _get('attachment_title');
  String get attachmentPhoto => _get('attachment_photo');
  String get attachmentVoice => _get('attachment_voice');
  String get attachmentMedia => _get('attachment_media');
  String get attachmentFile => _get('attachment_file');
  String get attachmentLocation => _get('attachment_location');
  String get attachmentContact => _get('attachment_contact');
  String get attachmentPoll => _get('attachment_poll');
  String get actionPickFile => _get('action_pick_file');
  String get locationTitle => _get('location_title');
  String get locationLatitude => _get('location_latitude');
  String get locationLongitude => _get('location_longitude');
  String get locationLabel => _get('location_label');
  String get locationInvalidCoords => _get('location_invalid_coords');
  String get actionSend => _get('action_send');
  String get contactEmpty => _get('contact_empty');
  String get pollTitle => _get('poll_title');
  String get pollQuestion => _get('poll_question');
  String get pollOption => _get('poll_option');
  String get pollAddOption => _get('poll_add_option');
  String get pollValidation => _get('poll_validation');
  String get actionPublish => _get('action_publish');
  String get errorChatOpenFailed => _get('error_chat_open_failed');
  String get attachmentListTitle => _get('attachment_list_title');
  String get attachmentEmpty => _get('attachment_empty');
  String get msgActions => _get('msg_actions');
  String get msgReply => _get('msg_reply');
  String get msgReplyPrivately => _get('msg_reply_privately');
  String get msgCopy => _get('msg_copy');
  String get msgCopied => _get('msg_copied');
  String get msgCopyLink => _get('msg_copy_link');
  String get msgLinkCopied => _get('msg_link_copied');
  String get msgShowInChat => _get('msg_show_in_chat');
  String get msgSaveToSaved => _get('msg_save_to_saved');
  String get msgForward => _get('msg_forward');
  String get msgSelect => _get('msg_select');
  String get msgDownload => _get('msg_download');
  String get msgReport => _get('msg_report');
  String get msgUnpin => _get('msg_unpin');
  String get msgPin => _get('msg_pin');
  String get msgEdit => _get('msg_edit');
  String get msgEditHistory => _get('msg_edit_history');
  String get msgNoEdits => _get('msg_no_edits');
  String get msgSavedToSaved => _get('msg_saved_to_saved');
  String get msgForwarded => _get('msg_forwarded');
  String get msgForwardFailed => _get('msg_forward_failed');
  String get errorOpenLinkFailed => _get('error_open_link_failed');
  String get actionUndoSend => _get('action_undo_send');
  String get msgDeleted => _get('msg_deleted');
  String get chatMorePins => _get('chat_more_pins');
  String get chatPinnedMessage => _get('chat_pinned_message');
  String get chatPinnedMessages => _get('chat_pinned_messages');
  String get chatEditing => _get('chat_editing');
  String get chatYou => _get('chat_you');
  String get chatMessageHint => _get('chat_message_hint');
  String get chatEmojiStickers => _get('chat_emoji_stickers');
  String get searchResultOf => _get('search_result_of');
  String get statusLastSeen => _get('status_last_seen');
  String get groupLeaveTitle => _get('group_leave_title');
  String get groupLeaveBody => _get('group_leave_body');
  String get groupLeaveConfirm => _get('group_leave_confirm');
  String get groupLeaveFailed => _get('group_leave_failed');
  String get groupInfoTitle => _get('group_info_title');
  String get groupLoading => _get('group_loading');
  String get groupMemberCount => _get('group_member_count');
  String get groupMembers => _get('group_members');
  String get groupNoMembers => _get('group_no_members');
  String get groupNameTitle => _get('group_name_title');
  String get groupCreateFailed => _get('group_create_failed');
  String get groupNew => _get('group_new');
  String get groupSearchHint => _get('group_search_hint');
  String get groupNoContactsToAdd => _get('group_no_contacts_to_add');
  String get groupSelectMembers => _get('group_select_members');
  String get groupCreateWithCount => _get('group_create_with_count');
  String get contactAdd => _get('contact_add');
  String get contactTitle => _get('contact_title');
  String get contactSearchHint => _get('contact_search_hint');
  String get contactEmptyList => _get('contact_empty_list');
  String get profileEnterName => _get('profile_enter_name');
  String get profileUsernameTaken => _get('profile_username_taken');
  String get profileSavedSynced => _get('profile_saved_synced');
  String get profileSaveFailed => _get('profile_save_failed');
  String get profileDefaultName => _get('profile_default_name');
  String get profileEditData => _get('profile_edit_data');
  String get profileInfo => _get('profile_info');
  String get profileInfoSubtitle => _get('profile_info_subtitle');
  String get profileInfoSoon => _get('profile_info_soon');
  String get profilePersonalChannel => _get('profile_personal_channel');
  String get profileChannelSubtitle => _get('profile_channel_subtitle');
  String get profileChannelSoon => _get('profile_channel_soon');
  String get profileAutomation => _get('profile_automation');
  String get profileAurionSubtitle => _get('profile_aurion_subtitle');
  String get actionSaving => _get('action_saving');
  String get profileAvatarRemoved => _get('profile_avatar_removed');
  String get profileAvatarUpdated => _get('profile_avatar_updated');
  String get profileAvatarUpdatedLocal => _get('profile_avatar_updated_local');
  String get profileSetupTitle => _get('profile_setup_title');
  String get profileSetupSubtitle => _get('profile_setup_subtitle');
  String get profilePickAvatar => _get('profile_pick_avatar');
  String get profileStartChatting => _get('profile_start_chatting');
  String get profileQrCode => _get('profile_qr_code');
  String get profileQrSubtitle => _get('profile_qr_subtitle');
  String get actionMore => _get('action_more');
  String get profileMisc => _get('profile_misc');
  String get profileOther => _get('profile_other');
  String get profilePickPhoto => _get('profile_pick_photo');
  String get profileAddAccount => _get('profile_add_account');
  String get profileMultiSoon => _get('profile_multi_soon');
  String get actionLogout => _get('action_logout');
  String get profileChangeColor => _get('profile_change_color');
  String get profileChangeName => _get('profile_change_name');
  String get profileCopyLink => _get('profile_copy_link');
  String get profileColorUpdated => _get('profile_color_updated');
  String get profileNameUpdated => _get('profile_name_updated');
  String get profileNameUpdateFailed => _get('profile_name_update_failed');
  String get profileLinkCopied => _get('profile_link_copied');
  String get errorProfileSaveFailed => _get('error_profile_save_failed');
  String get aurionSuggestion1 => _get('aurion_suggestion1');
  String get aurionSuggestion2 => _get('aurion_suggestion2');
  String get aurionSuggestion3 => _get('aurion_suggestion3');
  String get aurionSuggestion4 => _get('aurion_suggestion4');
  String get aurionConnectFailed => _get('aurion_connect_failed');
  String get aurionUnavailable => _get('aurion_unavailable');
  String get aurionTryAsking => _get('aurion_try_asking');
  String get aurionInputHint => _get('aurion_input_hint');
  String get aurionGreeting => _get('aurion_greeting');
  String get aurionHeroText => _get('aurion_hero_text');
  String get aurionConnectTitle => _get('aurion_connect_title');
  String get aurionConnectBody => _get('aurion_connect_body');
  String get aurionApiKeyHint => _get('aurion_api_key_hint');
  String get aurionStatusOnline => _get('aurion_status_online');
  String get aurionStatusDegraded => _get('aurion_status_degraded');
  String get aurionStatusOff => _get('aurion_status_off');
  String get aurionAnswer => _get('aurion_answer');
  String get aurionInsertToField => _get('aurion_insert_to_field');
  String get onboardingSecurityText => _get('onboarding_security_text');
  String get onboardingBusinessText => _get('onboarding_business_text');
  String get onboardingEconomyTitle => _get('onboarding_economy_title');
  String get onboardingEconomyText => _get('onboarding_economy_text');
  String get actionSkip => _get('action_skip');
  String get actionStart => _get('action_start');
  String get actionNext => _get('action_next');
  String get profileBlocked => _get('profile_blocked');
  String get profileUnblocked => _get('profile_unblocked');
  String get profileTitle => _get('profile_title');
  String get actionMessage => _get('action_message');
  String get actionAudio => _get('action_audio');
  String get actionVideo => _get('action_video');
  String get mediaTitle => _get('media_title');
  String get mediaEmpty => _get('media_empty');
  String get actionUnblock => _get('action_unblock');
  String get actionBlock => _get('action_block');
  String get composerLockedHint => _get('composer_locked_hint');
  String get composerSwipeHint => _get('composer_swipe_hint');
  String get composerLocked => _get('composer_locked');
  String get composerSwipeHintVideo => _get('composer_swipe_hint_video');
  String get faqQ1 => _get('faq_q1');
  String get faqQ2 => _get('faq_q2');
  String get faqQ3 => _get('faq_q3');
  String get faqQ4 => _get('faq_q4');
  String get policyText => _get('policy_text');
  String get dataOther => _get('data_other');
  String get dataVideoGif => _get('data_video_gif');
  String get dataPhoto => _get('data_photo');
  String get dataVoice => _get('data_voice');
  String get dataGif => _get('data_gif');
  String get dataBytes => _get('data_bytes');
  String get dataKb => _get('data_kb');
  String get dataMb => _get('data_mb');
  String get dataGb => _get('data_gb');
  String get dataClearCacheTitle => _get('data_clear_cache_title');
  String get dataSizeTotal => _get('data_total_size');
  String get dataCacheCleared => _get('data_cache_cleared');
  String get dataClearFailed => _get('data_clear_failed');
  String get dataClearCache => _get('data_clear_cache');
  String get dataMobileDesc => _get('data_mobile_desc');
  String get dataWifiDesc => _get('data_wifi_desc');
  String get appearanceWallpaperTitle => _get('appearance_wallpaper_title');
  String get appearanceNone => _get('appearance_none');
  String get appearanceGradient => _get('appearance_gradient');
  String get appearanceResetTitle => _get('appearance_reset_title');
  String get appearanceResetBody => _get('appearance_reset_body');
  String get appearanceResetDone => _get('appearance_reset_done');
  String get appearanceAutoNight => _get('appearance_auto_night');
  String get appearanceAutoNightEnable => _get('appearance_auto_night_enable');
  String get appearanceAutoNightStart => _get('appearance_auto_night_start');
  String get appearanceAutoNightEnd => _get('appearance_auto_night_end');
  String get appearanceSendByEnter => _get('appearance_send_by_enter');
  String get appearanceSendByEnterDesc => _get('appearance_send_by_enter_desc');
  String get appearanceDefault => _get('appearance_default');
  String get appearanceColor => _get('appearance_color');
  String get appearanceListDensity => _get('appearance_list_density');
  String get appearanceCompact => _get('appearance_compact');
  String get appearanceSpacious => _get('appearance_spacious');
  String get appearanceMedium => _get('appearance_medium');
  String get appearanceResetDefaults => _get('appearance_reset_defaults');
  String get notificationsBadgeAndQuietHours => _get('notifications_badge_and_quiet_hours');
  String get notificationsBadge => _get('notifications_badge');
  String get notificationsShowBadge => _get('notifications_show_badge');
  String get notificationsBadgeHidden => _get('notifications_badge_hidden');
  String get notificationsQuietHours => _get('notifications_quiet_hours');
  String get notificationsQuietStart => _get('notifications_quiet_start');
  String get notificationsQuietEnd => _get('notifications_quiet_end');
  String get supportQuestionHint => _get('support_question_hint');
  String get supportQuestionSent => _get('support_question_sent');
  String get errorSaveFailed => _get('error_save_failed');
  String get msgOriginalFrom => _get('msg_original_from');
  String get unreadCount => _get('unread_count');
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
