import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Состояния элемента очереди.
enum QueueItemState { queued, sending, sent, failed }

/// Элемент очереди офлайн-отправки.
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

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'chatId': chatId,
        'text': text,
        'replyText': replyText,
        'replyAuthor': replyAuthor,
        'state': state.index,
        'attempts': attempts,
        'createdAt': createdAt.toIso8601String(),
        'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      };

  factory QueueItem.fromJson(Map<String, dynamic> json) => QueueItem(
        localId: json['localId'] as String,
        chatId: json['chatId'] as String,
        text: json['text'] as String,
        replyText: json['replyText'] as String?,
        replyAuthor: json['replyAuthor'] as String?,
        state: QueueItemState.values[json['state'] as int],
        attempts: json['attempts'] as int? ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        lastAttemptAt: json['lastAttemptAt'] != null
            ? DateTime.tryParse(json['lastAttemptAt'] as String)
            : null,
      );
}

/// Сервис.persistent-очереди отправки сообщений.
/// Использует существующий механизм vibe_cache для хранения.
class OfflineQueueService {
  OfflineQueueService._();
  static final instance = OfflineQueueService._();

  final _queue = <QueueItem>[];
  List<QueueItem> get items => List.unmodifiable(_queue);

  /// Загрузить очередь из файла (вызывать при init).
  Future<void> load(String accountId) async {
    _queue.clear();
    try {
      final dir = await _cacheDir();
      final f = File(
          '${dir.path}${Platform.pathSeparator}queue_$accountId.json');
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString()) as List;
        for (final item in data) {
          final qi = QueueItem.fromJson(item as Map<String, dynamic>);
          if (qi.state != QueueItemState.sent) {
            // Сбрасываем sending → queued при загрузке (прошлая попытка
            // была прервана).
            if (qi.state == QueueItemState.sending) {
              qi.state = QueueItemState.queued;
            }
            _queue.add(qi);
          }
        }
      }
    } catch (_) {}
  }

  /// Сохранить очередь в файл.
  Future<void> _save(String accountId) async {
    try {
      final dir = await _cacheDir();
      final f = File(
          '${dir.path}${Platform.pathSeparator}queue_$accountId.json');
      await f.writeAsString(jsonEncode(_queue.map((e) => e.toJson()).toList()),
          flush: true);
    } catch (_) {}
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
    // Не дублировать, если уже есть в очереди.
    if (_queue.any((q) => q.localId == localId)) return;
    _queue.add(QueueItem(
      localId: localId,
      chatId: chatId,
      text: text,
      replyText: replyText,
      replyAuthor: replyAuthor,
      createdAt: DateTime.now(),
    ));
    await _save(accountId);
  }

  /// Пометить как отправляется.
  Future<void> markSending(String accountId, String localId) async {
    final item = _queue.firstWhere(
      (q) => q.localId == localId,
      orElse: () => QueueItem(
          localId: '', chatId: '', text: '', createdAt: DateTime.now()),
    );
    if (item.localId.isEmpty) return;
    item.state = QueueItemState.sending;
    item.attempts++;
    item.lastAttemptAt = DateTime.now();
    await _save(accountId);
  }

  /// Пометить как успешная отправка — удалить из очереди.
  Future<void> markSent(String accountId, String localId) async {
    _queue.removeWhere((q) => q.localId == localId);
    await _save(accountId);
  }

  /// Пометить как failed (после исчерпания попыток).
  Future<void> markFailed(String accountId, String localId) async {
    final item = _queue.firstWhere(
      (q) => q.localId == localId,
      orElse: () => QueueItem(
          localId: '', chatId: '', text: '', createdAt: DateTime.now()),
    );
    if (item.localId.isEmpty) return;
    item.state = QueueItemState.failed;
    await _save(accountId);
  }

  /// Удалить из очереди (ручное удаление).
  Future<void> remove(String accountId, String localId) async {
    _queue.removeWhere((q) => q.localId == localId);
    await _save(accountId);
  }

  /// Очистить очередь при logout.
  Future<void> clear(String accountId) async {
    _queue.clear();
    try {
      final dir = await _cacheDir();
      final f = File(
          '${dir.path}${Platform.pathSeparator}queue_$accountId.json');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Получить все элементы для конкретного чата.
  List<QueueItem> forChat(String chatId) =>
      _queue.where((q) => q.chatId == chatId).toList();

  /// Есть ли элементы, ожидающие отправки.
  bool get hasPending =>
      _queue.any((q) =>
          q.state == QueueItemState.queued ||
          q.state == QueueItemState.failed);

  static Future<Directory> _cacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final c =
        Directory('${dir.path}${Platform.pathSeparator}vibe_cache');
    if (!await c.exists()) await c.create(recursive: true);
    return c;
  }
}
