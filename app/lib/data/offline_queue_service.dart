/// RAM-only queue for offline message send retry.
///
/// SECURITY POLICY: No persistent storage.
/// E2EE messages must not be written to disk in plaintext.
/// Queued messages are lost on app restart — this is intentional.
/// Industry standard for E2EE apps (Signal, WhatsApp).
library;

import 'dart:async';

/// Состояния элемента очереди.
enum QueueItemState { queued, sending, sent, failed }

/// Элемент очереди офлайн-отправки. Хранится ТОЛЬКО в RAM.
class QueueItem {
  QueueItem({
    required this.localId,
    required this.chatId,
    required this.text,
    this.replyText,
    this.replyAuthor,
    this.state = QueueItemState.queued,
    this.attempts = 0,
    required this.createdAt,
    this.lastAttemptAt,
  });

  final String localId;
  final String chatId;
  final String text;
  final String? replyText;
  final String? replyAuthor;
  QueueItemState state;
  int attempts;
  final DateTime createdAt;
  DateTime? lastAttemptAt;

  static const maxAttempts = 3;

  bool get canRetry =>
      state == QueueItemState.failed && attempts < maxAttempts;
}

/// Сервис RAM-only очереди отправки сообщений.
///
/// **НЕ сохраняет данные на диск.** E2EE-сообщения в plaintext
/// не должны попадать в persistent storage.
///
/// При restart приложения очередь очищается — это осознанное
/// решение ради безопасности.
class OfflineQueueService {
  OfflineQueueService._();
  static final instance = OfflineQueueService._();

  final _queue = <QueueItem>[];
  List<QueueItem> get items => List.unmodifiable(_queue);

  /// RAM-only: ничего не загружается с диска.
  Future<void> load(String accountId) async {
    _queue.clear();
  }

  /// Добавить сообщение в очередь (вызывать при failure отправки).
  Future<void> enqueue(
    String accountId, {
    required String localId,
    required String chatId,
    required String text,
    String? replyText,
    String? replyAuthor,
  }) async {
    if (_queue.any((q) => q.localId == localId)) return;
    _queue.add(QueueItem(
      localId: localId,
      chatId: chatId,
      text: text,
      replyText: replyText,
      replyAuthor: replyAuthor,
      createdAt: DateTime.now(),
    ));
  }

  /// Пометить как отправляется.
  Future<void> markSending(String accountId, String localId) async {
    final item = _queue.where((q) => q.localId == localId).firstOrNull;
    if (item == null) return;
    item.state = QueueItemState.sending;
    item.attempts++;
    item.lastAttemptAt = DateTime.now();
  }

  /// Пометить как успешная отправка — удалить из очереди.
  Future<void> markSent(String accountId, String localId) async {
    _queue.removeWhere((q) => q.localId == localId);
  }

  /// Пометить как failed (после исчерпания попыток).
  Future<void> markFailed(String accountId, String localId) async {
    final item = _queue.where((q) => q.localId == localId).firstOrNull;
    if (item == null) return;
    item.state = QueueItemState.failed;
  }

  /// Удалить из очереди (ручное удаление).
  Future<void> remove(String accountId, String localId) async {
    _queue.removeWhere((q) => q.localId == localId);
  }

  /// Очистить очередь при logout или restart.
  Future<void> clear(String accountId) async {
    _queue.clear();
  }

  /// Получить все элементы для конкретного чата.
  List<QueueItem> forChat(String chatId) =>
      _queue.where((q) => q.chatId == chatId).toList();

  /// Есть ли элементы, ожидающие отправки.
  bool get hasPending =>
      _queue.any((q) =>
          q.state == QueueItemState.queued ||
          q.state == QueueItemState.failed);
}
