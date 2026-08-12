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
  Stream<String> get typingEvents;
  Stream<void> get chatEvents;

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
    String? replyText,
    String? replyAuthor,
  });

  Future<VibeMessage> sendSticker(
    String chatId,
    String emoji, {
    String? localId,
  });

  Future<VibeMessage> sendPhoto(
    String chatId,
    Uint8List bytes, {
    String? localId,
    String? localPath,
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
  Future<bool> deleteMessage(String messageId);

  // ─── Действия ───
  Future<void> setReaction(String chatId, String messageId, String emoji);
  Future<void> refreshChatReactions(String chatId);
  Future<void> sendTyping(String chatId);
  Future<void> markChatRead(String chatId);
  Future<void> setChatArchived(String chatId, {required bool archived});
  Future<void> setChatMuted(String chatId, {required bool muted});

  // ─── Прочее (экраны: пересылка, «Сохранить в Избранное») ───
  String? get myProfileId;
  Future<String> ensureSavedChat();
  Future<VibeMessage?> forwardMessage(
    String targetChatId,
    VibeMessage original,
  );

  /// Форматирование времени (в `VibeBackend` — статика, здесь — метод).
  String formatTime(dynamic raw);
}

/// Живая реализация по умолчанию: делегирует `VibeBackend.instance`.
class LiveVibeBackend implements VibeBackendApi {
  LiveVibeBackend([VibeBackend? backend]) : _b = backend ?? VibeBackend.instance;

  final VibeBackend _b;

  @override
  Stream<VibeMessage> get stream => _b.stream;

  @override
  Stream<VibeMsgEvent> get msgEvents => _b.msgEvents;

  @override
  Stream<String> get typingEvents => _b.typingEvents;

  @override
  Stream<void> get chatEvents => _b.chatEvents;

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
    String? replyText,
    String? replyAuthor,
  }) =>
      _b.sendText(
        chatId,
        text,
        localId: localId,
        replyText: replyText,
        replyAuthor: replyAuthor,
      );

  @override
  Future<VibeMessage> sendSticker(
    String chatId,
    String emoji, {
    String? localId,
  }) =>
      _b.sendSticker(chatId, emoji, localId: localId);

  @override
  Future<VibeMessage> sendPhoto(
    String chatId,
    Uint8List bytes, {
    String? localId,
    String? localPath,
  }) =>
      _b.sendPhoto(chatId, bytes, localId: localId, localPath: localPath);

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
  Future<bool> deleteMessage(String messageId) =>
      _b.deleteMessage(messageId);

  @override
  Future<void> setReaction(String chatId, String messageId, String emoji) =>
      _b.setReaction(chatId, messageId, emoji);

  @override
  Future<void> refreshChatReactions(String chatId) =>
      _b.refreshChatReactions(chatId);

  @override
  Future<void> sendTyping(String chatId) => _b.sendTyping(chatId);

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
    VibeMessage original,
  ) =>
      _b.forwardMessage(targetChatId, original);

  @override
  String formatTime(dynamic raw) => VibeBackend.formatTime(raw);
}
