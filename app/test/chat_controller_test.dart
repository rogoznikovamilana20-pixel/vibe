import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fake_async/fake_async.dart';

import 'package:vibe_app/chat/chat_controller.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';

import 'fake_vibe_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVibeBackend fake;
  late ChatController controller;
  final errors = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    fake = FakeVibeBackend();
    controller = ChatController(
      chatId: 'c1',
      chatTitle: 'Чат',
      onError: errors.add,
      backend: fake,
    );
    errors.clear();
  });

  tearDown(() {
    controller.dispose();
    fake.close();
  });

  Future<void> pump() =>
      Future<void>.delayed(const Duration(milliseconds: 10));

  VibeMessage seed({
    required String id,
    required DateTime created,
    String text = 'm',
    bool incoming = true,
    String? localId,
    String? stickerEmoji,
    Map<String, int> reactions = const {},
  }) {
    return VibeMessage(
      id: id,
      chatId: 'c1',
      senderId: incoming ? 'peer' : 'me',
      senderName: incoming ? 'Пир' : 'Я',
      senderAvatar: null,
      text: text,
      voicePath: null,
      photoPath: null,
      videoPath: null,
      created: created,
      incoming: incoming,
      status: MsgStatus.sent,
      localId: localId,
      stickerEmoji: stickerEmoji,
      reactions: reactions,
    );
  }

  group('ChatController — загрузка и пагинация', () {
    test('load(): лента из бэкенда + markChatRead + refreshChatReactions',
        () async {
      final t = DateTime(2026, 8, 12, 10, 0);
      fake.messagesByChat['c1'] = [
        seed(id: 'm2', created: t.add(const Duration(minutes: 1)), text: 'новое'),
        seed(id: 'm1', created: t, text: 'старое'),
      ];

      await controller.load();

      expect(controller.messages.length, 2);
      expect(controller.messages.first.serverId, 'm2');
      expect(controller.messages.first.text, 'новое');
      expect(fake.markReadCalls, 1);
      expect(fake.refreshReactionsCalls, 1);
      expect(fake.calls, contains('listMessages(c1)'));
    });

    test('loadOlderIfNeeded(): подгружает старше и выключает hasMoreOlder',
        () async {
      final t = DateTime(2026, 8, 12, 10, 0);
      fake.messagesByChat['c1'] = [
        seed(id: 'm2', created: t.add(const Duration(minutes: 1))),
        seed(id: 'm1', created: t),
      ];
      await controller.load();

      final older = [
        for (var i = 0; i < 30; i++)
          seed(
            id: 'old-$i',
            created: t.subtract(Duration(minutes: 10 + i)),
          ),
      ];
      fake.messagesByChat['c1'] = [
        ...fake.messagesByChat['c1']!,
        ...older,
      ];

      await controller.loadOlderIfNeeded();

      expect(controller.messages.length, 32);
      expect(controller.hasMoreOlder, isFalse);
      expect(controller.loadingOlder, isFalse);

      final before = controller.messages.length;
      await controller.loadOlderIfNeeded();
      expect(controller.messages.length, before);
    });
  });

  group('ChatController — отправка', () {
    test('send(): оптимистично вставляет, ack по localId → sent', () async {
      fake.emitOnSend = false;
      await controller.load();

      await controller.send('привет');
      expect(controller.messages.first.text, 'привет');
      expect(controller.messages.first.status, MsgStatus.sending);
      expect(controller.messages.first.localId, isNotNull);

      final localId = controller.messages.first.localId;
      fake.streamCtrl.add(seed(
        id: 'server-1',
        created: DateTime.now(),
        text: 'привет',
        incoming: false,
        localId: localId,
      ));
      await pump();
      expect(controller.messages.first.status, MsgStatus.sent);
      expect(fake.lastTextSent, 'привет');
    });

    test('send(): ack от бэкенда (эмит в sendText) → статус sent', () async {
      await controller.load();
      await controller.send('привет');
      await pump();
      expect(controller.messages.first.status, MsgStatus.sent);
    });

    test('send(): пустой текст не уходит', () async {
      await controller.load();
      await controller.send('   ');
      expect(controller.messages, isEmpty);
      expect(fake.calls.where((c) => c.startsWith('sendText')), isEmpty);
    });

    test('send(): ответ — replyText/replyAuthor передаются в бэкенд',
        () async {
      final t = DateTime(2026, 8, 12, 10, 0);
      fake.messagesByChat['c1'] = [
        seed(id: 'm1', created: t, text: 'цитата'),
      ];
      await controller.load();

      controller.replyToMsg(0);
      expect(controller.replyTo, 0);

      await controller.send('ответ');
      expect(fake.lastReplyText, 'цитата');
      expect(fake.lastReplyAuthor, 'Чат');
      expect(controller.replyTo, isNull);
    });

    test('send(): правка — updateMessage, текст обновлён, edited=true',
        () async {
      final t = DateTime(2026, 8, 12, 10, 0);
      fake.messagesByChat['c1'] = [
        seed(id: 'm1', created: t, text: 'старое', incoming: false),
      ];
      await controller.load();

      controller.startEdit(0);
      expect(controller.editingIdx, 0);

      await controller.send('новое');
      expect(fake.lastUpdatedMessageId, 'm1');
      expect(fake.lastUpdatedText, 'новое');
      expect(controller.messages.first.text, 'новое');
      expect(controller.messages.first.edited, isTrue);
      expect(controller.editingIdx, isNull);
    });

    test('send(): ошибка бэкенда — onError без падения', () async {
      await controller.load();
      fake.throwOnSendText = true;

      await controller.send('привет');
      expect(errors, ['Не удалось отправить сообщение']);
      // Оптимистичный пузырь остаётся в ленте (не падаем, статус sending).
      expect(controller.messages.first.text, 'привет');
      expect(controller.messages.first.status, MsgStatus.sending);
    });

    test('sendSticker(): эмодзи-стикер уходит и подтверждается', () async {
      await controller.load();
      await controller.sendSticker('🔥');
      expect(controller.messages.first.stickerEmoji, '🔥');
      await pump();
      expect(controller.messages.first.status, MsgStatus.sent);
      expect(fake.lastStickerSent, '🔥');
    });

    test('sendVoice(): голосовое отправляется с файлом', () async {
      await controller.load();
      final file = File('${Directory.systemTemp.path}/voice.m4a');
      await controller.sendVoice(path: file.path, seconds: 12);
      expect(controller.messages.first.voiceSeconds, 12);
      await pump();
      expect(controller.messages.first.status, MsgStatus.sent);
      expect(fake.calls, contains('sendVoice(c1)'));
    });
  });

  group('ChatController — realtime', () {
    test('входящее в реальном времени: вставка наверх + newIncoming', () async {
      final t = DateTime(2026, 8, 12, 10, 0);
      fake.messagesByChat['c1'] = [seed(id: 'm1', created: t)];
      await controller.load();

      controller.onScroll(atBottom: false);
      fake.streamCtrl.add(fake.incomingMessage(text: 'свежее'));
      await pump();

      expect(controller.messages.first.text, 'свежее');
      expect(controller.newIncoming, 1);

      controller.jumpToBottom();
      expect(controller.newIncoming, 0);
      expect(controller.atBottom, isTrue);
    });

    test('typing: peerTyping загорается и гаснет через 4 секунды', () {
      FakeAsync().run((async) {
        var loaded = false;
        controller.load().then((_) => loaded = true);
        async.flushMicrotasks();
        expect(loaded, isTrue);

        fake.typingCtrl.add('c1');
        async.flushMicrotasks();
        expect(controller.peerTyping, isTrue);

        async.elapse(const Duration(seconds: 4));
        expect(controller.peerTyping, isFalse);
      });
    });

    test('msgEvents.edited: текст обновляется и помечается', () async {
      final t = DateTime(2026, 8, 12, 10, 0);
      fake.messagesByChat['c1'] = [
        seed(id: 'm1', created: t, text: 'было'),
      ];
      await controller.load();

      fake.msgEventsCtrl.add(VibeMsgEvent(
        type: VibeMsgEventType.edited,
        chatId: 'c1',
        messageId: 'm1',
        updated: seed(id: 'm1', created: t, text: 'стало'),
      ));
      await pump();

      expect(controller.messages.first.text, 'стало');
      expect(controller.messages.first.edited, isTrue);
    });

    test('msgEvents.deleted: сообщение исчезает из ленты', () async {
      final t = DateTime(2026, 8, 12, 10, 0);
      fake.messagesByChat['c1'] = [
        seed(id: 'm2', created: t.add(const Duration(minutes: 1))),
        seed(id: 'm1', created: t),
      ];
      await controller.load();

      fake.msgEventsCtrl.add(const VibeMsgEvent(
        type: VibeMsgEventType.deleted,
        chatId: 'c1',
        messageId: 'm1',
      ));
      await pump();

      expect(controller.messages.length, 1);
      expect(controller.messages.first.serverId, 'm2');
    });

    test('msgEvents.reactions: счётчики заменяются с сервера', () async {
      final t = DateTime(2026, 8, 12, 10, 0);
      fake.messagesByChat['c1'] = [
        seed(id: 'm1', created: t),
      ];
      await controller.load();

      fake.msgEventsCtrl.add(const VibeMsgEvent(
        type: VibeMsgEventType.reactions,
        chatId: 'c1',
        messageId: 'm1',
        reactions: {'🔥': 3, '❤️': 1},
      ));
      await pump();

      expect(controller.messages.first.reactions.length, 2);
      expect(controller.messages.first.reactions.any((r) =>
          r.emoji == '🔥' && r.count == 3), isTrue);
    });
  });

  group('ChatController — черновик', () {
    test('load(): восстанавливает сохранённый черновик', () async {
      SharedPreferences.setMockInitialValues({'vibe_drafts:c1': 'черновик'});
      await SettingsService.instance.init();

      await controller.load();
      expect(controller.draft, 'черновик');
    });

    test('saveDraft(): пишет в prefs с дебаунсом 400 мс', () {
      FakeAsync().run((async) {
        controller.saveDraft('привет');
        expect(SettingsService.instance.draftFor('c1'), isNull);
        async.elapse(const Duration(milliseconds: 400));
        expect(SettingsService.instance.draftFor('c1'), 'привет');
      });
    });

    test('send(): успешная отправка стирает черновик', () async {
      await SettingsService.instance.setDraft('c1', 'привет');
      await controller.load();

      await controller.send('привет');
      expect(controller.draft, '');
      expect(SettingsService.instance.draftFor('c1'), isNull);
    });

    test('clearDraft(): стирает черновик и отменяет таймер', () {
      FakeAsync().run((async) {
        controller.saveDraft('x');
        controller.clearDraft();
        async.elapse(const Duration(milliseconds: 400));
        expect(SettingsService.instance.draftFor('c1'), isNull);
      });
    });
  });

  group('ChatController — unread-jump', () {
    test('initialUnread=0: плашка не показывается', () async {
      final t = DateTime(2026, 8, 12, 10, 0);
      fake.messagesByChat['c1'] = [
        seed(id: 'm2', created: t.add(const Duration(minutes: 1))),
        seed(id: 'm1', created: t),
      ];
      await controller.load();
      expect(controller.unreadJumpIndex, isNull);
    });

    test('initialUnread>0: индекс первого непрочитанного', () async {
      final t = DateTime(2026, 8, 12, 10, 0);
      fake.messagesByChat['c1'] = [
        for (var i = 0; i < 10; i++)
          seed(id: 'm$i', created: t.add(Duration(minutes: i)), text: 'm$i'),
      ];
      controller.dispose();
      controller = ChatController(
        chatId: 'c1',
        chatTitle: 'Чат',
        onError: errors.add,
        initialUnread: 5,
        backend: fake,
      );
      await controller.load();

      expect(controller.unreadJumpIndex, 4);
    });

    test('jumpToUnread(): поднимает первое непрочитанное, flash, возврат', () {
      FakeAsync().run((async) {
        var loaded = false;
        final t = DateTime(2026, 8, 12, 10, 0);
        fake.messagesByChat['c1'] = [
          for (var i = 0; i < 10; i++)
            seed(id: 'm$i', created: t.add(Duration(minutes: i)), text: 'm$i'),
        ];
        controller.dispose();
        controller = ChatController(
          chatId: 'c1',
          chatTitle: 'Чат',
          onError: errors.add,
          initialUnread: 5,
          backend: fake,
        );
        controller.load().then((_) => loaded = true);
        async.flushMicrotasks();
        expect(loaded, isTrue);
        expect(controller.unreadJumpIndex, isNotNull);

        final jumpedId = controller.messages[4].serverId;
        controller.jumpToUnread();
        expect(controller.unreadJumpIndex, isNull);
        expect(controller.unreadFlashId, jumpedId);
        expect(controller.messages.first.serverId, jumpedId);

        async.elapse(const Duration(seconds: 3));
        expect(controller.unreadFlashId, isNull);
        expect(controller.messages[4].serverId, jumpedId);
      });
    });
  });

  group('ChatController — реакции', () {
    test('addReaction: включает и выключает эмодзи + вызов бэкенда',
        () async {
      final t = DateTime(2026, 8, 12, 10, 0);
      fake.messagesByChat['c1'] = [
        seed(id: 'm1', created: t),
      ];
      await controller.load();

      controller.addReaction(0, '🔥');
      expect(controller.messages.first.reactions.single.emoji, '🔥');
      expect(controller.messages.first.reactions.single.count, 1);
      expect(fake.reactions.single.emoji, '🔥');

      controller.addReaction(0, '🔥');
      expect(controller.messages.first.reactions, isEmpty);
    });

    test('heartReact: добавляет ❤️, повторно — убирает', () async {
      final t = DateTime(2026, 8, 12, 10, 0);
      fake.messagesByChat['c1'] = [
        seed(id: 'm1', created: t),
      ];
      await controller.load();

      controller.heartReact(0);
      expect(controller.messages.first.reactions.single.emoji, '❤️');

      controller.heartReact(0);
      expect(controller.messages.first.reactions, isEmpty);
    });
  });

  group('ChatController — действия', () {
    test('deleteMessage(everyone: true): сервер + локально', () async {
      final t = DateTime(2026, 8, 12, 10, 0);
      fake.messagesByChat['c1'] = [
        seed(id: 'm1', created: t, incoming: false),
      ];
      await controller.load();

      await controller.deleteMessage(controller.messages.first, everyone: true);
      expect(controller.messages, isEmpty);
      expect(fake.deleteCalls, ['m1']);
    });

    test('deleteMessage(everyone: false): локально + серверная пометка', () async {
      final t = DateTime(2026, 8, 12, 10, 0);
      fake.messagesByChat['c1'] = [
        seed(id: 'm1', created: t, incoming: false),
      ];
      await controller.load();

      await controller.deleteMessage(controller.messages.first, everyone: false);
      expect(controller.messages, isEmpty);
      expect(fake.deleteCalls, isEmpty);
      expect(fake.hiddenMessageIds, ['m1'],
          reason: '«удалить для меня» помечает сообщение на сервере');
    });

    test('setPin: сохраняет в SettingsService', () async {
      await controller.load();
      controller.setPin('m1');
      expect(controller.pinMsgId, 'm1');
      expect(SettingsService.instance.pinnedMessageId('c1'), 'm1');
    });

    test('notifyTyping: троттлинг 2.5с и пустая строка не отправляются',
        () async {
      controller.notifyTyping('a');
      expect(fake.sendTypingCalls, 1);
      controller.notifyTyping('ab');
      expect(fake.sendTypingCalls, 1);
      controller.notifyTyping('   ');
      expect(fake.sendTypingCalls, 1);
    });
  });
}
