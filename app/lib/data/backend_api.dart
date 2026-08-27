import 'dart:io';

import 'package:flutter/foundation.dart';

import 'backend.dart';

/// Поверхность данных для контроллеров: ровно те методы и потоки, которыми
/// пользуются `ChatController` и `ChatListController`.
///
/// Позволяет подменить живой `VibeBackend` фейком в unit-тестах, не трогая
/// синглтон (см. `test/chat_controller_test.dart`).
abstract class VibeBackendApi {
  // ─── Realtime-потоки ───
  Stream<VibeMessage> get stream;
  Stream<VibeMsgEvent> get msgEvents;
  Stream<TypingEvent> get typingEvents;
  Stream<void> get chatEvents;
  Stream<PinChanged> get pinEvents;

  // ─── Публикаторы статусов ───
  ValueListenable<int> get presenceVersion;
  ValueListenable<Set<String>> get archivedNotifier;
  ValueListenable<Set<String>> get mutedNotifier;

  // ─── Сеть/онлайн (офлайн-баннер) ───
  ValueListenable<int> get connectivityVersion;
  bool get isOffline;

  // ─── Чаты ───
  Future<List<VibeChat>> listChats();
  Future<List<VibeChat>> getOfflineChats();

  // ─── Сториз ───
  Future<List<VibeStory>> listStories();

  // ─── Сообщения ───
  Future<List<VibeMessage>> listMessages(
    String chatId, {
    int? limit,
    DateTime? before,
  });

  Future<VibeMessage> sendText(
    String chatId,
    String text, {
    String? localId,
    String? replyTo,
    String? replyText,
    String? replyAuthor,
    bool silent = false,
  });

  Future<VibeMessage> sendSticker(
    String chatId,
    String emoji, {
    String? localId,
  });

  /// Стикер-паки для панели эмодзи/стикеров.
  Future<List<VibeStickerPack>> listStickerPacks();

  Future<VibeMessage> sendPhoto(
    String chatId,
    Uint8List bytes, {
    String? localId,
    String? localPath,
  });

  Future<VibeMessage> sendFile(
    String chatId,
    File file, {
    String? localId,
    String? localPath,
    String? mime,
  });

  Future<VibeMessage> sendVoice(
    String chatId,
    File voiceFile, {
    String? localId,
    String? localPath,
    int? voiceSeconds,
  });

  Future<VibeMessage> sendVideo(
    String chatId,
    File videoFile, {
    String? localId,
    String? localPath,
  });

  Future<VibeMessage?> updateMessage(String messageId, String newText);
  Future<List<MessageEdit>> listMessageEdits(String messageId);
  Future<bool> deleteMessage(String messageId);
  Future<void> hideMessageForMe(String messageId);
  Future<void> clearHistory(String chatId);

  // ─── Закреплённые сообщения (облако, множественные) ───
  /// Список закрепов чата (новые сверху).
  Future<List<String>> fetchChatPins(String chatId);
  Future<void> pinMessage(String chatId, String messageId);
  Future<void> unpinMessage(String chatId, String messageId);

  // ─── Действия ───
  Future<void> setReaction(String chatId, String messageId, String emoji);
  Future<void> refreshChatReactions(String chatId);
  Future<void> sendTyping(String chatId, {String action = 'typing'});
  Future<void> markChatRead(String chatId);
  Future<void> setChatArchived(String chatId, {required bool archived});
  Future<void> setChatMuted(String chatId, {required bool muted});

  // ─── Прочее (экраны: пересылка, «Сохранить в Избранное») ───
  String? get myProfileId;
  Future<String> ensureSavedChat();
  Future<VibeMessage?> forwardMessage(
    String targetChatId,
    VibeMessage original, {
    bool hideSender = false,
  });

  // ─── Профиль ───
  Future<bool> isUsernameAvailable(String username);
  Future<void> updateProfile({
    required String username,
    required String displayName,
    String? emoji,
    String? bio,
  });

  // ─── Контакты (8.3.1) ───
  Future<List<VibeProfile>> listContacts();
  Future<List<VibeProfile>> searchUsers(String query);
  Future<String> ensurePmChat(String peerId);
  Future<VibeChat?> chatById(String chatId);

  // ─── Приватность (3.7) ───
  Future<PrivacySettings?> fetchPrivacy();
  Future<void> savePrivacy(PrivacySettings settings);

  // ─── Черновики (как в TG messages.saveDraft) ───
  Future<void> saveDraft(String chatId, String? text);
  Future<String?> fetchDraft(String chatId);

  /// Форматирование времени (в `VibeBackend` — статика, здесь — метод).
  String formatTime(dynamic raw);
}

/// Живая реализация по умолчанию: делегирует `VibeBackend.instance`.
class LiveVibeBackend implements VibeBackendApi {
  LiveVibeBackend([VibeBackend? backend]) : _b = backend ?? _resolveBackend();

  static VibeBackend _resolveBackend() {
    final inst = VibeBackend.instanceOrNull;
    if (inst != null) return inst;
    throw StateError('VibeBackend not initialized yet — вызовите await VibeBackend.init()');
  }

  final VibeBackend _b;

  @override
  Stream<VibeMessage> get stream => _b.stream;

  @override
  Stream<VibeMsgEvent> get msgEvents => _b.msgEvents;

  @override
  Stream<TypingEvent> get typingEvents => _b.typingEvents;

  @override
  Stream<void> get chatEvents => _b.chatEvents;

  @override
  Stream<PinChanged> get pinEvents => _b.pinEvents;

  @override
  ValueListenable<int> get presenceVersion => _b.presenceVersion;

  @override
  ValueListenable<Set<String>> get archivedNotifier => _b.archivedNotifier;

