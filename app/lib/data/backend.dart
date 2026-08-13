import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/notification_service.dart';
import '../chat/attachments.dart';

/// Одна модель «чата» из списка.
class VibeChat {
  const VibeChat({
    required this.id,
    required this.title,
    required this.kind,
    required this.lastMessage,
    required this.lastTime,
    required this.unread,
required this.peerName,
    required this.peerAvatar,
    this.peerId,
    this.peerOnline = false,
    this.peerLastSeen,
  });

  final String id;
  final String title;
  final String kind;
  final String lastMessage;
  final String lastTime;
  final int unread;
  final String? peerName;
  final String? peerAvatar;

  /// Идентификатор собеседника (для личных чатов).
  final String? peerId;

  /// Собеседник сейчас онлайн (для личных чатов; группы — false).
  final bool peerOnline;

  /// Время последнего входа собеседника (если не скрыто приватностью).
  final DateTime? peerLastSeen;
}

/// Один стикер в паке.
class VibeSticker {
  const VibeSticker({required this.id, required this.emoji});

  final String id;
  final String emoji;
}

/// Стикер-пак (как в Telegram: папка со стикерами).
class VibeStickerPack {
  const VibeStickerPack({
    required this.id,
    required this.title,
    this.stickers = const [],
  });

  final String id;
  final String title;
  final List<VibeSticker> stickers;
}

/// Статус сообщения (как галочки в Telegram):
///  - sending — ещё летит на сервер (показываем часики);
///  - sent — одна серая галочка: сервер принял;
///  - delivered — две серые: собеседник получил (его устройство онлайн);
///  - read — две синие: собеседник открыл чат;
///  - failed — не ушло (сеть/сервер).
enum MsgStatus { sending, sent, delivered, read, failed }

/// Снимок правки сообщения (история правок): старый текст в момент правки.
class MessageEdit {
  const MessageEdit({
    required this.messageId,
    required this.text,
    required this.editedAt,
  });

  final String messageId;
  final String text;
  final DateTime editedAt;
}

/// Одна модель сообщения в чате.
class VibeMessage {
  const VibeMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    required this.voicePath,
    required this.photoPath,
    required this.videoPath,
    required this.created,
    required this.incoming,
    this.status = MsgStatus.sent,
    this.localId,
    this.replyText,
    this.replyAuthor,
    this.edited = false,
    this.forwardedFrom,
    this.stickerEmoji,
    this.reactions = const {},
  });

  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String? text;
  final String? voicePath;
  final String? photoPath;
  final String? videoPath;
  final DateTime created;
  final bool incoming;

  /// Стикер-эмодзи: сообщение-стикер (текста нет).
  final String? stickerEmoji;

  /// Сообщение было изменено автором (метка «изменено» как в Telegram).
  final bool edited;

  /// Имя автора оригинала при пересылке («Переслано от …»).
  final String? forwardedFrom;

  /// Реакции: эмодзи → количество поставивших (заполняется с сервера).
  final Map<String, int> reactions;

  /// Статус отправки (для своих сообщений).
  final MsgStatus status;

  /// Локальный ключ для «мгновенного» показа: отправляем с телом сообщения,
  /// потом заменяем тем же ключом из ответа сервера — пузырь не мигает.
  final String? localId;

  /// Ответ-цитата (только для локального отображения, на сервер не идёт).
  final String? replyText;
  final String? replyAuthor;

  VibeMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? text,
    String? voicePath,
    String? photoPath,
    String? videoPath,
    DateTime? created,
    bool? incoming,
    MsgStatus? status,
    String? localId,
    String? replyText,
    String? replyAuthor,
    bool? edited,
    String? forwardedFrom,
    Map<String, int>? reactions,
  }) {
    return VibeMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      text: text ?? this.text,
      voicePath: voicePath ?? this.voicePath,
      photoPath: photoPath ?? this.photoPath,
      videoPath: videoPath ?? this.videoPath,
      created: created ?? this.created,
      incoming: incoming ?? this.incoming,
      status: status ?? this.status,
      localId: localId ?? this.localId,
      replyText: replyText ?? this.replyText,
      replyAuthor: replyAuthor ?? this.replyAuthor,
      edited: edited ?? this.edited,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
      reactions: reactions ?? this.reactions,
    );
  }
}

/// Событие изменения истории, адресованное чат-экрану:
/// правка, удаление сообщения или очистка всей переписки.
enum VibeMsgEventType { edited, deleted, cleared, reactions }

class VibeMsgEvent {
  const VibeMsgEvent({
    required this.type,
    required this.chatId,
    this.messageId,
    this.updated,
    this.reactions,
  });

  final VibeMsgEventType type;

  /// Чат, в котором произошло изменение.
  final String chatId;

  /// Сообщение, которого касается событие (не для cleared).
  final String? messageId;

  /// Обновлённая версия сообщения (для edited).
  final VibeMessage? updated;

  /// Реакции: эмодзи → количество (для reactions).
  final Map<String, int>? reactions;
}

/// Закреплённое сообщение изменилось (поставлено/снято в реальном времени).
class PinChanged {
  const PinChanged({
    required this.chatId,
    required this.messageId,
    required this.pinned,
  });

  final String chatId;
  final String messageId;
  final bool pinned;
}

/// Настройки приватности владельца (3.7): 0 — Все, 1 — Мои контакты,
/// 2 — Никто. Зеркалируются в таблицу `profile_privacy`.
class PrivacySettings {
  const PrivacySettings({
    this.lastSeen = 0,
    this.photo = 0,
    this.forward = 0,
    this.calls = 0,
    this.groups = 0,
  });

  final int lastSeen;
  final int photo;
  final int forward;
  final int calls;
  final int groups;

  factory PrivacySettings.fromMap(Map<String, dynamic> m) => PrivacySettings(
        lastSeen: (m['last_seen'] as num?)?.toInt() ?? 0,
        photo: (m['photo'] as num?)?.toInt() ?? 0,
        forward: (m['forward'] as num?)?.toInt() ?? 0,
        calls: (m['calls'] as num?)?.toInt() ?? 0,
        groups: (m['groups'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'last_seen': lastSeen,
        'photo': photo,
        'forward': forward,
        'calls': calls,
        'groups': groups,
      };
}

/// Модель профиля пользователя/контакта.
class VibeProfile {
  const VibeProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.phone,
    this.fcmToken,
    this.uid,
    this.emoji,
    this.avatar,
    this.bio = '',
    this.online = false,
    this.lastSeen,
  });

  final String id;
  final String username;
  final String displayName;
  final String? phone;
  final String? fcmToken;
  final int? uid;
  final String? emoji;
  final String? avatar;
  final String bio;
  final bool online;

  /// Время последнего появления в сети (если не скрыто приватностью).
  final DateTime? lastSeen;

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'phone': phone,
        'fcmToken': fcmToken,
        'uid': uid,
        'emoji': emoji,
        'avatar': avatar,
        'bio': bio,
        'online': online,
        'last_seen': lastSeen?.toIso8601String(),
      };

  factory VibeProfile.fromJson(Map<String, dynamic> json) => VibeProfile(
        id: json['id'],
        username: json['username'] ?? '',
        displayName: json['display_name'] ?? '',
        phone: json['phone'],
        fcmToken: json['fcm_token'],
        uid: json['uid'],
        emoji: json['emoji'],
        avatar: json['avatar_url'],
        bio: json['bio'] ?? '',
        online: json['online'] ?? false,
        lastSeen: json['last_seen'] != null
            ? DateTime.tryParse('${json['last_seen']}')
            : null,
      );

  /// Копия без чувствительных полей — для показа другим пользователям
  /// (номер телефона, FCM-токен и время входа никогда не покидают «мои» данные).
  VibeProfile copyWithPrivacySafe() => VibeProfile(
        id: id,
        username: username,
        displayName: displayName,
        phone: null,
        emoji: emoji,
        avatar: avatar,
        bio: bio,
        online: online,
      );
}

/// Публичная история (стор) из облака.
class VibeStory {
  const VibeStory({
    required this.id,
    required this.profileId,
    this.photoUrl,
    this.authorName,
    this.createdAt,
  });

  final String id;
  final String profileId;
  final String? photoUrl;
  final String? authorName;
  final DateTime? createdAt;

