import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/backend_api.dart';

/// In-memory фейк `VibeBackendApi` для unit-тестов контроллеров:
/// хранит чаты/сообщения в памяти и позволяет эмитить realtime-события
/// вручную (как это делает живой websocket).
class FakeVibeBackend implements VibeBackendApi {
  final streamCtrl = StreamController<VibeMessage>.broadcast();
  final msgEventsCtrl = StreamController<VibeMsgEvent>.broadcast();
  final typingCtrl = StreamController<String>.broadcast();
  final chatEventsCtrl = StreamController<void>.broadcast();
  final pinEventsCtrl = StreamController<PinChanged>.broadcast();

  final presenceNotifier = ValueNotifier<int>(0);
  @override
  final ValueNotifier<Set<String>> archivedNotifier = ValueNotifier({});
  @override
  final ValueNotifier<Set<String>> mutedNotifier = ValueNotifier({});

  @override
  final ValueNotifier<int> connectivityVersion = ValueNotifier<int>(0);

  @override
  bool get isOffline => false;

  /// Заготовка для ленты сториз (экран списка читает для кружков).
  List<VibeStory> stories = [];

  @override
  Future<List<VibeStory>> listStories() async {
    calls.add('listStories');
    return List.of(stories);
  }

  /// Лента сообщений чата (newest-first), как возвращает бэкенд.
  final Map<String, List<VibeMessage>> messagesByChat = {};

  /// Живая лента чатов (`listChats`) и офлайн-кэш.
  List<VibeChat> chatList = [];
  List<VibeChat> offlineCache = [];

  // ─── Журнал вызовов ───
  final List<String> calls = [];
  String? lastTextSent;
  String? lastReplyText;
  String? lastReplyAuthor;
  String? lastStickerSent;
  int markReadCalls = 0;
  int refreshReactionsCalls = 0;
  int sendTypingCalls = 0;
  final List<({String id, bool archived})> setArchivedCalls = [];
  final List<({String id, bool muted})> setMutedCalls = [];
  final List<String> deleteCalls = [];
  final List<({String chatId, String messageId, String emoji})> reactions =
      [];
  String? lastUpdatedMessageId;
  String? lastUpdatedText;

  /// Если true — `sendText` бросает исключение (эмуляция сетевой ошибки).
  bool throwOnSendText = false;

  // ─── Приватность (3.7) ───
  PrivacySettings? privacySettings;
  bool throwOnFetchPrivacy = false;
  bool throwOnSavePrivacy = false;
  final List<PrivacySettings> savedPrivacy = [];

  @override
  Future<PrivacySettings?> fetchPrivacy() async {
    calls.add('fetchPrivacy');
    if (throwOnFetchPrivacy) throw Exception('no profile_privacy table');
    return privacySettings;
  }

  @override
  Future<void> savePrivacy(PrivacySettings settings) async {
    calls.add('savePrivacy');
    if (throwOnSavePrivacy) throw Exception('network');
    privacySettings = settings;
    savedPrivacy.add(settings);
  }

  /// Если true — `sendText` эмитит подтверждённое сообщение в `stream`
  /// (как живой бэкенд). Выключите, чтобы проверить оптимистичный статус.
  bool emitOnSend = true;

  @override
  Stream<VibeMessage> get stream => streamCtrl.stream;

  @override
  Stream<VibeMsgEvent> get msgEvents => msgEventsCtrl.stream;

  @override
  Stream<String> get typingEvents => typingCtrl.stream;

  @override
  Stream<void> get chatEvents => chatEventsCtrl.stream;

  @override
  Stream<PinChanged> get pinEvents => pinEventsCtrl.stream;

  /// Закрепы чата: messageId → «закреплён». Новые пины — в конец списка.
  final Map<String, List<String>> pinsByChat = {};
  /// Если true — fetchChatPins бросает (миграция не применена / сеть).
  bool throwOnFetchPins = false;
  final List<({String chatId, String messageId})> pinCalls = [];
  final List<({String chatId, String messageId})> unpinCalls = [];

  @override
  Future<List<String>> fetchChatPins(String chatId) async {
    calls.add('fetchChatPins:$chatId');
    if (throwOnFetchPins) throw Exception('no chat_pins table');
    return List.of(pinsByChat[chatId] ?? const []);
  }

  @override
  Future<void> pinMessage(String chatId, String messageId) async {
    pinCalls.add((chatId: chatId, messageId: messageId));
    pinsByChat.putIfAbsent(chatId, () => []).add(messageId);
  }

  @override
  Future<void> unpinMessage(String chatId, String messageId) async {
    unpinCalls.add((chatId: chatId, messageId: messageId));
    pinsByChat[chatId]?.remove(messageId);
  }

