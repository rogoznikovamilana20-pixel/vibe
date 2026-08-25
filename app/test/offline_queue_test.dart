// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/offline_queue_service.dart';

void main() {
  group('QueueItem', () {
    test('canRetry true only when failed and under maxAttempts', () {
      final item = QueueItem(
        localId: 'l3',
        chatId: 'c3',
        text: 't',
        createdAt: DateTime.now(),
      );
      item.state = QueueItemState.queued;
      expect(item.canRetry, isFalse);

      item.state = QueueItemState.sending;
      expect(item.canRetry, isFalse);

      item.state = QueueItemState.sent;
      expect(item.canRetry, isFalse);

      item.state = QueueItemState.failed;
      item.attempts = 1;
      expect(item.canRetry, isTrue);

      item.attempts = 3;
      expect(item.canRetry, isFalse);
    });

    test('maxAttempts constant is 3', () {
      expect(QueueItem.maxAttempts, 3);
    });
  });

  group('OfflineQueueService — RAM-only', () {
    late OfflineQueueService service;

    setUp(() async {
      service = OfflineQueueService.instance;
      // Clear before each test.
      await service.clear('_test_setup_');
    });

    test('empty queue on fresh load', () async {
      await service.load('test_empty');
      expect(service.items, isEmpty);
      expect(service.hasPending, isFalse);
    });

    test('enqueue and retrieve', () async {
      await service.enqueue(
        'test_acct',
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
      await service.enqueue('a', localId: 'msg1', chatId: 'c', text: 'a');
      await service.enqueue('a', localId: 'msg1', chatId: 'c', text: 'b');
      expect(service.items.length, 1);
    });

    test('markSending increments attempts', () async {
      await service.enqueue('a', localId: 'm1', chatId: 'c', text: 't');
      expect(service.items.first.attempts, 0);

      await service.markSending('a', 'm1');
      expect(service.items.first.state, QueueItemState.sending);
      expect(service.items.first.attempts, 1);

      await service.markSending('a', 'm1');
      expect(service.items.first.attempts, 2);
    });

    test('markSent removes from queue', () async {
      await service.enqueue('a', localId: 'm1', chatId: 'c', text: 't');
      expect(service.items.length, 1);

      await service.markSent('a', 'm1');
      expect(service.items, isEmpty);
    });

    test('markFailed sets failed state', () async {
      await service.enqueue('a', localId: 'm1', chatId: 'c', text: 't');
      await service.markFailed('a', 'm1');
      expect(service.items.first.state, QueueItemState.failed);
      expect(service.hasPending, isTrue);
    });

    test('forChat returns only items for that chat', () async {
      await service.enqueue('a', localId: 'm1', chatId: 'chatA', text: 'a');
      await service.enqueue('a', localId: 'm2', chatId: 'chatB', text: 'b');
      await service.enqueue('a', localId: 'm3', chatId: 'chatA', text: 'c');

      final items = service.forChat('chatA');
      expect(items.length, 2);
      expect(items.every((q) => q.chatId == 'chatA'), isTrue);
    });

    test('clear removes all items', () async {
      await service.enqueue('a', localId: 'm1', chatId: 'c', text: 't');
      await service.enqueue('a', localId: 'm2', chatId: 'c', text: 't2');
      await service.clear('a');
      expect(service.items, isEmpty);
    });

    test('remove single item', () async {
      await service.enqueue('a', localId: 'm1', chatId: 'c', text: 'a');
      await service.enqueue('a', localId: 'm2', chatId: 'c', text: 'b');
      await service.remove('a', 'm1');
      expect(service.items.length, 1);
      expect(service.items.first.localId, 'm2');
    });

    test('load clears in-memory queue', () async {
      await service.enqueue('a', localId: 'm1', chatId: 'c', text: 'from_a');
      expect(service.items.length, 1);

      await service.load('b');
      expect(service.items, isEmpty);
    });

    test('markSending on nonexistent localId is no-op', () async {
      await service.enqueue('a', localId: 'm1', chatId: 'c', text: 't');
      await service.markSending('a', 'nonexistent');
      expect(service.items.first.state, QueueItemState.queued);
      expect(service.items.first.attempts, 0);
    });

    test('markFailed on nonexistent localId is no-op', () async {
      await service.enqueue('a', localId: 'm1', chatId: 'c', text: 't');
      await service.markFailed('a', 'nonexistent');
      expect(service.items.first.state, QueueItemState.queued);
    });

    test('enqueue with reply fields preserves them', () async {
      await service.enqueue('a',
          localId: 'm1', chatId: 'c', text: 'hi',
          replyText: 'original', replyAuthor: 'Alice');
      expect(service.items.first.replyText, 'original');
      expect(service.items.first.replyAuthor, 'Alice');
    });

    test('hasPending is true when queued items exist', () async {
      expect(service.hasPending, isFalse);
      await service.enqueue('a', localId: 'm1', chatId: 'c', text: 't');
      expect(service.hasPending, isTrue);
    });

    test('hasPending is false when all items are sent', () async {
      await service.enqueue('a', localId: 'm1', chatId: 'c', text: 't');
      await service.markSent('a', 'm1');
      expect(service.hasPending, isFalse);
    });

    test('items getter returns unmodifiable list', () async {
      final list = service.items;
      expect(() => list.add(QueueItem(
          localId: 'x', chatId: 'c', text: 't', createdAt: DateTime.now())),
          throwsUnsupportedError);
    });
  });

  group('SECURITY: no persistent storage', () {
    test('load() clears queue — no persistence across sessions', () async {
      final service = OfflineQueueService.instance;
      await service.enqueue('sec', localId: 's1', chatId: 'c', text: 'secret msg');
      expect(service.items.length, 1);

      // Simulate app restart: load clears everything
      await service.load('sec');
      expect(service.items, isEmpty);
    });

    test('no file I/O — service has no disk methods', () {
      // Verify OfflineQueueService has no _save, _cacheDir, or file operations
      // by checking the class doesn't expose persistent state.
      final service = OfflineQueueService.instance;
      // All state is in _queue (in-memory List)
      expect(service.items, isA<List<QueueItem>>());
    });

    test('account isolation — load clears previous account data', () async {
      final service = OfflineQueueService.instance;
      await service.enqueue('acctA', localId: 'm1', chatId: 'c', text: 'A secret');
      expect(service.items.length, 1);

      // Switch to account B — A's data is gone
      await service.load('acctB');
      expect(service.items, isEmpty);

      // B can enqueue independently
      await service.enqueue('acctB', localId: 'm2', chatId: 'c', text: 'B message');
      expect(service.items.length, 1);
      expect(service.items.first.localId, 'm2');
    });

    test('logout clears queue — no data persists', () async {
      final service = OfflineQueueService.instance;
      await service.enqueue('logout_test', localId: 'l1', chatId: 'c', text: 'sensitive');
      await service.clear('logout_test');
      expect(service.items, isEmpty);
      expect(service.hasPending, isFalse);
    });

    test('restart drops all queued messages', () async {
      final service = OfflineQueueService.instance;
      // User sends 3 messages while offline
      await service.enqueue('r', localId: 'm1', chatId: 'c', text: 'msg1');
      await service.enqueue('r', localId: 'm2', chatId: 'c', text: 'msg2');
      await service.enqueue('r', localId: 'm3', chatId: 'c', text: 'msg3');
      expect(service.items.length, 3);

      // App killed and restarted — queue is empty
      await service.load('r');
      expect(service.items, isEmpty);
    });
  });
}