  factory VibeStory.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    return VibeStory(
      id: json['id'],
      profileId: json['profile_id'],
      photoUrl: json['photo_url'],
      authorName: author is Map<String, dynamic>
          ? author['display_name'] as String?
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// Клиент Supabase: профили, чаты, сообщения, realtime.
class VibeBackend {
  VibeBackend._(this._client);

  static VibeBackend? _instance;
  static VibeBackend get instance => _instance!;

  final SupabaseClient _client;

  VibeProfile? _myProfile;
  VibeProfile? get myProfile => _myProfile;

  static final myProfileNotifier = ValueNotifier<VibeProfile?>(null);
  String? myProfileId;

  final streamController = StreamController<VibeMessage>.broadcast();
  Stream<VibeMessage> get stream => streamController.stream;

  /// Изменения истории в реальном времени: правки, удаления, очистка.
  /// Чат-экран подписывается и обновляет список «на лету».
  final msgEventsController =
      StreamController<VibeMsgEvent>.broadcast();
  Stream<VibeMsgEvent> get msgEvents => msgEventsController.stream;

  /// Любое изменение «ленты»: новый чат/стори/входящее — чат-лист
  /// перезагружается сразу (мгновенные появления чатов).
  final _chatsController = StreamController<void>.broadcast();
  Stream<void> get chatEvents => _chatsController.stream;

  /// Закреплённые сообщения в реальном времени: кто-то пинит/снимает —
  /// открытые чаты обновляют плашку сразу.
  final _pinEventsController = StreamController<PinChanged>.broadcast();
  Stream<PinChanged> get pinEvents => _pinEventsController.stream;

  /// Дедупликация: одно и то же сообщение может прийти и по realtime
  /// postgres_changes, и по broadcast — показываем только один раз.
  final _seenIds = <String>{};

  /// Broadcast-канал доставки в реальном времени (мгновенно, без
  /// публикаций в Postgres — работает из коробки на любом Supabase).
  /// Глобальный — только для публичной ленты историй.
  static const _dmChannelName = 'dm';
  RealtimeChannel? _dmChannel;

  /// Приватный канал пользователя (`u_<myId>`): доставляются только
  /// события, адресованные именно мне, — никто не видит чужих.
  RealtimeChannel? _personal;
  String? _personalName;

  /// Кэш собеседников по chatId + кэш «моих» чатов: отправка и
  /// фильтрация realtime не дёргают базу на каждое событие.
  final _peers = <String, _CachedPeer>{};

  /// Проверка принадлежности чата мне (для postgres_changes-пути).
  Future<bool> _isMyChat(String chatId) {
    final hit = _peers[chatId];
    if (hit != null && hit.expiresAt.isAfter(DateTime.now())) {
      return Future.value(hit.peerId != null);
    }
    return _client
        .from('chats')
        .select('members')
        .eq('id', chatId)
        .maybeSingle()
        .then((c) {
      final members = c == null ? const <String>[] : List<String>.from(c['members']);
      final peerId = myProfileId == null
          ? null
          : members.firstWhere((m) => m != myProfileId, orElse: () => myProfileId!);
      _peers[chatId] = _CachedPeer(
        peerId,
        DateTime.now().add(const Duration(minutes: 5)),
      );
      return peerId != null;
    }).catchError((_) => false);
  }

  /// Собеседник в личном чате (с кэшем).
  Future<String?> _peerIdOf(String chatId) async {
    final hit = _peers[chatId];
    if (hit != null && hit.expiresAt.isAfter(DateTime.now())) {
      return hit.peerId;
    }
    try {
      final c = await _client
          .from('chats')
          .select('members')
          .eq('id', chatId)
          .maybeSingle();
      final members =
          c == null ? const <String>[] : List<String>.from(c['members']);
      final peerId = myProfileId == null
          ? null
          : members.firstWhere((m) => m != myProfileId, orElse: () => myProfileId!);
      _peers[chatId] = _CachedPeer(
        peerId,
        DateTime.now().add(const Duration(minutes: 5)),
      );
      return peerId;
    } catch (_) {
      return null;
    }
  }

  static Future<VibeBackend> init({String? myId}) async {
    final client = Supabase.instance.client;
    final backend = VibeBackend._(client);
    _instance = backend;

    // Дожидаемся восстановления auth-сессии (JWT) из хранилища клиента.
    final restored = await _waitForAuthRestore(client);
    if (restored) {
      final user = client.auth.currentUser;
      if (user != null) {
        backend.myProfileId = user.id;
        final cached = await _loadLocalProfile();
        if (cached != null && cached.id == user.id) {
          backend._myProfile = cached;
          myProfileNotifier.value = cached;
        }
        unawaited(backend.profileById(user.id).then((p) {
          if (p != null) backend.setMyProfile(p);
        }));
      }
    }

    backend.subscribeMessages();
    backend.startNetworkMonitor();
    return backend;
  }

  /// Ждёт первое событие auth (сессия из storage загружена или её нет).
  static Future<bool> _waitForAuthRestore(SupabaseClient client) async {
    final completer = Completer<void>();
    late final StreamSubscription<AuthState> sub;
    sub = client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.initialSession ||
          data.event == AuthChangeEvent.signedIn) {
        if (!completer.isCompleted) completer.complete();
      }
    });
    await completer.future
        .timeout(const Duration(seconds: 4), onTimeout: () {});
    await sub.cancel();
    return client.auth.currentUser != null;
  }

  static VibeProfile? _cachedProfile;
  static Future<VibeProfile?> _loadLocalProfile() async {
    if (_cachedProfile != null) return _cachedProfile;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}session.json');
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        _cachedProfile = VibeProfile.fromJson(data);
      }
    } catch (_) {}
    return _cachedProfile;
  }

  // ==== Оффлайн-кеш (как в Telegram: синхронизированный контент доступен
  // без сети) ====
  //
  // Кеш последнего успешного ответа: чаты (список) и сообщения (на чат).
  // При недоступной сети отдаём кеш, помечая режим [isOffline].
  //
  // Плашка «нет сети» показывается ТОЛЬКО при реальной потере связности на
  // устройстве (connectivity_plus). Недоступность сервера при живом
  // интернете плашку НЕ включает — как в Telegram: если супабайз лежит,
  // показываем кеш молча, без красного баннера.
  bool get isOffline => !_networkAvailable;

  /// Есть ли интернет на устройстве (по данным connectivity_plus).
  bool _networkAvailable = true;

  /// Доступен ли бекенд (последний health-check к Supabase прошёл).
  bool _backendReachable = true;

  /// Сигнал об изменении сетевого режима (для баннеров «оффлайн»).
  final ValueNotifier<int> connectivityVersion = ValueNotifier<int>(0);

  Timer? _healthTimer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  /// Период проверки доступности сервера (health-check).
  static const _healthInterval = Duration(seconds: 12);

  /// Запускает мониторинг сети: подписка на изменение связности устройства
  /// плюс периодический health-check к Supabase. Легковесный запрос, не
  /// тяжёлый — безопасен для тарифа Supabase.
  void startNetworkMonitor() {
    _connSub ??=
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    _healthTimer ??=
        Timer.periodic(_healthInterval, (_) => unawaited(_healthCheck()));
    unawaited(_syncConnectivity());
    unawaited(_healthCheck());
  }

  Future<void> _syncConnectivity() async {
    try {
      _onConnectivityChanged(await Connectivity().checkConnectivity());
    } catch (_) {}
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final ok = results.any((r) => r != ConnectivityResult.none);
    // Нет связи на устройстве — сразу флаг «оффлайн».
    if (!ok && _networkAvailable) {
      _networkAvailable = false;
      connectivityVersion.value++;
    } else if (ok && !_networkAvailable) {
      _networkAvailable = true;
      connectivityVersion.value++;
      // Сеть вернулась: снимаем оффлайн, переподключаем realtime и
      // даём знать UI (чаты перечитаются из сети).
      unawaited(_reconnectRealtime());
      if (!_chatsController.isClosed) _chatsController.add(null);
      unawaited(_healthCheck());
    }
  }

  /// Периодический пинг доступности бекенда. Если интернет есть, а сервер
  /// не отвечает — оффлайн-режим входа НЕ включаем (см. [isOffline]), просто
  /// держим пометку для кеш-стратегии.
  Future<void> _healthCheck() async {
    if (!_networkAvailable) return; // без сети сервер не проверить
    try {
      await _client
          .from('profiles')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      final was = _backendReachable;
      _backendReachable = true;
      if (!was) {
        // Сервер вернулся — подскажем UI обновить ленту.
        if (!_chatsController.isClosed) _chatsController.add(null);
      }
    } catch (_) {
      _backendReachable = false;
    }
  }

  /// Пересоздаёт realtime-каналы после потери/восстановления сети.
  Future<void> _reconnectRealtime() async {
    try {
      final personal = _personal;
      if (personal != null) {
        try {
          await personal.unsubscribe();
        } catch (_) {}
        _personal = null;
        _personalName = null;
      }
      final dm = _dmChannel;
      if (dm != null) {
        try {
          await dm.unsubscribe();
        } catch (_) {}
        _dmChannel = _client.channel(_dmChannelName)
          ..onBroadcast(
              event: 'new_story', callback: (_) => _chatsController.add(null));
        _dmChannel!.subscribe();
      }
      _ensurePersonalChannel();
    } catch (_) {}
  }

  static final String _cacheDirName = 'vibe_cache';
  static Future<Directory> _cacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final c = Directory('${dir.path}${Platform.pathSeparator}$_cacheDirName');
    if (!await c.exists()) await c.create(recursive: true);
    return c;
  }

  static Future<void> _writeCache(String name, Object data) async {
    try {
      final c = await _cacheDir();
      await File('${c.path}${Platform.pathSeparator}$name.json')
          .writeAsString(jsonEncode(data), flush: true);
    } catch (_) {}
  }

  static Future<dynamic> _readCache(String name) async {
    try {
      final c = await _cacheDir();
      final f = File('${c.path}${Platform.pathSeparator}$name.json');
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  static const _cacheChatsName = 'chats';
  static String _cacheMsgsName(String chatId) => 'msgs_$chatId';

  /// Мгновенное чтение чатов из локальной памяти (для старта без задержек).
  Future<List<VibeChat>> getOfflineChats() async {
    final rows = await _readCache(_cacheChatsName);
    if (rows is List) {
      return rows
          .whereType<Map<String, dynamic>>()
          .map(_chatFromCacheRow)
          .toList();
    }
    return [];
  }

  static Map<String, dynamic> _chatToCacheRow(VibeChat c) => {
        'id': c.id,
        'title': c.title,
        'kind': c.kind,
        'lastMessage': c.lastMessage,
        'lastTime': c.lastTime,
        'unread': c.unread,
        'peerName': c.peerName,
        'peerAvatar': c.peerAvatar,
        'peerId': c.peerId,
        'peerOnline': c.peerOnline,
        'peerLastSeen': c.peerLastSeen?.toIso8601String(),
      };

  static VibeChat _chatFromCacheRow(Map<String, dynamic> m) => VibeChat(
        id: m['id'],
        title: m['title'],
        kind: m['kind'],
        lastMessage: m['lastMessage'],
        lastTime: m['lastTime'],
        unread: m['unread'] ?? 0,
        peerName: m['peerName'],
        peerAvatar: m['peerAvatar'],
        peerId: m['peerId'],
        peerOnline: m['peerOnline'] ?? false,
        peerLastSeen: m['peerLastSeen'] != null
            ? DateTime.tryParse('${m['peerLastSeen']}')
            : null,
      );

  static List<VibeMessage> _messagesFromCacheRows(List<dynamic> rows) {
    return rows.map((r) {
      final m = r as Map<String, dynamic>;
      return VibeMessage(
        id: m['id'],
        chatId: m['chatId'],
        senderId: m['senderId'],
        senderName: m['senderName'] ?? '',
        senderAvatar: m['senderAvatar'],
        text: m['text'],
        voicePath: m['voicePath'],
        photoPath: m['photoPath'],
        videoPath: m['videoPath'],
        created: DateTime.tryParse('${m['created']}') ?? DateTime.now(),
        incoming: m['incoming'] == true,
        status: MsgStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => MsgStatus.sent,
        ),
        localId: m['localId'],
        replyText: m['replyText'],
        replyAuthor: m['replyAuthor'],
        edited: m['edited'] == true,
        forwardedFrom: m['forwardedFrom'],
      );
    }).toList();
  }

  static Map<String, dynamic> _messageToCacheRow(VibeMessage m) => {
        'id': m.id,
        'chatId': m.chatId,
        'senderId': m.senderId,
        'senderName': m.senderName,
        'senderAvatar': m.senderAvatar,
        'text': m.text,
        'voicePath': m.voicePath,
        'photoPath': m.photoPath,
        'videoPath': m.videoPath,
        'created': m.created.toIso8601String(),
        'incoming': m.incoming,
        'status': m.status.name,
        'localId': m.localId,
        'replyText': m.replyText,
        'replyAuthor': m.replyAuthor,
        'edited': m.edited,
        'forwardedFrom': m.forwardedFrom,
      };

  static Future<void> saveMyId(String id) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}my_profile_id.txt');
      await f.writeAsString(id, flush: true);
    } catch (_) {}
  }

  static Future<void> _saveLocalProfile(VibeProfile p) async {
    _cachedProfile = p;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}session.json');
      await f.writeAsString(jsonEncode(p.toJson()), flush: true);
    } catch (_) {}
  }

  /// Регистрация через Supabase Auth. Профиль создаёт серверный
  /// триггер (auth.users -> profiles); пароль хранит только GoTrue.
  Future<VibeProfile> register({
    required String phone,
    required String password,
  }) async {
    final email = _emailForPhone(phone);
    try {
      await _client.auth.signUp(email: email, password: password);
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    }
    return _profileAfterAuth();
  }

  /// Вход по номеру и паролю (JWT-сессия). null — неверные данные.
  Future<VibeProfile?> login({
    required String phone,
    required String password,
  }) async {
    final email = _emailForPhone(phone);
    try {
      await _client.auth
          .signInWithPassword(email: email, password: password);
    } on AuthException {
      return null;
    }
    return _profileAfterAuth();
  }

  static String _emailForPhone(String phone) =>
      '${phone.replaceAll(RegExp(r'[^\d]'), '')}@vibe.local';

  Future<VibeProfile> _profileAfterAuth() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Не удалось войти. Попробуйте ещё раз.');
    }
    final profile = await profileById(user.id) ??
        VibeProfile.fromJson({'id': user.id});
    await setMyProfile(profile);
    return profile;
  }

  /// Русскоязычные сообщения по исключениям Supabase Auth.
  static Exception _mapAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('already registered')) {
      return Exception('Номер уже зарегистрирован. Войдите с паролем.');
    }
    if (msg.contains('password')) {
      return Exception('Пароль должен быть не короче 6 символов.');
    }
    return Exception('Не удалось создать аккаунт. Попробуйте ещё раз.');
  }

  Future<void> updateProfile({
    required String username,
    required String displayName,
    String? emoji,
    String? bio,
  }) async {
    if (myProfileId == null) return;
    final updated = await _client.from('profiles').update({
      'username': username.toLowerCase().trim(),
      'display_name': displayName.trim(),
      'emoji': ?emoji,
      'bio': ?bio,
    }).eq('id', myProfileId!).select('id,username,display_name,emoji,avatar_url,bio,online,uid').single();
    
    await setMyProfile(VibeProfile.fromJson(updated));
  }

  Future<bool> isUsernameAvailable(String username) async {
    final clean = username.toLowerCase().trim();
    if (clean.length < 3) return false;
    final res = await _client
        .from('profiles')
        .select('id')
        .eq('username', clean)
        .neq('id', myProfileId ?? '')
        .maybeSingle();
    return res == null;
  }

  /// 3.7: облачное зеркало настроек приватности (best-effort; клиент
  /// держит локальный кеш и деградирует при недоступности сервера).
  Future<PrivacySettings?> fetchPrivacy() async {
    if (myProfileId == null) return null;
    try {
      final row = await _client
          .from('profile_privacy')
          .select()
          .eq('user_id', myProfileId!)
          .maybeSingle();
      if (row == null) return null;
      return PrivacySettings.fromMap(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePrivacy(PrivacySettings settings) async {
    if (myProfileId == null) return;
    await _client.from('profile_privacy').upsert({
      'user_id': myProfileId,
      ...settings.toMap(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  /// Мои контакты: только те, с кем у меня уже есть личные чаты.
  /// Никаких глобальных списков — чужие профили (и телефоны) наружу
  /// не попадают.
  Future<List<VibeProfile>> listContacts() async {
    if (myProfileId == null) return [];
    try {
      final res = await _client
          .from('chats')
          .select('members')
          .eq('kind', 'pm')
          .contains('members', [myProfileId])
          .limit(200);
      final peerIds = <String>{};
      for (final c in res) {
        final members = List<String>.from(c['members']);
        for (final m in members) {
          if (m != myProfileId) peerIds.add(m);
        }
      }
      final contacts = <VibeProfile>[];
      for (final id in peerIds) {
        final p = await profileById(id);
        if (p != null) contacts.add(p.copyWithPrivacySafe());
      }
      return contacts;
    } catch (_) {
      return [];
    }
  }

  /// Поиск людей по нику/имени по всей базе — как глобальный поиск
  /// в Telegram: без номеров телефонов в результатах.
  Future<List<VibeProfile>> searchUsers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final res = await _client
        .from('profiles')
        .select('id,username,display_name,emoji,avatar_url,bio,uid')
        .or('username.ilike.%$q%,display_name.ilike.%$q%')
        .limit(20);

    return (res as List)
        .map((e) => VibeProfile.fromJson(e).copyWithPrivacySafe())
        .toList();
  }

  final _profileCache = <String, _CachedProfile>{};

  Future<VibeProfile?> profileById(String id) async {
    final hit = _profileCache[id];
    if (hit != null && hit.expiresAt.isAfter(DateTime.now())) {
      return hit.profile;
    }
    try {
      final p = await _client
          .from('profiles')
          .select('id,username,display_name,emoji,avatar_url,bio,online,uid')
          .eq('id', id)
          .single();
      final profile = VibeProfile.fromJson(p);
      _profileCache[id] = _CachedProfile(
        profile,
        DateTime.now().add(const Duration(minutes: 5)),
      );
      return profile;
    } catch (_) {
      return null;
    }
  }

Future<void> setMyProfile(VibeProfile p) async {
    _myProfile = p;
    myProfileId = p.id;
    myProfileNotifier.value = p;
    await _saveLocalProfile(p);
    await saveMyId(p.id);
    // Личный realtime-канал пересоздаётся под новый аккаунт.
    _ensurePersonalChannel();
    // Присутствие: отмечаемся онлайн при входе и слушаем чужие статусы.
    startPresence();
  }

  // ==== Онлайн-статусы (как в Telegram: точка «в сети» только у тех,
  // кто реально в сети) ====
  //
  // Свой статус держим честным: включаем при входе/возобновлении,
  // выключаем при сворачивании, heartbeat обновляет каждую минуту.
  // Чужие статусы прилетают через realtime на таблицу profiles.

  Timer? _presenceTimer;
  RealtimeChannel? _presenceChannel;

  /// Сигнал об изменении чужого статуса онлайна (для живых точек).
  final ValueNotifier<int> presenceVersion = ValueNotifier<int>(0);

  void startPresence() {
    final id = myProfileId;
    if (id == null) return;
    unawaited(_writeOnline(id, true));
    _presenceTimer ??= Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        final me = myProfileId;
        if (me != null) unawaited(_writeOnline(me, true));
      },
    );
    _subscribePresence();
  }

  /// Включить/выключить собственный статус «в сети»
  /// (сворачивание приложения, выход из чата на рабочий стол и т.п.).
  Future<void> setOnline(bool value) async {
    final id = myProfileId;
    if (id == null) return;
    await _writeOnline(id, value);
  }

  Future<void> _writeOnline(String id, bool value) async {
    try {
      // Время последнего входа пишем заодно со статусом «в сети»:
      // по нему показываем «был(а) в сети …», когда человек офлайн.
      await _client.from('profiles').update({
        'online': value,
      }).eq('id', id);
    } catch (_) {
      // Оффлайн/права — статус просто не обновится, ничего не ломаем.
    }
  }

  void _subscribePresence() {
    if (_presenceChannel != null) return;
    _presenceChannel = _client
        .channel('presence')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            final data = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            final id = data['id'] as String?;
            if (id == null) return;
            // Сбрасываем кеш профиля — next read возьмёт свежий статус.
            _profileCache.remove(id);
            presenceVersion.value++;
          },
        )
        .subscribe();
  }

  Future<void> logout() async {
    final id = myProfileId;
    if (id != null) unawaited(_writeOnline(id, false));
    await _client.auth.signOut();
    final old = _personal;
    if (old != null) {
      _client.removeChannel(old);
    }
    _personal = null;
    _personalName = null;
    _myProfile = null;
    myProfileId = null;
    myProfileNotifier.value = null;
    final dir = await getApplicationDocumentsDirectory();
    final f1 = File('${dir.path}${Platform.pathSeparator}session.json');
    if (await f1.exists()) await f1.delete();
  }

  Future<String> ensurePmChat(String peerId) async {
    if (myProfileId == null) return '';

    // Ищем существующий личный чат
    final existing = await _client
        .from('chats')
        .select()
        .eq('kind', 'pm')
        .contains('members', [myProfileId, peerId])
        .maybeSingle();

    if (existing != null) return existing['id'];

    final created = await _client.from('chats').insert({
      'kind': 'pm',
      'members': [myProfileId, peerId],
    }).select().single();

    // Мгновенно сообщаем собеседнику: появился новый чат.
    // Только на его личный канал — чужим эта информация не попадает.
    unawaited(_sendRemote('u_$peerId', 'new_chat', {
      'chat_id': created['id'],
      'sender_id': myProfileId,
    }));

    // Себе (локально на этом устройстве) — обновить список чатов.
    _chatsController.add(null);

    return created['id'];
  }

  Future<String> createGroupChat(List<String> memberIds) async {
    if (myProfileId == null) return '';
    try {
      final members = [
        myProfileId!,
        ...memberIds.where((m) => m != myProfileId),
      ];
      final created = await _client.from('chats').insert({
        'kind': 'group',
        'members': members,
      }).select().single();
      // Всем участникам — появился новый групповой чат.
      for (final m in members) {
        if (m == myProfileId) continue;
        unawaited(_sendRemote('u_$m', 'new_chat', {
          'chat_id': created['id'],
          'sender_id': myProfileId,
        }));
      }
      _chatsController.add(null);
      return created['id'];
    } catch (_) {
      return '';
    }
  }

  /// «Избранное»: личный чат с самим собой (как Saved Messages в TG).
  Future<String> ensureSavedChat() async {
    final me = myProfileId;
    if (me == null) return '';
    try {
      final existing = await _client
          .from('chats')
          .select('id')
          .eq('kind', 'pm')
          .eq('members', [me, me])
          .maybeSingle();
      if (existing != null) return existing['id'];
    } catch (_) {}
    try {
      final created = await _client
          .from('chats')
          .insert({
            'kind': 'pm',
            'members': [me, me],
          })
          .select()
          .single();
      _chatsController.add(null);
      return created['id'];
    } catch (_) {
      return '';
    }
  }

  /// Участники чата (с коротким кешем — реальтайм-доставка групповых).
  final Map<String, ({List<String> ids, DateTime at})> _membersCache = {};
  Future<List<String>> chatMemberIds(String chatId) async {
    final hit = _membersCache[chatId];
    if (hit != null &&
        DateTime.now().difference(hit.at) < const Duration(minutes: 2)) {
      return hit.ids;
    }
    try {
      final c = await _client
          .from('chats')
          .select('members')
          .eq('id', chatId)
          .maybeSingle();
      if (c == null) return const [];
      final ids = List<String>.from(c['members']);
      _membersCache[chatId] = (ids: ids, at: DateTime.now());
      return ids;
    } catch (_) {
      return const [];
    }
  }

  /// Тип чата: `pm` | `group` | '' (кеш 2 мин — для гейтинга уведомлений).
  final Map<String, ({String kind, DateTime at})> _chatKindCache = {};
  Future<String> chatKindOf(String chatId) async {
    if (chatId.isEmpty) return '';
    final hit = _chatKindCache[chatId];
    if (hit != null &&
        DateTime.now().difference(hit.at) < const Duration(minutes: 2)) {
      return hit.kind;
    }
    try {
      final c = await _client
          .from('chats')
          .select('kind')
          .eq('id', chatId)
          .maybeSingle();
      final kind = '${(c as Map? ?? {})['kind'] ?? 'pm'}';
      _chatKindCache[chatId] = (kind: kind, at: DateTime.now());
      return kind;
    } catch (_) {
      return '';
    }
  }

  /// Участники группы с профилями (включая меня).
  Future<List<VibeProfile>> groupMembers(String chatId) async {
    final ids = await chatMemberIds(chatId);
    if (ids.isEmpty) return const [];
    try {
      final rows = await _client
          .from('profiles')
          .select('id,username,display_name,emoji,avatar_url,bio,online,uid')
          .inFilter('id', ids);
      final profiles = [
        for (final r in rows) VibeProfile.fromJson(r),
      ];
      profiles.sort((a, b) => a.displayName.compareTo(b.displayName));
      return profiles;
    } catch (_) {
      return const [];
    }
  }

  /// Переименование группы: пишем кастомное название, всем участникам —
  /// событие обновления, списки чатов перечитываются.
  Future<bool> renameGroup(String chatId, String title) async {
    final me = myProfileId;
    if (me == null || title.trim().isEmpty) return false;
    try {
      await _client
          .from('chats')
          .update({'title': title.trim()})
          .eq('id', chatId);
      final ids = await chatMemberIds(chatId);
      for (final m in ids) {
        if (m == me) continue;
        unawaited(_sendRemote('u_$m', 'group_info', {'chat_id': chatId}));
      }
      _chatsController.add(null);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Выход из группы: убираем себя из участников и рассылаем событие.
  Future<bool> leaveGroup(String chatId) async {
    final me = myProfileId;
    if (me == null) return false;
    try {
      final ids = await chatMemberIds(chatId);
      final rest = ids.where((m) => m != me).toList();
      await _client.from('chats').update({'members': rest}).eq('id', chatId);
      for (final m in rest) {
        unawaited(_sendRemote('u_$m', 'group_info', {'chat_id': chatId}));
      }
      _chatsController.add(null);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> uploadAvatar(Uint8List bytes) async {
    if (myProfileId == null) return;
    final path = 'avatars/$myProfileId.png';
    await _client.storage.from('avatars').uploadBinary(
      path, 
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );
    await _client.from('profiles').update({'avatar_url': path}).eq('id', myProfileId!);
  }

  Future<Uint8List?> downloadMyAvatar() async {
    if (_myProfile?.avatar == null) return null;
    try {
      return await _client.storage.from('avatars').download('avatars/$myProfileId.png');
    } catch (_) { return null; }
  }

  /// Кэш подписанных URL: ключ — путь в бакете, значение — URL и срок.
  final _signedUrls = <String, ({String url, DateTime expires})>{};

  /// Резолвер приватных медиа: относительный путь (или старый публичный URL)
  /// превращает в подписанный URL через edge-функцию media-sign.
  ///
  /// Аргумент может быть:
  ///  - путём в бакете: `avatars/…`, `stories/…`, `media/…`, `messages/…`;
  ///  - старым публичным URL `…/storage/v1/object/public/avatars/<path>`;
  ///  - локальным путём файла (приводится как есть).
  Future<String?> mediaUrl(String? source) async {
    if (source == null || source.isEmpty) return null;
    var path = source;
    final publicIdx = source.indexOf('/storage/v1/object/public/avatars/');
    if (publicIdx >= 0) {
      path = source.substring(publicIdx + '/storage/v1/object/public/avatars/'.length);
    }
    final isBucketPath = path.startsWith('avatars/') ||
        path.startsWith('stories/') ||
        path.startsWith('media/') ||
        path.startsWith('messages/');
    if (!isBucketPath) return source;

    final cached = _signedUrls[path];
    if (cached != null && cached.expires.isAfter(DateTime.now())) return cached.url;

    try {
      final res = await _client.functions
          .invoke('media-sign', body: {'bucket': 'avatars', 'path': path});
      final data = res.data;
      final url = data is Map<String, dynamic> ? data['url'] as String? : null;
      if (url != null) {
        _signedUrls[path] = (
          url: url,
          expires: DateTime.now().add(const Duration(minutes: 50)),
        );
        return url;
      }
    } catch (_) {}
    return null;
  }

  /// Лента публичных сториз (чужие; свои клиент показывает локально).
  Future<List<VibeStory>> listStories() async {
    final myId = myProfileId;
    if (myId == null) return [];
    final res = await _client
        .from('stories')
        .select('*, author:profiles(display_name)')
        .neq('profile_id', myId)
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List)
        .map((row) => VibeStory.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Публикация стори: фото в storage + запись в stories.
  Future<void> uploadStory(Uint8List bytes) async {
    if (myProfileId == null) return;
    final path =
        'stories/$myProfileId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        upsert: false,
        contentType: 'image/jpeg',
      ),
    );
    await _client.from('stories').insert({
      'profile_id': myProfileId,
      'photo_url': path,
    });

    // Мгновенно обновляем карусель у всех: появилась новая история.
    unawaited(_dmChannel?.sendBroadcastMessage(
      event: 'new_story',
      payload: {'profile_id': myProfileId},
    ));
  }

  /// Удаление своей стори.
  Future<void> deleteStory(String storyId) async {
    if (myProfileId == null) return;
    await _client.from('stories').delete().eq('id', storyId);
  }

  Future<List<VibeChat>> listChats() async {
    if (myProfileId == null) return [];
    try {
      final res = await _client
          .from('chats')
          .select('*, messages(text, created_at)')
          .inFilter('kind', ['pm', 'group'])
          .contains('members', [myProfileId])
          .timeout(const Duration(seconds: 6));

      // ОПТИМИЗАЦИЯ: Собираем все ID участников одним списком, чтобы не делать 100 запросов
      final allMemberIds = <String>{};
      for (final c in res) {
        allMemberIds.addAll(List<String>.from(c['members']));
      }
      
      // Скачиваем все нужные профили одним запросом
      final List profilesRaw = await _client
          .from('profiles')
          .select('id,username,display_name,emoji,avatar_url,bio,online,uid')
          .inFilter('id', allMemberIds.toList());
      
      final profilesMap = {
        for (var p in profilesRaw) p['id']: VibeProfile.fromJson(p)
      };

      final chats = <VibeChat>[];
      final lastCreated = <String, DateTime>{};
      
      for (final c in res) {
        try {
          final kind = '${c['kind'] ?? 'pm'}';
          final members = List<String>.from(c['members']);
          final peerId = members.firstWhere(
            (m) => m != myProfileId,
            orElse: () => myProfileId!,
          );
          
          final peer = profilesMap[peerId];
          final peerName = peer?.displayName;
          final peerUsername = peer?.username ?? '';

          String title;
          if (kind == 'group') {
            final customTitle = c['title'] as String?;
            if (customTitle != null && customTitle.trim().isNotEmpty) {
              title = customTitle.trim();
            } else {
              final others = members.where((m) => m != myProfileId).toList();
              final names = <String>[];
              for (final mid in others.take(3)) {
                final p = profilesMap[mid];
                if (p?.displayName.isNotEmpty ?? false) {
                  names.add(p!.displayName);
                }
              }
              title = names.isEmpty ? 'Группа' : names.join(', ');
            }
          } else {
            title = (peerName?.isNotEmpty ?? false) ? peerName! : peerUsername;
          }

          final msgsRaws = c['messages'];
          final msgs = <Map<String, dynamic>>[
            if (msgsRaws is List) ...msgsRaws.cast<Map<String, dynamic>>(),
          ]..sort((a, b) => '${a['created_at'] ?? ''}'.compareTo('${b['created_at'] ?? ''}'));

          final last = msgs.isNotEmpty ? msgs.last : null;
          final lastSticker = last?['sticker_emoji'] as String?;
          final lastText = (lastSticker?.isNotEmpty ?? false)
              ? 'Стикер'
              : ((last?['text'] as String?) ??
                  (last == null ? 'Нет сообщений' : 'Медиа'));
          
          chats.add(VibeChat(
            id: c['id'],
            title: title,
            kind: kind,
            lastMessage: lastText,
            lastTime: last != null ? formatTime(last['created_at']) : '',
            unread: _unreadByChat['${c['id']}'] ?? 0,
            peerName: kind == 'group' ? title : peer?.displayName,
            peerAvatar: peer?.avatar,
            peerId: peer?.id,
            peerOnline: kind == 'pm' ? (peer?.online ?? false) : false,
            peerLastSeen: kind == 'pm' ? peer?.lastSeen : null,
          ));
          
          if (last?['created_at'] != null) {
            lastCreated[c['id']] = DateTime.parse(last!['created_at']);
          }
        } catch (_) {}
      }
      // Как в TG: чаты упорядочены по последнему сообщению.
      chats.sort((a, b) {
        final ta = lastCreated[a.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = lastCreated[b.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      unawaited(_refreshUnread());
      unawaited(_writeCache(
        _cacheChatsName,
        chats.map(_chatToCacheRow).toList(),
      ));
      return chats;
    } catch (e, st) {
      // Нет сети (или таймаут) — оффлайн-режим: отдаём кешированный список.
      debugPrint('listChats error: $e\n$st');
      unawaited(_syncConnectivity());
      final rows = await _readCache(_cacheChatsName);
      if (rows is List) {
        return rows
            .whereType<Map<String, dynamic>>()
            .map(_chatFromCacheRow)
            .toList();
      }
      return [];
    }
  }

  /// Время для превью чата: сегодня — ЧЧ:ММ, вчера — «Вчера», иначе дата.
  static String formatTime(dynamic raw) {
    final t = DateTime.tryParse('$raw')?.toLocal();
    if (t == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    if (day == today) return '$hh:$mm';
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == yesterday) return 'Вчера';
    return '${t.day.toString().padLeft(2, '0')}.'
        '${t.month.toString().padLeft(2, '0')}.'
        '${t.year.toString().substring(2)}';
  }

  /// Сообщения чата. `limit` — размер страницы; `before` — курсор
  /// (грузим сообщения старше этой даты, для пагинации вверх).
  Future<List<VibeMessage>> listMessages(
    String chatId, {
    int? limit,
    DateTime? before,
  }) async {
    try {
      final filter = _client
          .from('messages')
          .select('*, profiles!sender_id(*)')
          .eq('chat_id', chatId);
      final withCursor = before != null
          ? filter.lt('created_at', before.toUtc().toIso8601String())
          : filter;
      final ordered = withCursor.order('created_at', ascending: false);
      final req = limit != null ? ordered.limit(limit) : ordered;
      final res = await req.timeout(const Duration(seconds: 6));

      final raws = res as List;
      final msgs = raws
          .where((m) {
            // «Удалить для меня»: сообщение помечено author deleted_by —
            // такие не возвращаем владельцу пометки.
            final deletedBy = m['deleted_by'];
            if (myProfileId != null &&
                deletedBy is List &&
                deletedBy.contains(myProfileId)) {
              return false;
            }
            return true;
          })
          .map((m) {
        final sender = VibeProfile.fromJson(m['profiles']);
        return VibeMessage(
          id: m['id'],
          chatId: m['chat_id'],
          senderId: m['sender_id'],
          senderName: sender.displayName,
          senderAvatar: sender.avatar,
          text: m['text'],
          voicePath: m['voice_url'],
          photoPath: m['photo_url'],
          videoPath: m['video_url'],
          created: DateTime.parse(m['created_at']).toLocal(), // FORCE LOCAL TIME
          incoming: m['sender_id'] != myProfileId,
          edited: m['edited_at'] != null,
          forwardedFrom: m['forward_from'],
        );
      }).toList();
      // Защита от «пустой истории» после перезахода: если сервер вернул
      // пусто (кратковременный сбой/REST-нестабильность), а локально есть
      // история — показываем кэш и НЕ затираем его пустым списком.
      if (raws.isEmpty) {
        final rows = await _readCache(_cacheMsgsName(chatId));
        if (rows is List && rows.isNotEmpty) {
          return _messagesFromCacheRows(rows);
        }
      }
      unawaited(_writeCache(
        _cacheMsgsName(chatId),
        msgs.map(_messageToCacheRow).toList(),
      ));
      return msgs;
    } catch (_) {
      unawaited(_syncConnectivity());
      final rows = await _readCache(_cacheMsgsName(chatId));
      if (rows is List) return _messagesFromCacheRows(rows);
      return [];
    }
  }

  Future<VibeChat?> chatById(String chatId) async {
    if (myProfileId == null) return null;
    try {
      final c = await _client
          .from('chats')
          .select()
          .eq('id', chatId)
          .maybeSingle();
      if (c == null) return null;
      final members = List<String>.from(c['members']);
      final myIdNow = myProfileId!;
      // «Избранное»: личный чат с самим собой (Saved Messages в TG).
      final isSaved = (c['kind'] == 'pm' || c['kind'] == null) &&
          members.length == 1 &&
          members.first == myIdNow;
      final peerId = members.firstWhere(
        (m) => m != myProfileId,
        orElse: () => myProfileId!,
      );
      if (isSaved) {
        return VibeChat(
          id: c['id'],
          title: 'Избранное',
          kind: 'pm',
          lastMessage: '',
          lastTime: '',
          unread: 0,
          peerName: 'Избранное',
          peerAvatar: null,
          peerId: myIdNow,
          peerOnline: false,
          peerLastSeen: null,
        );
      }
      final peer = await profileById(peerId);
      return VibeChat(
        id: c['id'],
        title: peer?.displayName ?? 'Пользователь',
        kind: c['kind'] ?? 'pm',
        lastMessage: '',
        lastTime: '',
        unread: 0,
peerName: peer?.displayName,
        peerAvatar: peer?.avatar,
        peerId: peer?.id,
        peerOnline: peer?.online ?? false,
        peerLastSeen: peer?.lastSeen,
      );
    } catch (_) {
      return null;
    }
  }

/// Отправить текст: показываем сразу (часики), сервер подтверждает
  /// через долю секунды — галочка «отправлено». Задержка как в Telegram.
  Future<VibeMessage> sendText(
    String chatId,
    String text, {
    String? localId,
    String? replyText,
    String? replyAuthor,
  }) async {
    final lId = localId ?? _nextLocalId();
    final local = _ownLocal(
      chatId: chatId,
      localId: lId,
      text: text,
      status: MsgStatus.sending,
      replyText: replyText,
      replyAuthor: replyAuthor,
    );
    streamController.add(local);
    _chatsController.add(null);
    try {
      final row = await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': myProfileId,
        'text': text,
      }).select().single();
      _broadcastMessageRow(row);
      _chatsController.add(null);
      final sent = _ownMessage(row).copyWith(
        localId: lId,
        replyText: replyText,
        replyAuthor: replyAuthor,
        status: MsgStatus.sent,
      );
      _sentById['${row['id']}'] = sent;
      streamController.add(sent);
      return sent;
    } catch (_) {
      streamController.add(local.copyWith(status: MsgStatus.failed));
      rethrow;
    }
  }

  /// Отправить стикер (эмодзи-стикер с подложкой).
  Future<VibeMessage> sendSticker(
    String chatId,
    String emoji, {
    String? localId,
  }) async {
    final lId = localId ?? _nextLocalId();
    final local = _ownLocal(
      chatId: chatId,
      localId: lId,
      stickerEmoji: emoji,
      status: MsgStatus.sending,
    );
    streamController.add(local);
    _chatsController.add(null);
    try {
      final row = await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': myProfileId,
        'sticker_emoji': emoji,
      }).select().single();
      _broadcastMessageRow(row);
      _chatsController.add(null);
      final sent = _ownMessage(row).copyWith(
        localId: lId,
        status: MsgStatus.sent,
      );
      _sentById['${row['id']}'] = sent;
      streamController.add(sent);
      return sent;
    } catch (_) {
      streamController.add(local.copyWith(status: MsgStatus.failed));
      rethrow;
    }
  }

  /// Все стикер-паки со стикерами (для панели отправки).
  Future<List<VibeStickerPack>> listStickerPacks() async {
    try {
      final packsRaw = await _client
          .from('sticker_packs')
          .select('*, stickers(id, emoji)')
          .order('created_at', ascending: true);
      return [
        for (final p in packsRaw)
          VibeStickerPack(
            id: p['id'],
            title: p['title'],
            stickers: [
              for (final s in (p['stickers'] as List? ?? const []))
                VibeSticker(id: s['id'], emoji: s['emoji']),
            ],
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Отправить фото: файл в storage, ссылка — в сообщении.
  Future<VibeMessage> sendPhoto(
    String chatId,
    Uint8List bytes, {
    String? localId,
    String? localPath,
  }) async {
    final lId = localId ?? _nextLocalId();
    final local = _ownLocal(
      chatId: chatId,
      localId: lId,
      photoPath: localPath,
      status: MsgStatus.sending,
    );
    streamController.add(local);
    try {
      final path =
          'media/$chatId/photo_$myProfileId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );
      final row = await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': myProfileId,
        'photo_url': path,
      }).select().single();
      _broadcastMessageRow(row);
      _chatsController.add(null);
      final sent = _ownMessage(row).copyWith(
        localId: lId,
        status: MsgStatus.sent,
      );
      _sentById['${row['id']}'] = sent;
      streamController.add(sent);
      return sent;
    } catch (_) {
      streamController.add(local.copyWith(status: MsgStatus.failed));
      rethrow;
    }
  }

  /// Отправить файл-вложение: загрузка в storage + JSON-метаданные в text.
  /// Один бакет (`avatars`), путь `media/<chatId>/file_*` — media-sign уже
  /// разрешает префикс участникам чата.
  Future<VibeMessage> sendFile(
    String chatId,
    File file, {
    String? localId,
    String? localPath,
    String? mime,
  }) async {
    final lId = localId ?? _nextLocalId();
    final name = file.uri.pathSegments.isEmpty
        ? 'file'
        : file.uri.pathSegments.last;
    final mimeType = mime ?? _mimeByExtension(file.path);
    // Гифки — анимированное медиа (kind=gif), не карточка-файл.
    final kind = mimeType == 'image/gif'
        ? AttachmentKind.gif
        : AttachmentKind.file;
    final json = AttachmentData.encode(
      kind: kind,
      name: name,
      size: file.lengthSync(),
      mime: mimeType,
    );
    final local = _ownLocal(
      chatId: chatId,
      localId: lId,
      text: json,
      status: MsgStatus.sending,
    );
    streamController.add(local);
    try {
      final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path =
          'media/$chatId/file_$myProfileId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await _client.storage.from('avatars').upload(
            path,
            file,
            fileOptions: FileOptions(
              upsert: false,
              contentType: mime ?? _mimeByExtension(file.path),
            ),
          );
      final jsonWithUrl = AttachmentData.encode(
        kind: kind,
        name: name,
        size: file.lengthSync(),
        mime: mimeType,
        url: path,
      );
      final row = await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': myProfileId,
        'text': jsonWithUrl,
      }).select().single();
      _broadcastMessageRow(row);
      _chatsController.add(null);
      final sent = _ownMessage(row).copyWith(
        localId: lId,
        status: MsgStatus.sent,
      );
      _sentById['${row['id']}'] = sent;
      streamController.add(sent);
      return sent;
    } catch (_) {
      streamController.add(local.copyWith(status: MsgStatus.failed));
      rethrow;
    }
  }

  static String _mimeByExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    const map = {
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
      'zip': 'application/zip',
      'rar': 'application/vnd.rar',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'mp3': 'audio/mpeg',
      'mp4': 'video/mp4',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  /// Отправить голосовое сообщение (файл m4a).
  Future<VibeMessage> sendVoice(
    String chatId,
    File voiceFile, {
    String? localId,
    String? localPath,
    int? voiceSeconds,
  }) async {
    final lId = localId ?? _nextLocalId();
    final local = _ownLocal(
      chatId: chatId,
      localId: lId,
      voicePath: localPath,
      voiceSeconds: voiceSeconds,
      status: MsgStatus.sending,
    );
    streamController.add(local);
    try {
      // 5.5: стриминг файла в storage — без readAsBytes всего файла.
      final path =
          'media/$chatId/voice_$myProfileId/${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _client.storage.from('avatars').upload(
            path,
            voiceFile,
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'audio/mp4',
            ),
          );
      final row = await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': myProfileId,
        'voice_url': path,
      }).select().single();
      _broadcastMessageRow(row);
      _chatsController.add(null);
      final sent = _ownMessage(row).copyWith(
        localId: lId,
        voicePath: localPath ?? voiceFile.path,
        status: MsgStatus.sent,
      );
      _sentById['${row['id']}'] = sent;
      streamController.add(sent);
      return sent;
    } catch (_) {
      streamController.add(local.copyWith(status: MsgStatus.failed));
      rethrow;
    }
  }

  /// Отправить видеокружок (файл mp4).
  Future<VibeMessage> sendVideo(
    String chatId,
    File videoFile, {
    String? localId,
    String? localPath,
  }) async {
    final lId = localId ?? _nextLocalId();
    final local = _ownLocal(
      chatId: chatId,
      localId: lId,
      videoPath: localPath,
      status: MsgStatus.sending,
    );
    streamController.add(local);
    try {
      // 5.5: стриминг файла в storage — без readAsBytes всего файла.
      final path =
          'media/$chatId/video_$myProfileId/${DateTime.now().millisecondsSinceEpoch}.mp4';
      await _client.storage.from('avatars').upload(
            path,
            videoFile,
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'video/mp4',
            ),
          );
      final row = await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': myProfileId,
        'video_url': path,
      }).select().single();
      _broadcastMessageRow(row);
      _chatsController.add(null);
      final sent = _ownMessage(row).copyWith(
        localId: lId,
        videoPath: localPath ?? videoFile.path,
        status: MsgStatus.sent,
      );
      _sentById['${row['id']}'] = sent;
      streamController.add(sent);
      return sent;
    } catch (_) {
      streamController.add(local.copyWith(status: MsgStatus.failed));
      rethrow;
    }
  }