  @override
  ValueListenable<int> get presenceVersion => presenceNotifier;

  // ─── Чаты ───
  @override
  Future<List<VibeChat>> listChats() async {
    calls.add('listChats');
    return List.of(chatList);
  }

  @override
  Future<List<VibeChat>> getOfflineChats() async {
    calls.add('getOfflineChats');
    return List.of(offlineCache);
  }

  // ─── Сообщения ───
  @override
  Future<List<VibeMessage>> listMessages(
    String chatId, {
    int? limit,
    DateTime? before,
  }) async {
    calls.add('listMessages($chatId)');
    var list = messagesByChat[chatId] ?? const <VibeMessage>[];
    if (before != null) {
      list = list.where((m) => m.created.isBefore(before)).toList();
    }
    if (limit != null && list.length > limit) {
      list = list.sublist(0, limit);
    }
    return List.of(list);
  }

  @override
  Future<VibeMessage> sendText(
    String chatId,
    String text, {
    String? localId,
    String? replyText,
    String? replyAuthor,
  }) async {
    if (throwOnSendText) {
      calls.add('sendText($chatId)');
      throw Exception('network');
    }
    calls.add('sendText($chatId)');
    lastTextSent = text;
    lastReplyText = replyText;
    lastReplyAuthor = replyAuthor;
    final sent = _sent(
      chatId,
      text: text,
      localId: localId,
      status: MsgStatus.sent,
    );
    if (emitOnSend) streamCtrl.add(sent);
    return sent;
  }

  @override
  Future<VibeMessage> sendSticker(
    String chatId,
    String emoji, {
    String? localId,
  }) async {
    calls.add('sendSticker($chatId)');
    lastStickerSent = emoji;
    final sent = _sent(
      chatId,
      stickerEmoji: emoji,
      localId: localId,
      status: MsgStatus.sent,
    );
    streamCtrl.add(sent);
    return sent;
  }

  @override
  Future<VibeMessage> sendPhoto(
    String chatId,
    Uint8List bytes, {
    String? localId,
    String? localPath,
  }) async {
    calls.add('sendPhoto($chatId)');
    final sent = _sent(
      chatId,
      photoPath: 'media/$chatId/photo.jpg',
      localId: localId,
      status: MsgStatus.sent,
      created: DateTime.now(),
    );
    streamCtrl.add(sent);
    return sent;
  }

  @override
  Future<VibeMessage> sendVoice(
    String chatId,
    File voiceFile, {
    String? localId,
    String? localPath,
    int? voiceSeconds,
  }) async {
    calls.add('sendVoice($chatId)');
    final sent = _sent(
      chatId,
      voicePath: localPath ?? voiceFile.path,
      localId: localId,
      status: MsgStatus.sent,
    );
    streamCtrl.add(sent);
    return sent;
  }

  @override
  Future<VibeMessage> sendVideo(
    String chatId,
    File videoFile, {
    String? localId,
    String? localPath,
  }) async {
    calls.add('sendVideo($chatId)');
    final sent = _sent(
      chatId,
      videoPath: localPath ?? videoFile.path,
      localId: localId,
      status: MsgStatus.sent,
    );
    streamCtrl.add(sent);
    return sent;
  }

  @override
  Future<VibeMessage?> updateMessage(String messageId, String newText) async {
    calls.add('updateMessage($messageId)');
    lastUpdatedMessageId = messageId;
    lastUpdatedText = newText;
    return _sent(
      'x',
      text: newText,
      id: messageId,
      status: MsgStatus.sent,
    );
  }

  final Map<String, List<MessageEdit>> messageEditsByMessage = {};

  @override
  Future<List<MessageEdit>> listMessageEdits(String messageId) async {
    calls.add('listMessageEdits($messageId)');
    return List.of(messageEditsByMessage[messageId] ?? const []);
  }

  @override
  Future<bool> deleteMessage(String messageId) async {
    calls.add('deleteMessage($messageId)');
    deleteCalls.add(messageId);
    return true;
  }

  final List<String> hiddenMessageIds = [];

  @override
  Future<void> hideMessageForMe(String messageId) async {
    calls.add('hideMessageForMe($messageId)');
    hiddenMessageIds.add(messageId);
  }

  final List<String> clearHistoryCalls = [];

  @override
  Future<void> clearHistory(String chatId) async {
    calls.add('clearHistory($chatId)');
    clearHistoryCalls.add(chatId);
  }

  // ─── Прочее (экраны: пересылка, «Сохранить в Избранное») ───
  @override
  String? get myProfileId => 'me';

  @override
  Future<String> ensureSavedChat() async {
    calls.add('ensureSavedChat');
    return 'saved';
  }

  final List<({String chatId, String text})> forwardCalls = [];

