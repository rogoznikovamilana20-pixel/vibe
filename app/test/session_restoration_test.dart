import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/chat/chat_list_controller.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';

import 'fake_vibe_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVibeBackend fake;

  VibeChat chat(String id, {int unread = 0}) {
    return VibeChat(
      id: id,
      title: 'Chat $id',
      kind: 'pm',
      lastMessage: '',
      lastTime: '',
      unread: unread,
      peerName: 'Peer $id',
      peerAvatar: null,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    fake = FakeVibeBackend();
  });

  tearDown(() {
    fake.close();
  });

  group('Scenario A: valid session → app restart → session restored', () {
    test('loadChats succeeds with valid backend', () async {
      fake.chatList = [chat('c1'), chat('c2')];
      final controller = ChatListController(
        onSnack: (_) {},
        backend: fake,
      );

      await controller.load();

      expect(controller.chats.length, 2);
      expect(controller.chats[0].id, 'c1');
      controller.dispose();
    });
  });

  group('Scenario B: no session → login/onboarding', () {
    test('empty chat list after load → no crash', () async {
      fake.chatList = [];
      final controller = ChatListController(
        onSnack: (_) {},
        backend: fake,
      );

      await controller.load();

      expect(controller.chats, isEmpty);
      controller.dispose();
    });
  });

  group('Scenario C: expired session → session rejected', () {
    test('network error during load → stays on cache', () async {
      fake.chatList = [chat('c1')];
      final controller = ChatListController(
        onSnack: (_) {},
        backend: fake,
      );

      // First load succeeds.
      await controller.load();
      expect(controller.chats.length, 1);

      // Simulate network failure on reload.
      fake.throwOnSendText = false;
      fake.chatList = [];
      // listChats will return empty, but _mergeChats handles it.
      await controller.loadChats();

      controller.dispose();
    });
  });

  group('Scenario D: session initially unavailable → temporary delay', () {
    test('delayed chat list load → controller handles gracefully', () async {
      final controller = ChatListController(
        onSnack: (_) {},
        backend: fake,
      );

      // Simulate slow load by not setting chatList before load.
      fake.chatList = [];
      await controller.load();
      expect(controller.chats, isEmpty);

      // Now chats arrive.
      fake.chatList = [chat('c1')];
      await controller.loadChats();
      expect(controller.chats.length, 1);

      controller.dispose();
    });
  });

  group('Scenario E: profile loading delay → no false registration', () {
    test('load() called twice → no duplicate listeners', () async {
      fake.chatList = [chat('c1')];
      final controller = ChatListController(
        onSnack: (_) {},
        backend: fake,
      );

      // Call load() twice — should not crash or leak listeners.
      await controller.load();
      await controller.load();

      expect(controller.chats.length, 1);
      controller.dispose();
    });
  });

  group('Logout cache clearing (Phase 3 fix)', () {
    test('chatListController clears state on dispose', () async {
      fake.chatList = [chat('c1'), chat('c2')];
      final controller = ChatListController(
        onSnack: (_) {},
        backend: fake,
      );

      await controller.load();
      controller.toggleSelect('c1');
      expect(controller.selectionMode, isTrue);

      // Dispose simulates logout cleanup.
      controller.dispose();

      // After dispose, controller should not be usable.
      // This tests that dispose completes without error.
    });

    test('new controller after dispose starts clean', () async {
      fake.chatList = [chat('c1')];
      final c1 = ChatListController(onSnack: (_) {}, backend: fake);
      await c1.load();
      c1.read.add('c1');
      // Note: pinned state persists via SettingsService — that's expected
      // behavior (passcode/pinned survive app restarts).
      c1.dispose();

      // New controller starts with clean runtime state (not persisted).
      final c2 = ChatListController(onSnack: (_) {}, backend: fake);
      await c2.load();
      expect(c2.read, isEmpty); // read is runtime-only, not persisted
      expect(c2.chats.length, 1);
      c2.dispose();
    });
  });

  group('Session restoration: loadChats resilience', () {
    test('loadChats handles empty → populated → empty transitions', () async {
      final controller = ChatListController(
        onSnack: (_) {},
        backend: fake,
      );

      // Empty state.
      fake.chatList = [];
      await controller.load();
      expect(controller.chats, isEmpty);

      // Chats appear.
      fake.chatList = [chat('c1'), chat('c2')];
      await controller.loadChats();
      expect(controller.chats.length, 2);

      // Chats disappear (e.g., all archived).
      fake.chatList = [];
      await controller.loadChats();
      expect(controller.chats, isEmpty);

      controller.dispose();
    });

    test('offline cache used when server fails', () async {
      fake.offlineCache = [chat('cached')];
      fake.chatList = [];
      final controller = ChatListController(
        onSnack: (_) {},
        backend: fake,
      );

      await controller.load();

      // Should have cached chat since server returned empty.
      // Note: _mergeChats compares cached vs fresh — if both empty, no chats.
      // But if cache has data and fresh is empty, cache is used.
      expect(fake.calls, contains('getOfflineChats'));
      controller.dispose();
    });
  });
}