/// Собрать сообщение, которое отправил сам пользователь
  /// (без джойна по отправителю — профиль свой уже известен).
  VibeMessage _ownMessage(Map<String, dynamic> row) {
    final me = _myProfile;
    return VibeMessage(
      id: row['id'],
      chatId: row['chat_id'],
      senderId: row['sender_id'],
      senderName: me?.displayName ?? 'Вы',
      senderAvatar: me?.avatar,
      text: row['text'],
      voicePath: row['voice_url'],
      photoPath: row['photo_url'],
      videoPath: row['video_url'],
      created: DateTime.parse(row['created_at']),
      incoming: false,
      edited: row['edited_at'] != null,
      forwardedFrom: row['forward_from'],
      stickerEmoji: row['sticker_emoji'],
    );
  }

  int _localSeq = 0;
  String _nextLocalId() =>
      'l${DateTime.now().microsecondsSinceEpoch}_${_localSeq++}';

  /// Мгновенное локальное «своё» сообщение (до ответа сервера).
  VibeMessage _ownLocal({
    required String chatId,
    required String localId,
    String? text,
    String? voicePath,
    int? voiceSeconds,
    String? photoPath,
    String? videoPath,
    MsgStatus? status,
    String? replyText,
    String? replyAuthor,
    String? stickerEmoji,
  }) {
    final me = _myProfile;
    return VibeMessage(
      id: localId,
      chatId: chatId,
      senderId: myProfileId ?? '',
      senderName: me?.displayName ?? 'Вы',
      senderAvatar: me?.avatar,
      text: text,
      voicePath: voicePath,
      photoPath: photoPath,
      videoPath: videoPath,
      created: DateTime.now(),
      incoming: false,
      status: status ?? MsgStatus.sending,
      localId: localId,
      replyText: replyText,
      replyAuthor: replyAuthor,
      stickerEmoji: stickerEmoji,
    );
  }

  /// Реестр отправленных сообщений: id на сервере → сообщение с localId.
  /// Нужен, чтобы галочки «доставлено/прочитано» находили пузырёк на экране.
  final _sentById = <String, VibeMessage>{};

  /// Непрочитанные по каждому чату (из серверного RPC get_unread_counts).
  final Map<String, int> _unreadByChat = {};

  /// Суммарный счётчик непрочитанных — для бейджа на вкладке «Чаты».
  final ValueNotifier<int> chatsUnreadTotal = ValueNotifier<int>(0);

  void _publishUnread() {
    var total = 0;
    for (final v in _unreadByChat.values) {
      total += v;
    }
    if (chatsUnreadTotal.value != total) chatsUnreadTotal.value = total;
  }

  /// Запросить серверные счётчики непрочитанных. Если миграция read_states
  /// ещё не применена — функция тихо не работает (все счётчики 0).
  Future<void> _refreshUnread() async {
    final myId = myProfileId;
    if (myId == null) return;
    try {
      final res = await _client
          .rpc('get_unread_counts')
          .timeout(const Duration(seconds: 5));
      if (res is! List) return;
      final map = <String, int>{};
      for (final r in res) {
        if (r is Map) {
          final v = (r['unread'] as num?)?.toInt() ?? 0;
          if (v > 0) map['${r['chat_id']}'] = v;
        }
      }
      _unreadByChat
        ..clear()
        ..addAll(map);
      _publishUnread();
    } catch (_) {
      // Рантайм/нет сети/миграция не применена — молча пропускаем.
    }
  }

  /// Новое входящее сообщение в чат, который у меня не открыт — увеличить
  /// счётчик непрочитанных сразу (без ожидания перезагрузки списка).
  void _bumpUnread(String chatId) {
    _unreadByChat[chatId] = (_unreadByChat[chatId] ?? 0) + 1;
    _publishUnread();
  }

  /// Архив чатов (из облака): id чатов, где archived_at != null.
  final ValueNotifier<Set<String>> archivedNotifier = ValueNotifier({});

  /// DND (из облака): id чатов, где muted_until позже текущего момента.
  final ValueNotifier<Set<String>> mutedNotifier = ValueNotifier({});

  /// Загрузить с облака архив/DND и обновить нотификаторы.
  Future<void> _loadChatStates() async {
    final myId = myProfileId;
    if (myId == null) return;
    try {
      final res = await _client
          .rpc('get_my_chat_states')
          .timeout(const Duration(seconds: 5));
      if (res is! List) return;
      final archived = <String>{};
      final muted = <String>{};
      final now = DateTime.now();
      for (final r in res) {
        if (r is! Map) continue;
        final chatId = '${r['chat_id']}';
        final a = r['archived_at'];
        if (a != null && a.toString().isNotEmpty) archived.add(chatId);
        final mUntil = r['muted_until'];
        final until = mUntil == null
            ? null
            : DateTime.tryParse('$mUntil');
        if (until != null && until.isAfter(now)) muted.add(chatId);
      }
      archivedNotifier.value = archived;
      mutedNotifier.value = muted;
    } catch (_) {}
  }

  /// Перенести чат в архив / вернуть из архива (на сервере + локально).
  Future<void> setChatArchived(String chatId, {required bool archived}) async {
    final myId = myProfileId;
    if (myId == null) return;
    try {
      await _client.from('read_states').upsert({
        'chat_id': chatId,
        'user_id': myId,
        if (archived) 'archived_at': DateTime.now().toIso8601String()
        else 'archived_at': null,
      }, onConflict: 'chat_id,user_id');
    } catch (_) {}
    final set = {...archivedNotifier.value};
    if (archived) {
      set.add(chatId);
    } else {
      set.remove(chatId);
    }
    archivedNotifier.value = set;
  }

  /// Включить/выключить DND (muted_until на сервере). forever=true — без
  /// таймера (до выключения), иначе действует до указанного момента.
  Future<void> setChatMuted(
    String chatId, {
    required bool muted,
    bool forever = false,
    DateTime? until,
  }) async {
    final myId = myProfileId;
    if (myId == null) return;
    DateTime? target = muted ? (until ?? DateTime.now().add(const Duration(days: 36500))) : null;
    if (muted && !forever && until != null) target = until;
    if (!muted) target = null;
    try {
      await _client.from('read_states').upsert({
        'chat_id': chatId,
        'user_id': myId,
        'muted_until': target?.toIso8601String(),
      }, onConflict: 'chat_id,user_id');
    } catch (_) {}
    final set = {...mutedNotifier.value};
    if (muted) {
      set.add(chatId);
    } else {
      set.remove(chatId);
    }
    mutedNotifier.value = set;
  }

  /// Подписки realtime. Всё анонимно-безопасно:
  ///  - личный канал `u_<myId>` — только мои сообщения и новые чаты;
  ///  - глобальный канал — только публичная лента историй;
  ///  - postgres_changes — страховка с проверкой принадлежности чата.
  void subscribeMessages() {
    _dmChannel = _client.channel(_dmChannelName)
      ..onBroadcast(event: 'new_story', callback: (_) => _chatsController.add(null));
    _dmChannel!.subscribe();

    _ensurePersonalChannel();

    unawaited(_refreshUnread());
    unawaited(_loadChatStates());

    // Дубль-источник: postgres_changes (если таблица включена в
    // публикацию realtime на сервере). Также мгновенно, но каждое
    // событие проверяется на принадлежность чата мне.
    _client.channel('public:messages').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) async {
        final myId = myProfileId;
        final m = payload.newRecord;
        if (myId == null || m['sender_id'] == myId) return;
        final chatId = '${m['chat_id']}';
        if (chatId == 'null' || !await _isMyChat(chatId)) return;
        _onBroadcastMessage(m);
      },
    ).subscribe();

    // Страховка для правок и удалений (если таблица в публикации realtime):
    // бродкаст — основной канал, этот — резервный.
    final myIdSub = myProfileId;
    if (myIdSub != null) {
      _client.channel('public:messages:changes').onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        callback: (payload) async {
          final myId = myProfileId;
          final m = payload.newRecord;
          if (myId == null) return;
          final chatId = '${m['chat_id']}';
          if (chatId == 'null' || !await _isMyChat(chatId)) return;
          final msgId = '${m['id']}';
          final fromMe = '${m['sender_id']}' == myId;
          if (fromMe) return; // свои правки идут через _sentById/stream
          if (msgEventsController.isClosed) return;
          msgEventsController.add(VibeMsgEvent(
            type: VibeMsgEventType.edited,
            chatId: chatId,
            messageId: msgId,
            updated: VibeMessage(
              id: msgId,
              chatId: chatId,
              senderId: '${m['sender_id']}',
              senderName: '',
              senderAvatar: null,
              text: '${m['text'] ?? ''}',
              voicePath: null,
              photoPath: null,
              videoPath: null,
              created: DateTime.now(),
              incoming: true,
              edited: m['edited_at'] != null,
            ),
          ));
        },
      ).subscribe();

      _client.channel('public:messages:deleted').onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'messages',
        callback: (payload) async {
          final myId = myProfileId;
          final m = payload.oldRecord;
          if (myId == null) return;
          final chatId = '${m['chat_id']}';
          final msgId = '${m['id']}';
          if (chatId == 'null' || !await _isMyChat(chatId)) return;
          if (msgEventsController.isClosed) return;
          msgEventsController.add(VibeMsgEvent(
            type: VibeMsgEventType.deleted,
            chatId: chatId,
            messageId: msgId,
          ));
        },
      ).subscribe();

      // Реакции в реальном времени: кто-то поставил/снял — пересчитываем
      // счётчики чата и рассылаем обновления чат-экрану.
      _client.channel('public:reactions').onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'message_reactions',
        callback: (payload) async {
          final chatId = await _chatIdOfMessage('${payload.newRecord['message_id']}');
          if (chatId == 'null' || chatId.isEmpty || !await _isMyChat(chatId)) return;
          await refreshChatReactions(chatId);
        },
      ).subscribe();
      _client.channel('public:reactions:delete').onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'message_reactions',
        callback: (payload) async {
          final chatId = await _chatIdOfMessage('${payload.oldRecord['message_id']}');
          if (chatId == 'null' || chatId.isEmpty || !await _isMyChat(chatId)) return;
          await refreshChatReactions(chatId);
        },
      ).subscribe();

      // Закрепы в реальном времени: свои пины приходят тоже (отсекаем
      // дубли на стороне контроллера по факту изменения списка).
      _client.channel('public:chat_pins:insert').onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chat_pins',
        callback: (payload) async {
          final myId = myProfileId;
          final r = payload.newRecord;
          if (myId == null || '${r['pinned_by']}' == myId) return;
          final chatId = '${r['chat_id']}';
          if (chatId == 'null' || !await _isMyChat(chatId)) return;
          if (_pinEventsController.isClosed) return;
          _pinEventsController.add(PinChanged(
            chatId: chatId,
            messageId: '${r['message_id']}',
            pinned: true,
          ));
        },
      ).subscribe();
      _client.channel('public:chat_pins:delete').onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'chat_pins',
        callback: (payload) async {
          final myId = myProfileId;
          final r = payload.oldRecord;
          if (myId == null || '${r['pinned_by']}' == myId) return;
          final chatId = '${r['chat_id']}';
          if (chatId == 'null' || !await _isMyChat(chatId)) return;
          if (_pinEventsController.isClosed) return;
          _pinEventsController.add(PinChanged(
            chatId: chatId,
            messageId: '${r['message_id']}',
            pinned: false,
          ));
        },
      ).subscribe();
    }
  }

  /// Чат, в котором лежит сообщение (для событий реакций).
  Future<String> _chatIdOfMessage(String messageId) async {
    if (messageId.isEmpty || messageId == 'null') return '';
    try {
      final row = await _client
          .from('messages')
          .select('chat_id')
          .eq('id', messageId)
          .single();
      return '${(row as Map)['chat_id']}';
    } catch (_) {
      return '';
    }
  }

  /// Личный канал `u_<myId>`: пересоздаётся при смене аккаунта.
  void _ensurePersonalChannel() {
    final myId = myProfileId;
    if (myId == null || _personalName == 'u_$myId') return;
    final old = _personal;
    if (old != null) {
      _client.removeChannel(old);
    }
    _personalName = 'u_$myId';
_personal = _client.channel('u_$myId')
      ..onBroadcast(event: 'new_message', callback: _onBroadcastMessage)
      ..onBroadcast(event: 'new_chat', callback: (m) {
        final senderId = m['sender_id'] ?? (m['payload'] is Map
            ? (m['payload'] as Map)['sender_id']
            : null);
        if (senderId == myId) return;
        _chatsController.add(null);
      })
      ..onBroadcast(event: 'delivered', callback: (m) {
        // Галочка «доставлено»: устройство собеседника получило сообщение.
        final inner = m['payload'];
        final data = (inner is Map<String, dynamic> ||
                inner is Map<dynamic, dynamic>)
            ? Map<String, dynamic>.from(inner as Map)
            : m;
        final id = '${data['message_id']}';
        final sent = _sentById[id];
        if (sent == null || sent.status == MsgStatus.read) return;
        final updated = sent.copyWith(status: MsgStatus.delivered);
        _sentById[id] = updated;
        if (!streamController.isClosed) {
          streamController.add(updated);
        }
      })
      ..onBroadcast(event: 'read', callback: (m) {
        // Галочка «прочитано»: собеседник открыл чат (до этого момента).
        final inner = m['payload'];
        final data = (inner is Map<String, dynamic> ||
                inner is Map<dynamic, dynamic>)
            ? Map<String, dynamic>.from(inner as Map)
            : m;
        final chatId = '${data['chat_id']}';
        final at = DateTime.tryParse('${data['at']}') ?? DateTime.now();
        final ids = _sentById.entries.where((e) {
          final v = e.value;
          return v.chatId == chatId &&
              v.created.isBefore(at) &&
              v.status != MsgStatus.read;
        }).map((e) => e.key).toList();
        for (final id in ids) {
          final updated = _sentById[id]!.copyWith(status: MsgStatus.read);
          _sentById[id] = updated;
          if (!streamController.isClosed) {
            streamController.add(updated);
          }
        }
      })
      ..onBroadcast(event: 'edit_message', callback: (m) {
        // Собеседник исправил сообщение — пузырь обновляется на лету.
        final inner = m['payload'];
        final data = (inner is Map<String, dynamic> ||
                inner is Map<dynamic, dynamic>)
            ? Map<String, dynamic>.from(inner as Map)
            : m;
        final msgId = '${data['id']}';
        final chatId = '${data['chat_id']}';
        if (msgId.isEmpty || chatId.isEmpty) return;
        if (msgEventsController.isClosed) return;
        msgEventsController.add(VibeMsgEvent(
          type: VibeMsgEventType.edited,
          chatId: chatId,
          messageId: msgId,
          updated: VibeMessage(
            id: msgId,
            chatId: chatId,
            senderId: '${data['sender_id']}',
            senderName: '',
            senderAvatar: null,
            text: '${data['text']}',
            voicePath: null,
            photoPath: null,
            videoPath: null,
            created: DateTime.now(),
            incoming: true,
            edited: true,
          ),
        ));
        _chatsController.add(null);
      })
      ..onBroadcast(event: 'delete_message', callback: (m) {
        // Собеседник удалил своё сообщение — прячем пузырь.
        final inner = m['payload'];
        final data = (inner is Map<String, dynamic> ||
                inner is Map<dynamic, dynamic>)
            ? Map<String, dynamic>.from(inner as Map)
            : m;
        final msgId = '${data['id']}';
        final chatId = '${data['chat_id']}';
        if (msgId.isEmpty || chatId.isEmpty) return;
        if (msgEventsController.isClosed) return;
        msgEventsController.add(VibeMsgEvent(
          type: VibeMsgEventType.deleted,
          chatId: chatId,
          messageId: msgId,
        ));
        _chatsController.add(null);
      })
      ..onBroadcast(event: 'clear_history', callback: (m) {
        final inner = m['payload'];
        final data = (inner is Map<String, dynamic> ||
                inner is Map<dynamic, dynamic>)
            ? Map<String, dynamic>.from(inner as Map)
            : m;
        final chatId = '${data['chat_id']}';
        if (chatId.isEmpty) return;
        if (msgEventsController.isClosed) return;
        msgEventsController.add(VibeMsgEvent(
          type: VibeMsgEventType.cleared,
          chatId: chatId,
        ));
        _chatsController.add(null);
      })
      ..onBroadcast(event: 'typing', callback: (m) {
        // Собеседник печатает — показываем «печатает…» в шапке.
        final inner = m['payload'];
        final data = (inner is Map<String, dynamic> ||
                inner is Map<dynamic, dynamic>)
            ? Map<String, dynamic>.from(inner as Map)
            : m;
        final chatId = '${data['chat_id']}';
        if (chatId.isEmpty || _typingController.isClosed) return;
        _typingController.add(chatId);
      });
    _personal!.subscribe();
  }

  /// События «печатает…»: chatId собеседника.
  final _typingController = StreamController<String>.broadcast();
  Stream<String> get typingEvents => _typingController.stream;

  /// Сообщить собеседникам чата, что я печатаю (для PM и групп).
  /// UI сам сглаживает частоту вызовов.
  Future<void> sendTyping(String chatId) async {
    final me = myProfileId;
    if (me == null) return;
    final ids = await chatMemberIds(chatId);
    final others = ids.where((m) => m != me).toList();
    for (final m in others) {
      unawaited(_sendRemote('u_$m', 'typing', {'chat_id': chatId}));
    }
  }

  void _onBroadcastMessage(Map<String, dynamic> m) {
    // Realtime v2-протокол: данные лежат во вложенном payload.
    final inner = m['payload'];
    final data = (inner is Map<String, dynamic> ||
            inner is Map<dynamic, dynamic>)
        ? Map<String, dynamic>.from(inner as Map)
        : m;
    final senderId = data['sender_id'];
    final myId = myProfileId;
    if (myId == null || senderId == null || senderId == myId) return;
    debugPrint('RTX incoming: id=${data['id']} chat=${data['chat_id']} '
        'sender=$senderId text=${data['text']}');
    final id = '${data['id']}';
    if (_seenIds.contains(id)) return;
    _seenIds.add(id);
    if (_seenIds.length > 400) _seenIds.remove(_seenIds.first);

unawaited(() async {
      final sender = await profileById(senderId);
      if (!streamController.isClosed) {
        streamController.add(VibeMessage(
          id: id,
          chatId: '${data['chat_id']}',
          senderId: senderId,
          senderName: sender?.displayName ?? 'Пользователь',
          senderAvatar: sender?.avatar,
          text: data['text'],
          voicePath: data['voice_url'],
          photoPath: data['photo_url'],
          videoPath: data['video_url'],
          created: DateTime.tryParse('${data['created_at']}')?.toLocal() ?? DateTime.now(), // FORCE LOCAL TIME
          incoming: true,
          stickerEmoji: data['sticker_emoji'],
        ));
      }
      // Квитанции отправителю: «доставлено» — всегда, когда моё устройство
      // получило сообщение; «прочитано» — если чат сейчас открыт у меня.
      final chatId = '${data['chat_id']}';
      _ackDelivered(id, chatId, senderId);
      if (NotificationService.instance.activeChatId == chatId) {
        markChatRead(chatId);
      } else {
        _bumpUnread(chatId);
      }
    }());
  }

  /// Отправить квитанцию отправителю (на его личный канал).
  /// Канал НЕ подписываем — только REST-доставка (httpSend), ничего не
  /// «подслушивая».
  Future<void> _ackTo(
      String senderId, String event, Map<String, dynamic> payload) async {
    if (senderId.isEmpty || senderId == myProfileId) return;
    await _sendRemote('u_$senderId', event, payload);
  }

  void _ackDelivered(String msgId, String chatId, String senderId) {
    unawaited(_ackTo(senderId, 'delivered', {
      'message_id': msgId,
      'chat_id': chatId,
    }));
  }

  /// «Прочитано»: мой чат открыт, отправитель увидит синие галочки
  /// у всех своих сообщений до этого момента. Плюс серверный read_state:
  /// непрочитанный счётчик чата обнуляется (для бейджа на вкладке «Чаты»).
  Future<void> markChatRead(String chatId) async {
    final peerId = await _peerIdOf(chatId);
    if (peerId == null) return;
    unawaited(_ackTo(peerId, 'read', {
      'chat_id': chatId,
      'at': DateTime.now().toIso8601String(),
    }));

    final myId = myProfileId;
    if (myId == null) return;
    try {
      await _client.from('read_states').upsert({
        'chat_id': chatId,
        'user_id': myId,
        'last_read_at': DateTime.now().toIso8601String(),
      }, onConflict: 'chat_id,user_id');
    } catch (_) {
      // Миграция read_states не применена на сервере — молча пропускаем.
    }
    if (_unreadByChat.containsKey(chatId)) {
      _unreadByChat[chatId] = 0;
      _publishUnread();
      _chatsController.add(null);
    }
  }

  /// Переключить свою реакцию на сообщении (как в Telegram):
  /// повторный тап той же эмодзи — снять, другая — заменить.
  Future<void> setReaction(
    String chatId,
    String messageId,
    String emoji,
  ) async {
    final myId = myProfileId;
    if (myId == null) return;
    try {
      final mine = await _client
          .from('message_reactions')
          .select('emoji')
          .eq('message_id', messageId)
          .eq('user_id', myId);
      final mineEmojis = mine
          .map((r) => '${(r as Map)['emoji']}')
          .toSet();
      if (mineEmojis.contains(emoji)) {
        await _client
            .from('message_reactions')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', myId)
            .eq('emoji', emoji);
      } else {
        await _client.from('message_reactions').upsert({
          'message_id': messageId,
          'user_id': myId,
          'emoji': emoji,
        }, onConflict: 'message_id,user_id,emoji');
      }
      // Обновлённые счётчики разойдутся по realtime (insert/delete).
    } catch (_) {
      // Миграция message_reactions не применена — молча пропускаем.
    }
  }

  /// Загрузить актуальные реакции чата (для первичного показа и после
  /// realtime-изменений) и разослать их чат-экрану.
  Future<void> refreshChatReactions(String chatId) async {
    if (myProfileId == null) return;
    try {
      final res = await _client
          .rpc('get_message_reactions', params: {'chat': chatId})
          .timeout(const Duration(seconds: 5));
      if (res is! List) return;
      final grouped = <String, Map<String, int>>{};
      for (final r in res) {
        if (r is! Map) continue;
        final mid = '${r['message_id']}';
        final emoji = '${r['emoji']}';
        final cnt = (r['cnt'] as num?)?.toInt() ?? 1;
        grouped
            .putIfAbsent(mid, () => {})[emoji] = cnt;
      }
      if (msgEventsController.isClosed) return;
      for (final entry in grouped.entries) {
        msgEventsController.add(VibeMsgEvent(
          type: VibeMsgEventType.reactions,
          chatId: chatId,
          messageId: entry.key,
          reactions: entry.value,
        ));
      }
    } catch (_) {}
  }

  /// Закрепы чата (новые сверху). Если таблица chat_pins недоступна
  /// (миграция не применена) — бросает, контроллер остаётся на локальном
  /// списке (деградация без фейков).
  Future<List<String>> fetchChatPins(String chatId) async {
    final rows = await _client
        .from('chat_pins')
        .select('message_id')
        .eq('chat_id', chatId)
        .order('created_at', ascending: false);
    return rows.map((r) => '${(r as Map)['message_id']}').toList();
  }

  /// Закрепить сообщение в облаке (новый закреп — сверху).
  Future<void> pinMessage(String chatId, String messageId) async {
    final myId = myProfileId;
    if (myId == null) return;
    await _client.from('chat_pins').upsert({
      'chat_id': chatId,
      'message_id': messageId,
      'pinned_by': myId,
    }, onConflict: 'chat_id,message_id');
  }

  /// Снять закреп в облаке.
  Future<void> unpinMessage(String chatId, String messageId) async {
    final myId = myProfileId;
    if (myId == null) return;
    await _client
        .from('chat_pins')
        .delete()
        .eq('chat_id', chatId)
        .eq('message_id', messageId)
        .eq('pinned_by', myId);
  }

  /// Отправить broadcast событие на ЧУЖОЙ личный канал `u_<id>`.
  ///
  /// Канал не подписываем (чужой трафик нам не нужен), поэтому используем
  /// явный [RealtimeChannel.httpSend] (REST-эндпоинт realtime, гарантирует
  /// доставку без подписки). `sendBroadcastMessage` на неподписанном канале
  /// сам падает в REST-фолбэк, который на сервере реально НЕ доставляет
  /// событие (проверено пробником) — собеседник не видит сообщение.
  Future<void> _sendRemote(
    String peerTopic,
    String event,
    Map<String, dynamic> payload,
  ) async {
    if (peerTopic.isEmpty || peerTopic == 'u_' || peerTopic == 'u_null') return;
    try {
      await _client
          .channel(peerTopic)
          .httpSend(event: event, payload: payload);
    } catch (_) {
      // Оффлайн/сеть — событие доедет следующей перезагрузкой списка.
    }
  }