  @override
  ValueListenable<Set<String>> get mutedNotifier => _b.mutedNotifier;

  @override
  ValueListenable<int> get connectivityVersion => _b.connectivityVersion;

  @override
  bool get isOffline => _b.isOffline;

  @override
  Future<List<VibeChat>> listChats() => _b.listChats();

@override
  Future<List<VibeChat>> getOfflineChats() => _b.getOfflineChats();

  @override
  Future<List<VibeStory>> listStories() => _b.listStories();

  @override
  Future<List<VibeMessage>> listMessages(
    String chatId, {
    int? limit,
    DateTime? before,
  }) =>
      _b.listMessages(chatId, limit: limit, before: before);

  @override
  Future<VibeMessage> sendText(
    String chatId,
    String text, {
    String? localId,
    String? replyTo,
    String? replyText,
    String? replyAuthor,
    bool silent = false,
  }) =>
      _b.sendText(
        chatId,
        text,
        localId: localId,
        replyTo: replyTo,
        replyText: replyText,
        replyAuthor: replyAuthor,
        silent: silent,
      );

  @override
  Future<VibeMessage> sendSticker(
    String chatId,
    String emoji, {
    String? localId,
  }) =>
      _b.sendSticker(chatId, emoji, localId: localId);

  @override
  Future<List<VibeStickerPack>> listStickerPacks() => _b.listStickerPacks();

  @override
  Future<VibeMessage> sendPhoto(
    String chatId,
    Uint8List bytes, {
    String? localId,
    String? localPath,
  }) =>
      _b.sendPhoto(chatId, bytes, localId: localId, localPath: localPath);

  @override
  Future<VibeMessage> sendFile(
    String chatId,
    File file, {
    String? localId,
    String? localPath,
    String? mime,
  }) =>
      _b.sendFile(chatId, file,
          localId: localId, localPath: localPath, mime: mime);

  @override
  Future<VibeMessage> sendVoice(
    String chatId,
    File voiceFile, {
    String? localId,
    String? localPath,
    int? voiceSeconds,
  }) =>
      _b.sendVoice(
        chatId,
        voiceFile,
        localId: localId,
        localPath: localPath,
        voiceSeconds: voiceSeconds,
      );

  @override
  Future<VibeMessage> sendVideo(
    String chatId,
    File videoFile, {
    String? localId,
    String? localPath,
  }) =>
      _b.sendVideo(chatId, videoFile, localId: localId, localPath: localPath);

  @override
  Future<VibeMessage?> updateMessage(String messageId, String newText) =>
      _b.updateMessage(messageId, newText);

  @override
  Future<List<MessageEdit>> listMessageEdits(String messageId) =>
      _b.listMessageEdits(messageId);

  @override
  Future<bool> deleteMessage(String messageId) =>
      _b.deleteMessage(messageId);

  @override
  Future<void> hideMessageForMe(String messageId) =>
      _b.hideMessageForMe(messageId);

  @override
  Future<void> clearHistory(String chatId) => _b.clearHistory(chatId);

  @override
  Future<List<String>> fetchChatPins(String chatId) =>
      _b.fetchChatPins(chatId);

  @override
  Future<void> pinMessage(String chatId, String messageId) =>
      _b.pinMessage(chatId, messageId);

  @override
  Future<void> unpinMessage(String chatId, String messageId) =>
      _b.unpinMessage(chatId, messageId);

  @override
  Future<void> setReaction(String chatId, String messageId, String emoji) =>
      _b.setReaction(chatId, messageId, emoji);

  @override
  Future<void> refreshChatReactions(String chatId) =>
      _b.refreshChatReactions(chatId);

  @override
  Future<void> sendTyping(String chatId, {String action = 'typing'}) => _b.sendTyping(chatId, action: action);

  @override
  Future<void> markChatRead(String chatId) => _b.markChatRead(chatId);

  @override
  Future<void> setChatArchived(String chatId, {required bool archived}) =>
      _b.setChatArchived(chatId, archived: archived);

  @override
  Future<void> setChatMuted(String chatId, {required bool muted}) =>
      _b.setChatMuted(chatId, muted: muted);

  @override
  String? get myProfileId => _b.myProfileId;

  @override
  Future<String> ensureSavedChat() => _b.ensureSavedChat();

  @override
  Future<VibeMessage?> forwardMessage(
    String targetChatId,
    VibeMessage original, {
    bool hideSender = false,
  }) =>
      _b.forwardMessage(targetChatId, original, hideSender: hideSender);

  @override
  Future<bool> isUsernameAvailable(String username) =>
      _b.isUsernameAvailable(username);

  @override
  Future<void> updateProfile({
    required String username,
    required String displayName,
    String? emoji,
    String? bio,
  }) =>
      _b.updateProfile(
        username: username,
        displayName: displayName,
        emoji: emoji,
        bio: bio,
      );

  @override
  Future<PrivacySettings?> fetchPrivacy() => _b.fetchPrivacy();

  @override
  Future<void> savePrivacy(PrivacySettings settings) =>
      _b.savePrivacy(settings);

  @override
  Future<void> saveDraft(String chatId, String? text) => _b.saveDraft(chatId, text);

  @override
  Future<String?> fetchDraft(String chatId) => _b.fetchDraft(chatId);

  @override
  String formatTime(dynamic raw) => VibeBackend.formatTime(raw);

  @override
  Future<List<VibeProfile>> listContacts() => _b.listContacts();

  @override
  Future<List<VibeProfile>> searchUsers(String query) =>
      _b.searchUsers(query);

  @override
  Future<String> ensurePmChat(String peerId) => _b.ensurePmChat(peerId);

  @override
  Future<VibeChat?> chatById(String chatId) => _b.chatById(chatId);
}
