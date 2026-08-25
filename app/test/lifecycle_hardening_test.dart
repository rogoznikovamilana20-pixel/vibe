// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/chat/chat_controller.dart';
import 'package:vibe_app/chat/chat_list_controller.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/offline_queue_service.dart';
import 'package:vibe_app/data/settings_service.dart';

import 'fake_vibe_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    await OfflineQueueService.instance.load('_test_lifecycle_');
  });

  VibeMessage msg({
    required String id,
    String chatId = 'c1',
    String text = 'm',
    bool incoming = true,
  }) {
    return VibeMessage(
      id: id,
      chatId: chatId,
      senderId: incoming ? 'peer' : 'me',
      senderName: 'X',
      senderAvatar: null,
      text: text,
      voicePath: null,
      photoPath: null,
      videoPath: null,
      created: DateTime(2026, 8, 15),
      incoming: incoming,
      status: MsgStatus.sent,
    );
  }

  group('ChatController lifecycle', () {
    test('dispose() cancels all subscriptions and timers', () async {
      final fake = FakeVibeBackend();
      final errors = <String>[];
      final c = ChatController(
        chatId: 'c1',
        chatTitle: 'T',
        onError: errors.add,
        backend: fake,
      );

      fake.streamCtrl.add(msg(id: 'm1', incoming: true));
      fake.typingCtrl.add(TypingEvent(chatId: 'c1', userId: 'u1'));
      fake.msgEventsCtrl.add(VibeMsgEvent(
        type: VibeMsgEventType.edited,
        chatId: 'c1',
        messageId: 'm1',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 20));

      c.dispose();

      fake.streamCtrl.add(msg(id: 'm2', incoming: true));
      fake.typingCtrl.add(TypingEvent(chatId: 'c1', userId: 'u1'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(errors, isEmpty);
      fake.close();
    });

    test('dispose() prevents further event handling', () async {
      final fake = FakeVibeBackend();
      final c = ChatController(
        chatId: 'c1',
        chatTitle: 'T',
        onError: (_) {},
        backend: fake,
      );

      c.dispose();
      // After dispose, stream events should be silently ignored.
      fake.streamCtrl.add(msg(id: 'm2', incoming: true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      fake.close();
    });
  });

  group('ChatListController lifecycle', () {
    test('dispose() removes all listeners', () async {
      final fake = FakeVibeBackend();
      final c = ChatListController(
        onSnack: (_) {},
        backend: fake,
      );

      await c.load();
      c.dispose();

      fake.chatEventsCtrl.add(null);
      fake.presenceNotifier.value++;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      fake.close();
    });
  });

  group('OfflineQueueService lifecycle', () {
    test('clear() empties queue', () async {
      final svc = OfflineQueueService.instance;
      await svc.load('lifecycle_test');
      await svc.enqueue('lifecycle_test', localId: 'l1', chatId: 'c1', text: 'hello');
      await svc.enqueue('lifecycle_test', localId: 'l2', chatId: 'c2', text: 'world');
      expect(svc.items.length, 2);

      await svc.clear('lifecycle_test');
      expect(svc.items.length, 0);
    });

    test('hasPending reflects queue state', () async {
      final svc = OfflineQueueService.instance;
      await svc.load('lifecycle_test2');
      expect(svc.hasPending, isFalse);

      await svc.enqueue('lifecycle_test2', localId: 'l1', chatId: 'c1', text: 'hello');
      expect(svc.hasPending, isTrue);

      await svc.markSent('lifecycle_test2', 'l1');
      expect(svc.hasPending, isFalse);
    });
  });
}