/// Отправить broadcast о новом сообщении (мгновенная доставка).
  /// Личные каналы получателей — чужие события не доставляются.
  /// Групповой чат: уведомляем каждого участника, кроме отправителя.
  void _broadcastMessageRow(Map<String, dynamic> row) {
    final chatId = '${row['chat_id']}';
    unawaited(() async {
      final members = await chatMemberIds(chatId);
      if (members.isEmpty) return;
      final senderId = '${row['sender_id']}';
      final payload = {
        'id': row['id'],
        'chat_id': chatId,
        'sender_id': senderId,
        'text': row['text'],
        'photo_url': row['photo_url'],
        'voice_url': row['voice_url'],
        'video_url': row['video_url'],
        'sticker_emoji': row['sticker_emoji'],
        'created_at': row['created_at'],
        'forward_from': row['forward_from'],
      };
      if (members.length > 2) {
        // Группа: каждому участнику, кроме автора.
        for (final m in members) {
          if (m == senderId) continue;
          await _sendRemote('u_$m', 'new_message', payload);
        }
        return;
      }
      final peerId = members.firstWhere(
        (m) => m != myProfileId,
        orElse: () => myProfileId ?? '',
      );
      if (peerId.isEmpty || peerId == myProfileId) return;
      await _sendRemote('u_$peerId', 'new_message', payload);
    }());
  }

  /// Разослать событие (правка/удаление/очистка) всем участникам чата,
  /// кроме инициатора. Тот же принцип, что у _broadcastMessageRow.
  void _dispatchToMembers(
    String chatId,
    String event,
    Map<String, dynamic> payload,
  ) {
    final myId = myProfileId;
    if (myId == null) return;
    unawaited(() async {
      final members = await chatMemberIds(chatId);
      for (final m in members) {
        if (m == myId) continue;
        await _sendRemote('u_$m', event, payload);
      }
    }());
  }

  /// Клиент может скинуть сигнал «обнови список» (например, свой send).
  void notifyChatsChanged() => _chatsController.add(null);

  /// Редактирование своего текстового сообщения (как в Telegram).
  /// Меняет только чужие нельзя: `sender_id = myProfileId` в условии.
  /// Возвращает null, если сообщение не найдено или оно не ваше.
  Future<VibeMessage?> updateMessage(
    String messageId,
    String newText,
  ) async {
    final myId = myProfileId;
    if (myId == null) return null;
    final before = await _client
        .from('messages')
        .select('text,chat_id')
        .eq('id', messageId)
        .eq('sender_id', myId)
        .maybeSingle();
    if (before == null) return null;
    // Снимок старого текста в историю правок (как в Telegram).
    final oldText = (before['text'] as String?) ?? '';
    if (oldText.isNotEmpty) {
      final chatIdNow = (before['chat_id'] as String?) ?? '';
      if (chatIdNow.isNotEmpty) {
        await _client.from('message_edits').insert({
          'message_id': messageId,
          'text': oldText,
          'edited_at': DateTime.now().toIso8601String(),
        });
      }
    }
    final row = await _client
        .from('messages')
        .update({
          'text': newText,
          'edited_at': DateTime.now().toIso8601String(),
        })
        .eq('id', messageId)
        .eq('sender_id', myId)
        .select()
        .maybeSingle();
    if (row == null) return null;

    final updated = _ownMessage(row).copyWith(edited: true);
    _sentById['${row['id']}'] = updated;
    _chatsController.add(null);
    if (!streamController.isClosed) {
      streamController.add(updated);
    }
    // Другим участникам: сообщение изменено (их клиент обновит пузырь).
    _dispatchToMembers('${row['chat_id']}', 'edit_message', {
      'id': row['id'],
      'chat_id': row['chat_id'],
      'text': newText,
      'sender_id': myId,
    });
    return updated;
  }

  /// История правок сообщения (снимки текста, от новых к старым).
  Future<List<MessageEdit>> listMessageEdits(String messageId) async {
    try {
      final res = await _client
          .from('message_edits')
          .select('message_id,text,edited_at')
          .eq('message_id', messageId)
          .order('edited_at', ascending: false)
          .limit(50);
      return [
        for (final r in res)
          MessageEdit(
            messageId: '${r['message_id']}',
            text: '${r['text']}',
            editedAt: DateTime.tryParse('${r['edited_at']}') ??
                DateTime.now(),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Удаление сообщения «для всех» (только своих).
  /// Чужие сообщения клиент скрывает локально — сервер их не трогает.
  /// Возвращает true, если удаление произошло.
  Future<bool> deleteMessage(String messageId) async {
    final myId = myProfileId;
    if (myId == null) return false;
    final res = await _client
        .from('messages')
        .delete()
        .eq('id', messageId)
        .eq('sender_id', myId)
        .select('id, chat_id');
    if (res.isEmpty) return false;
    final chatId = '${(res.first as Map)['chat_id']}';
    _sentById.remove(messageId);
    _chatsController.add(null);
    _dispatchToMembers(chatId, 'delete_message', {
      'id': messageId,
      'chat_id': chatId,
    });
    return true;
  }

  /// «Удалить для меня» (серверная часть): добавляет мой id в `deleted_by`
  /// сообщения — оно остаётся у других, но не возвращается мне при загрузке.
  Future<void> hideMessageForMe(String messageId) async {
    final myId = myProfileId;
    if (myId == null) return;
    try {
      final row = await _client
          .from('messages')
          .select('deleted_by')
          .eq('id', messageId)
          .maybeSingle();
      if (row == null) return;
      final list = List<String>.from(row['deleted_by'] ?? const []);
      if (list.contains(myId)) return;
      list.add(myId);
      await _client
          .from('messages')
          .update({'deleted_by': list})
          .eq('id', messageId);
    } catch (_) {
      // Клиент уже скрыл сообщение локально; серверная пометка
      // повторится при следующей загрузке (не критично).
    }
  }

  /// «Очистить историю»: удаляет все сообщения чата (как в Telegram).
  /// Доступно участнику чата: сначала проверяем принадлежность.
  Future<void> clearHistory(String chatId) async {
    final myId = myProfileId;
    if (myId == null) return;
    if (!await _isMyChat(chatId)) return;
    await _client
        .from('messages')
        .delete()
        .eq('chat_id', chatId);
    _chatsController.add(null);
    _dispatchToMembers(chatId, 'clear_history', {
      'chat_id': chatId,
    });
  }

  /// Переслать сообщение в другой чат: серверная копия с пометкой
  /// «Переслано от …» (как в Telegram). Возвращает новое сообщение.
  Future<VibeMessage?> forwardMessage(
    String targetChatId,
    VibeMessage original,
  ) async {
    final myId = myProfileId;
    if (myId == null || !await _isMyChat(targetChatId)) return null;
    final row = await _client.from('messages').insert({
      'chat_id': targetChatId,
      'sender_id': myId,
      'text': original.text,
      'photo_url': original.photoPath,
      'voice_url': original.voicePath,
      'video_url': original.videoPath,
      'sticker_emoji': original.stickerEmoji,
      'forward_from': original.senderName,
    }).select().single();
    _broadcastMessageRow(row);
    _chatsController.add(null);
    final sent = _ownMessage(row).copyWith(
      forwardedFrom: original.senderName,
      status: MsgStatus.sent,
    );
    _sentById['${row['id']}'] = sent;
    if (!streamController.isClosed) {
      streamController.add(sent);
    }
    return sent;
  }

  /// Удалить аватар с сервера (из storage и из поля avatar_url).
  Future<void> removeRemoteAvatar() async {
    if (myProfileId == null) return;
    try {
      await _client.storage
          .from('avatars')
          .remove(['avatars/$myProfileId.png']);
    } catch (_) {}
    await _client
        .from('profiles')
        .update({'avatar_url': null})
        .eq('id', myProfileId!);
  }

  Future<void> updateFcmToken(String token) async {
    if (myProfileId == null) return;
    await _client.from('profiles').update({'fcm_token': token}).eq('id', myProfileId!);
  }
}

/// Кэш профиля (5 минут): чтобы realtime и список чатов не дёргали сеть
/// на каждый чих — профили почти не меняются.
class _CachedProfile {
  _CachedProfile(this.profile, this.expiresAt);

  final VibeProfile profile;
  final DateTime expiresAt;
}

/// Кэш собеседника/принадлежности чата (5 минут).
class _CachedPeer {
  _CachedPeer(this.peerId, this.expiresAt);

  final String? peerId;
  final DateTime expiresAt;
}

