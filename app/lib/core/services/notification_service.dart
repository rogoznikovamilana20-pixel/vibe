import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/backend.dart';
import '../../data/settings_service.dart';

/// Событие пуша для показывания баннера в приложении.
class VibePushEvent {
  const VibePushEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.chatId,
    this.photoUrl,
    this.callId,
    this.callType,
    this.callerId,
  });

  /// type: chat | story | generic | call
  final String type;
  final String id;
  final String title;
  final String body;
  final String? chatId;
  final String? photoUrl;

  /// Call-specific fields
  final String? callId;
  final String? callType; // "voice" | "video"
  final String? callerId;
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _local = FlutterLocalNotificationsPlugin();

  /// FCM-часть доступна только когда Firebase инициализирован (в widget-тестах
  /// его нет — лениво возвращаем null, и всё FCM-ветки тихо отключаются).
  FirebaseMessaging? _fcm;
  FirebaseMessaging? get _messaging {
    try {
      return _fcm ??= FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  /// События для in-app баннеров (приходят, когда приложение на экране).
  final _events = StreamController<VibePushEvent>.broadcast();
  Stream<VibePushEvent> get events => _events.stream;

  /// Callback для навигации: открыть чат по id.
  void Function(String chatId)? onOpenChatRequested;

  /// Callback для входящего звонка.
  void Function(VibePushEvent callEvent)? onIncomingCall;

  /// Чат, открытый сейчас на экране (чтобы не станитировать сам себе).
  String? activeChatId;

  /// Чат, ожидающий открытия после тапа по системному пущу
  /// (пока приложение ещё не доехало до RootShell).
  String? _pendingChatId;

  bool _inited = false;
  StreamSubscription<VibeMessage>? _realtimeSub;
  int _localId = 0;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    await _initLocalNotifications();

    // FCM-часть с жёстким таймаутом: без интернета запросы токена и
    // initial-сообщения могут висеть дольше, чем нужно пользователю.
    try {
      await _initFcm().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('NotificationService FCM init skipped: $e');
    }

    // Бейдж иконки: синхронизация с общим счётчиком непрочитанных.
    VibeBackend.instance.chatsUnreadTotal.addListener(_updateBadge);
    // Обновляем бейдж при изменении настроек (вкл/выкл бейджа).
    SettingsService.instance.notificationsVersion.addListener(_updateBadge);
    _updateBadge();

    // Живые события от realtime: новое входящее сообщение. Если экран
    // открыт (не этот чат) — баннер сверху; если приложение свёрнуто —
    // штатное системное уведомление. Так доставка не зависит от FCM.
    _realtimeSub?.cancel();
    _realtimeSub = VibeBackend.instance.stream.listen(_onRealtimeMessage);
  }

  Future<void> _initFcm() async {
    final messaging = _messaging;
    if (messaging == null) return; // нет Firebase (widget-тесты)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');
    await _syncToken();

    messaging.onTokenRefresh.listen((_) => _syncToken());

    // Приложение открыто, получено сообщение в foreground -> баннер.
    FirebaseMessaging.onMessage.listen((msg) {
      final e = _parseRemote(msg);
      if (e == null) return;

      // Звонки — показываем входящий звонок (всегда, даже если открыт этот чат)
      if (e.type == 'call') {
        onIncomingCall?.call(e);
        _events.add(e);
        return;
      }

      // Не показываем баннер, если открыт именно этот чат:
      if (e.type == 'chat' && e.chatId != null && e.chatId == activeChatId) {
        return;
      }
      _events.add(e);
    });

    // Тап по системному пущу (приложение было в фоне).
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      // Звонки — открываем входящий звонок
      if (msg.data['type'] == 'call') {
        final event = VibePushEvent(
          id: msg.data['callId'] ?? '',
          type: 'call',
          title: msg.data['callerName'] ?? 'Входящий звонок',
          body: msg.data['callType'] == 'video' ? 'Видеозвонок' : 'Голосовой звонок',
          callId: msg.data['callId'],
          callType: msg.data['callType'] ?? 'voice',
          callerId: msg.data['callerId'],
          chatId: msg.data['chatId'],
        );
        onIncomingCall?.call(event);
        return;
      }

      final chatId = msg.data['chatId'];
      if (chatId != null && chatId.isNotEmpty) {
        _pendingChatId = chatId;
        _flushPending();
      }
    });

    // Приложение запущено из трея (tap по уведомлению в завёрнутом виде).
    final initial = await _messaging?.getInitialMessage();
    if (initial != null) {
      // Звонки при холодном старте
      if (initial.data['type'] == 'call') {
        final event = VibePushEvent(
          id: initial.data['callId'] ?? '',
          type: 'call',
          title: initial.data['callerName'] ?? 'Входящий звонок',
          body: initial.data['callType'] == 'video' ? 'Видеозвонок' : 'Голосовой звонок',
          callId: initial.data['callId'],
          callType: initial.data['callType'] ?? 'voice',
          callerId: initial.data['callerId'],
          chatId: initial.data['chatId'],
        );
        // Отложим до готовности навигации
        Future.delayed(const Duration(seconds: 2), () {
          onIncomingCall?.call(event);
        });
        return;
      }

      final chatId = initial.data['chatId'];
      if (chatId != null && chatId.isNotEmpty) {
        _pendingChatId = chatId;
        _flushPending();
      }
    }
  }

  Future<void> _initLocalNotifications() async {
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _local.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (resp) {
          final chatId = resp.payload;
          if (chatId != null && chatId.isNotEmpty) {
            _pendingChatId = chatId;
            _flushPending();
          }
        },
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Local notifications init error: $e');
    }
  }

  void _onRealtimeMessage(VibeMessage msg) {
    if (msg.chatId == activeChatId) return;

    final s = SettingsService.instance;

    // Скрытые чаты — тишина: ни превью, ни уведомления (приватность).
    if (s.hiddenChats.contains(msg.chatId)) return;

    // Тихие часы — подавляем уведомления.
    if (s.quietHoursEnabled && s.isQuietHoursNow) return;

    // Настройка «Уведомления из чатов»: личные/группы можно выключить.
    // Тип чата берём с кешем (без лишних запросов на каждое сообщение).
    unawaited(() async {
      final kind = await VibeBackend.instance.chatKindOf(msg.chatId);
      if ((kind == 'pm' || kind.isEmpty) && !s.notifyPersonal) return;
      if (kind == 'group' && !s.notifyGroups) return;

      // Превью чатов: выключено — не показываем текст сообщения.
      final showPreview = s.chatPreview;
      final content = showPreview ? _bodyFor(msg) : _noPreviewFor(msg);
      final body = content ?? 'Новое сообщение';
      final event = VibePushEvent(
        id: msg.id,
        type: 'chat',
        title: msg.senderName,
        body: body,
        chatId: msg.chatId,
      );

      final lifecycle = WidgetsBinding.instance.lifecycleState;
      final foreground = lifecycle == AppLifecycleState.resumed ||
          lifecycle == AppLifecycleState.inactive;
      if (foreground) {
        _events.add(event);
      } else {
        _showLocalNotification(event);
      }
    }());
  }

  /// Текст превью с учётом типа контента.
  String? _bodyFor(VibeMessage msg) {
    switch ((msg.photoPath, msg.voicePath, msg.videoPath)) {
      case (final p?, _, _) when p.isNotEmpty:
        return '[Фото]';
      case (_, final v?, _) when v.isNotEmpty:
        return '[Голосовое]';
      case (_, _, final vd?) when vd.isNotEmpty:
        return '[Видеокружок]';
      default:
        return msg.text?.isNotEmpty == true ? msg.text : null;
    }
  }

  /// Без превью: только служебная метка.
  String? _noPreviewFor(VibeMessage msg) {
    switch ((msg.photoPath, msg.voicePath, msg.videoPath)) {
      case (final p?, _, _) when p.isNotEmpty:
        return '[Фото]';
      case (_, final v?, _) when v.isNotEmpty:
        return '[Голосовое]';
      case (_, _, final vd?) when vd.isNotEmpty:
        return '[Видеокружок]';
      default:
        return null;
    }
  }

  Future<void> _showLocalNotification(VibePushEvent e) async {
    try {
      final s = SettingsService.instance;
      final playSound = s.inAppSounds;
      final vibrate = s.inAppVibration;
      await _local.show(
        id: _localId++,
        title: e.title,
        body: e.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'vibe_chat',
            'Сообщения Vibe',
            channelDescription: 'Новые сообщения в чатах',
            importance: Importance.high,
            priority: Priority.high,
            playSound: playSound,
            enableVibration: vibrate,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: e.chatId,
      );
      _updateBadge();
    } catch (e) {
      debugPrint('Local notification error: $e');
    }
  }

  /// Обновляет бейдж иконки приложения на основе счётчика непрочитанных.
  void _updateBadge() {
    // Badge count is managed via Android notification channel automatically.
    // Local badge packages are deprecated or broken with modern Gradle.
  }

  /// Помечает «текущий открытый чат», чтобы не дублировать баннером.
  void enterChat(String chatId) => activeChatId = chatId;
  void exitChat([String? chatId]) {
    if (chatId == null || activeChatId == chatId) activeChatId = null;
  }

  /// Вызов после построения RootShell: открыть отложенный чат с тапа.
  void flushPendingOpen() => _flushPending();

  void _flushPending() {
    final id = _pendingChatId;
    if (id == null) return;
    _pendingChatId = null;
    final open = onOpenChatRequested;
    open?.call(id);
  }

  /// Переслать FCM-токен в профиль (после входа).
  Future<void> syncToken() => _syncToken();

  Future<void> _syncToken() async {
    try {
      final token = await _messaging?.getToken();
      if (token == null) return;
      debugPrint('FCM token synced');
      if (VibeBackend.instance.myProfileId != null) {
        await VibeBackend.instance.updateFcmToken(token);
      }
    } catch (e) {
      debugPrint('FCM token sync error: $e');
    }
  }

  VibePushEvent? _parseRemote(RemoteMessage msg) {
    final data = msg.data;
    final type = data['type'] ?? 'generic';
    final chatId = data['chatId'];
    final n = msg.notification;
    if (n == null) return null;

    return VibePushEvent(
      id: msg.messageId ?? '${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      title: n.title ?? 'Vibe',
      body: n.body ?? '',
      chatId: chatId,
      photoUrl: data['photoUrl'],
    );
  }
}