  @override
  Future<VibeMessage?> forwardMessage(
    String targetChatId,
    VibeMessage original,
  ) async {
    calls.add('forwardMessage($targetChatId)');
    forwardCalls.add((chatId: targetChatId, text: original.text ?? ''));
    return _sent(
      targetChatId,
      text: original.text,
      forwardedFrom: original.senderName,
    );
  }

  // ─── Профиль ───
  final Set<String> takenUsernames = {};
  int updateProfileCalls = 0;
  String? lastUsernameUpdated;

  @override
  Future<bool> isUsernameAvailable(String username) async {
    calls.add('isUsernameAvailable($username)');
    return !takenUsernames.contains(username.trim().toLowerCase());
  }

  // ─── Контакты (8.3.1) ───
  List<VibeProfile> searchResults = [];
  final Map<String, String> pmChatForPeer = {};

  @override
  Future<List<VibeProfile>> searchUsers(String query) async {
    calls.add('searchUsers($query)');
    final q = query.trim().toLowerCase();
    return searchResults
        .where((p) =>
            p.displayName.toLowerCase().contains(q) ||
            p.username.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<String> ensurePmChat(String peerId) async {
    calls.add('ensurePmChat($peerId)');
    return pmChatForPeer[peerId] ?? 'pm_$peerId';
  }

  @override
  Future<VibeChat?> chatById(String chatId) async {
    for (final c in chatList) {
      if (c.id == chatId) return c;
    }
    return null;
  }

  @override
  Future<void> updateProfile({
    required String username,
    required String displayName,
    String? emoji,
    String? bio,
  }) async {
    calls.add('updateProfile($username)');
    updateProfileCalls++;
    lastUsernameUpdated = username;
  }

  // ─── Действия ───
  @override
  Future<void> setReaction(
    String chatId,
    String messageId,
    String emoji,
  ) async {
    reactions.add((chatId: chatId, messageId: messageId, emoji: emoji));
  }

  @override
  Future<void> refreshChatReactions(String chatId) async {
    refreshReactionsCalls++;
  }

  @override
  Future<void> sendTyping(String chatId) async {
    sendTypingCalls++;
  }

  @override
  Future<void> markChatRead(String chatId) async {
    markReadCalls++;
  }

  @override
  Future<void> setChatArchived(String chatId, {required bool archived}) async {
    setArchivedCalls.add((id: chatId, archived: archived));
    if (archived) {
      archivedNotifier.value = {...archivedNotifier.value, chatId};
    } else {
      archivedNotifier.value = {
        ...archivedNotifier.value,
      }..remove(chatId);
    }
  }

  @override
  Future<void> setChatMuted(String chatId, {required bool muted}) async {
    setMutedCalls.add((id: chatId, muted: muted));
    if (muted) {
      mutedNotifier.value = {...mutedNotifier.value, chatId};
    } else {
      mutedNotifier.value = {...mutedNotifier.value}..remove(chatId);
    }
  }

  @override
  String formatTime(dynamic raw) => VibeBackend.formatTime(raw);

  // ─── Помощники ───
  VibeMessage _sent(
    String chatId, {
    String? text,
    String? stickerEmoji,
    String? photoPath,
    String? voicePath,
    String? videoPath,
    String? localId,
    String? id,
    MsgStatus status = MsgStatus.sent,
    DateTime? created,
    bool incoming = false,
    String? forwardedFrom,
  }) {
    return VibeMessage(
      id: id ?? 'sent-${calls.length}-${DateTime.now().microsecondsSinceEpoch}',
      chatId: chatId,
      senderId: 'me',
      senderName: 'Я',
      senderAvatar: null,
      text: text,
      voicePath: voicePath,
      photoPath: photoPath,
      videoPath: videoPath,
      created: created ?? DateTime.now(),
      incoming: incoming,
      status: status,
      localId: localId,
      stickerEmoji: stickerEmoji,
      forwardedFrom: forwardedFrom,
    );
  }

  /// Стандартное входящее сообщение для ручной эмуляции realtime.
  VibeMessage incomingMessage({
    String chatId = 'c1',
    String text = 'hi',
    String? id,
  }) {
    return VibeMessage(
      id: id ?? 'in-${DateTime.now().microsecondsSinceEpoch}',
      chatId: chatId,
      senderId: 'peer',
      senderName: 'Пир',
      senderAvatar: null,
      text: text,
      voicePath: null,
      photoPath: null,
      videoPath: null,
      created: DateTime.now(),
      incoming: true,
      status: MsgStatus.sent,
    );
  }

  void close() {
    streamCtrl.close();
    msgEventsCtrl.close();
    typingCtrl.close();
    chatEventsCtrl.close();
  }
}
