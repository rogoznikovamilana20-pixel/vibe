import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/offline_queue_service.dart';

void main() {
  group('QueueItem', () {
    test('serialization roundtrip', () {
      final item = QueueItem(
        localId: 'l1',
        chatId: 'c1',
        text: 'hello',
        replyText: 'r',
        replyAuthor: 'a',
        state: QueueItemState.sending,
        attempts: 2,
        createdAt: DateTime(2026),
        lastAttemptAt: DateTime(2026, 1, 2),
      );
      final json = item.toJson();
      final restored = QueueItem.fromJson(json);
      expect(restored.localId, 'l1');
      expect(restored.chatId, 'c1');
      expect(restored.text, 'hello');
      expect(restored.replyText, 'r');
      expect(restored.replyAuthor, 'a');
      expect(restored.state, QueueItemState.sending);
      expect(restored.attempts, 2);
      expect(restored.createdAt, DateTime(2026));
      expect(restored.lastAttemptAt, DateTime(2026, 1, 2));
    });

    test('serialization roundtrip with nulls', () {
      final item = QueueItem(
        localId: 'l2',
        chatId: 'c2',
        text: 'world',
        createdAt: DateTime(2026, 3),
      );
      final json = item.toJson();
      final restored = QueueItem.fromJson(json);
      expect(restored.replyText, isNull);
      expect(restored.replyAuthor, isNull);
      expect(restored.lastAttemptAt, isNull);
      expect(restored.state, QueueItemState.queued);
      expect(restored.attempts, 0);
    });

    test('canRetry true only when failed and under maxAttempts', () {
      final item = QueueItem(
        localId: 'l3',
        chatId: 'c3',
        text: 't',
        createdAt: DateTime.now(),
      );
      // queued — not retryable
      item.state = QueueItemState.queued;
      expect(item.canRetry, isFalse);

      // sending — not retryable
      item.state = QueueItemState.sending;
      expect(item.canRetry, isFalse);

      // sent — not retryable
      item.state = QueueItemState.sent;
      expect(item.canRetry, isFalse);

      // failed, attempts < maxAttempts — retryable
      item.state = QueueItemState.failed;
      item.attempts = 1;
      expect(item.canRetry, isTrue);

      // failed, attempts >= maxAttempts — not retryable
      item.attempts = QueueItemState.queued.index; // use a large number
      item.attempts = 3;
      expect(item.canRetry, isFalse);
    });
  });

  group('OfflineQueueService', () {
    late OfflineQueueService service;

    setUp(() {
      service = OfflineQueueService.instance;
    });

    test('empty queue on fresh load', () async {
      await service.load('test_empty');
      expect(service.items, isEmpty);
      expect(service.hasPending, isFalse);
    });

    test('enqueue and retrieve', () async {
      await service.load('test_enq');
      await service.enqueue(
        'test_enq',
        localId: 'msg1',
        chatId: 'chat1',
        text: 'hello',
      );
      expect(service.items.length, 1);
      expect(service.items.first.localId, 'msg1');
      expect(service.items.first.chatId, 'chat1');
      expect(service.items.first.text, 'hello');
      expect(service.items.first.state, QueueItemState.queued);
    });

    test('enqueue deduplicates by localId', () async {
      await service.load('test_dedup');
      await service.enqueue('test_dedup', localId: 'msg1', chatId: 'c', text: 'a');
      await service.enqueue('test_dedup', localId: 'msg1', chatId: 'c', text: 'b');
      expect(service.items.length, 1);
    });

    test('markSending increments attempts', () async {
      await service.load('test_sending');
      await service.enqueue('test_sending', localId: 'm1', chatId: 'c', text: 't');
      expect(service.items.first.attempts, 0);

      await service.markSending('test_sending', 'm1');
      expect(service.items.first.state, QueueItemState.sending);
      expect(service.items.first.attempts, 1);

      await service.markSending('test_sending', 'm1');
      expect(service.items.first.attempts, 2);
    });

    test('markSent removes from queue', () async {
      await service.load('test_sent');
      await service.enqueue('test_sent', localId: 'm1', chatId: 'c', text: 't');
      expect(service.items.length, 1);

      await service.markSent('test_sent', 'm1');
      expect(service.items, isEmpty);
    });

    test('markFailed sets failed state', () async {
      await service.load('test_fail');
      await service.enqueue('test_fail', localId: 'm1', chatId: 'c', text: 't');
      await service.markFailed('test_fail', 'm1');
      expect(service.items.first.state, QueueItemState.failed);
      expect(service.hasPending, isTrue);
    });

    test('forChat returns only items for that chat', () async {
      await service.load('test_forchat');
      await service.enqueue('test_forchat', localId: 'm1', chatId: 'chatA', text: 'a');
      await service.enqueue('test_forchat', localId: 'm2', chatId: 'chatB', text: 'b');
      await service.enqueue('test_forchat', localId: 'm3', chatId: 'chatA', text: 'c');

      final items = service.forChat('chatA');
      expect(items.length, 2);
      expect(items.every((q) => q.chatId == 'chatA'), isTrue);
    });

    test('clear removes all items', () async {
      await service.load('test_clear');
      await service.enqueue('test_clear', localId: 'm1', chatId: 'c', text: 't');
      await service.enqueue('test_clear', localId: 'm2', chatId: 'c', text: 't2');
      await service.clear('test_clear');
      expect(service.items, isEmpty);
    });

    test('remove single item', () async {
      await service.load('test_remove');
      await service.enqueue('test_remove', localId: 'm1', chatId: 'c', text: 'a');
      await service.enqueue('test_remove', localId: 'm2', chatId: 'c', text: 'b');
      await service.remove('test_remove', 'm1');
      expect(service.items.length, 1);
      expect(service.items.first.localId, 'm2');
    });

    test('account isolation — in-memory queue is cleared on load', () async {
      await service.load('acct1');
      await service.enqueue('acct1', localId: 'm1', chatId: 'c', text: 'from_acct1');
      expect(service.items.length, 1);

      // load different account clears in-memory queue
      await service.load('acct2');
      expect(service.items, isEmpty);
      await service.enqueue('acct2', localId: 'm2', chatId: 'c', text: 'from_acct2');
      expect(service.items.length, 1);
      expect(service.items.first.localId, 'm2');
    });

    test('markSending on nonexistent localId is no-op', () async {
      await service.load('test_noop');
      await service.enqueue('test_noop', localId: 'm1', chatId: 'c', text: 't');
      await service.markSending('test_noop', 'nonexistent');
      expect(service.items.first.state, QueueItemState.queued);
      expect(service.items.first.attempts, 0);
    });

    test('markFailed on nonexistent localId is no-op', () async {
      await service.load('test_noop2');
      await service.enqueue('test_noop2', localId: 'm1', chatId: 'c', text: 't');
      await service.markFailed('test_noop2', 'nonexistent');
      expect(service.items.first.state, QueueItemState.queued);
    });

    test('maxAttempts constant is 3', () {
      expect(QueueItem.maxAttempts, 3);
    });

    test('enqueue with reply fields preserves them', () async {
      await service.load('test_reply');
      await service.enqueue('test_reply',
          localId: 'm1', chatId: 'c', text: 'hi',
          replyText: 'original', replyAuthor: 'Alice');
      expect(service.items.first.replyText, 'original');
      expect(service.items.first.replyAuthor, 'Alice');
    });

    test('hasPending is true when queued items exist', () async {
      await service.load('test_pending');
      expect(service.hasPending, isFalse);
      await service.enqueue('test_pending', localId: 'm1', chatId: 'c', text: 't');
      expect(service.hasPending, isTrue);
    });

    test('hasPending is false when all items are sent', () async {
      await service.load('test_pending2');
      await service.enqueue('test_pending2', localId: 'm1', chatId: 'c', text: 't');
      await service.markSent('test_pending2', 'm1');
      expect(service.hasPending, isFalse);
    });

    test('items getter returns unmodifiable list', () async {
      await service.load('test_unmod');
      final list = service.items;
      expect(() => list.add(QueueItem(
          localId: 'x', chatId: 'c', text: 't', createdAt: DateTime.now())),
          throwsUnsupportedError);
    });
  });
}
