// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/chat/chat_list_controller.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';

import 'fake_vibe_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVibeBackend fake;
  late ChatListController controller;
  final snacks = <String>[];

  VibeChat chat(String id, {int unread = 0, String lastMessage = ''}) {
    return VibeChat(
      id: id,
      title: 'Чат $id',
      kind: 'pm',
      lastMessage: lastMessage,
      lastTime: '',
      unread: unread,
      peerName: 'Пир $id',
      peerAvatar: null,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    fake = FakeVibeBackend();
    controller = ChatListController(onSnack: snacks.add, backend: fake);
    snacks.clear();
  });

  tearDown(() {
    controller.dispose();
    fake.close();
  });

  Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 10));

  test('load(): статусы из настроек + облака, первая загрузка ленты', () async {
    SharedPreferences.setMockInitialValues({
      'vibe_pinned_chats': ['c2'],
      'vibe_muted_chats': ['c3'],
    });
    await SettingsService.instance.init();
    fake.mutedNotifier.value = {'c4'};
    fake.archivedNotifier.value = {'c5'};
    fake.chatList = [chat('c1'), chat('c2')];

    await controller.load();

    expect(controller.pinned, {'c2'});
    expect(controller.dnd, {'c3', 'c4'});
    expect(controller.archived, {'c5'});
    expect(controller.chats.map((c) => c.id), ['c1', 'c2']);
  });

  test('typingEvents: isTyping включается и гаснет через 6 секунд', () async {
    fake.chatList = [chat('c1'), chat('c2')];
    await controller.load();

    expect(controller.isTyping('c1'), isFalse);

    fake.typingCtrl.add(TypingEvent(chatId: 'c1', userId: 'u1'));
    await pump();
    expect(controller.isTyping('c1'), isTrue);
    expect(controller.isTyping('c2'), isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 6100));
    expect(controller.isTyping('c1'), isFalse);
  });

  test('typingEvents: два чата печатают независимо', () async {
    fake.chatList = [chat('c1'), chat('c2')];
    await controller.load();

    fake.typingCtrl.add(TypingEvent(chatId: 'c1', userId: 'u1'));
    fake.typingCtrl.add(TypingEvent(chatId: 'c2', userId: 'u2'));
    await pump();
    expect(controller.isTyping('c1'), isTrue);
    expect(controller.isTyping('c2'), isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 6100));
    expect(controller.isTyping('c1'), isFalse);
    expect(controller.isTyping('c2'), isFalse);
  });

  test('loadChats(): сначала кэш, затем свежие данные', () async {
    fake.offlineCache = [chat('cached')];
    fake.chatList = [chat('fresh1'), chat('fresh2')];

    await controller.load();

    expect(controller.chats.length, 2);
    expect(controller.chats.first.id, 'fresh1');
    expect(fake.calls, contains('getOfflineChats'));
    expect(fake.calls, contains('listChats'));
  });

  test(
    'applyLivePreview: чат поднимается наверх с превью и временем',
    () async {
      fake.chatList = [
        chat('c1', unread: 3),
        chat('c2', unread: 1, lastMessage: 'старое'),
      ];
      await controller.load();

      fake.streamCtrl.add(
        VibeMessage(
          id: 'in1',
          chatId: 'c2',
          senderId: 'peer',
          senderName: 'Пир',
          senderAvatar: null,
          text: 'новое превью',
          voicePath: null,
          photoPath: null,
          videoPath: null,
          created: DateTime.now(),
          incoming: true,
        ),
      );
      await pump();

      expect(controller.chats.first.id, 'c2');
      expect(controller.chats.first.lastMessage, 'новое превью');
      expect(controller.chats.first.lastTime, isNotEmpty);
    },
  );

  test('unreadOf: локальная пометка «прочитано» зануляет счётчик', () {
    controller.read.add('c1');
    expect(controller.unreadOf(chat('c1', unread: 5)), 0);
    expect(controller.unreadOf(chat('c2', unread: 5)), 5);
  });

  group('ChatListController — мультивыбор', () {
    test('selectionMode и toggleSelect', () {
      expect(controller.selectionMode, isFalse);
      controller.toggleSelect('c1');
      expect(controller.selectionMode, isTrue);
      expect(controller.selected, {'c1'});
      controller.toggleSelect('c1');
      expect(controller.selectionMode, isFalse);
    });

    test('markRead: читает выделенные, чистит выбор, snack', () async {
      controller.toggleSelect('c1');
      controller.toggleSelect('c2');
      controller.markRead();

      expect(controller.read, {'c1', 'c2'});
      expect(controller.selected, isEmpty);
      expect(snacks, ['Прочитано']);
    });

    test('markArchived: архив + setChatArchived на сервер + snack', () async {
      controller.toggleSelect('c1');
      controller.toggleSelect('c2');
      controller.markArchived();

      expect(controller.archived, {'c1', 'c2'});
      expect(fake.setArchivedCalls, [
        (id: 'c1', archived: true),
        (id: 'c2', archived: true),
      ]);
      expect(snacks.single, startsWith('В архив'));
    });

    test('markHidden: скрытие в HMS-список + snack', () async {
      controller.toggleSelect('c1');
      controller.toggleSelect('c2');
      controller.markHidden();

      expect(controller.hidden, {'c1', 'c2'});
      expect(snacks.single, startsWith('Скрыто'));
    });

    test(
      'скрытие персистится: новый контроллер восстанавливает список',
      () async {
        controller.toggleSelect('c1');
        controller.markHidden();
        await pump();

        final restored = ChatListController(onSnack: (_) {}, backend: fake);
        await restored.load();
        await pump();

        expect(restored.hidden, {
          'c1',
        }, reason: 'скрытые чаты сохраняются между сессиями');
        restored.dispose();
      },
    );

    test('setHidden: скрыть/показать один чат + персистентность', () async {
      controller.setHidden('c1', hiddenNow: true);
      expect(controller.hidden, {'c1'});
      await pump();
      expect(SettingsService.instance.hiddenChats, ['c1']);

      controller.setHidden('c1', hiddenNow: false);
      expect(controller.hidden, isEmpty);
      await pump();
      expect(SettingsService.instance.hiddenChats, isEmpty);
    });

    test('syncHidden: изменение в другом месте синхронизируется', () async {
      await controller.load();
      await pump();
      await SettingsService.instance.setHiddenChats(['c7']);
      await pump();
      expect(controller.hidden, {'c7'});
    });

    test('removeSelected: чаты удаляются из ленты', () async {
      fake.chatList = [chat('c1'), chat('c2')];
      await controller.load();
      controller.toggleSelect('c2');
      controller.removeSelected();

      expect(controller.chats.single.id, 'c1');
      expect(snacks, ['Удалено']);
    });

    test('clearSelection: сброс выделения', () async {
      controller.toggleSelect('c1');
      controller.clearSelection();
      expect(controller.selected, isEmpty);
      expect(controller.selectionMode, isFalse);
    });
  });

  group('ChatListController — статусы чата', () {
    test('togglePin: закреп локально и в настройках', () async {
      controller.togglePin('c1');
      expect(controller.pinned, {'c1'});
      expect(SettingsService.instance.pinnedChats, ['c1']);

      controller.togglePin('c1');
      expect(controller.pinned, isEmpty);
      expect(SettingsService.instance.pinnedChats, isEmpty);
    });

    test('toggleDnd: DND вкл/выкл + setChatMuted на сервер', () async {
      controller.toggleDnd('c1');
      await pump();
      expect(controller.dnd, {'c1'});
      expect(fake.setMutedCalls, [(id: 'c1', muted: true)]);
      expect(SettingsService.instance.mutedChats, ['c1']);

      controller.toggleDnd('c1');
      await pump();
      expect(controller.dnd, isEmpty);
      expect(fake.setMutedCalls, [
        (id: 'c1', muted: true),
        (id: 'c1', muted: false),
      ]);
    });

    test(
      'toggleArchived: архив вкл/выкл + setChatArchived на сервер',
      () async {
        controller.toggleArchived('c1');
        await pump();
        expect(controller.archived, {'c1'});
        expect(fake.setArchivedCalls, [(id: 'c1', archived: true)]);

        controller.toggleArchived('c1');
        await pump();
        expect(controller.archived, isEmpty);
        expect(fake.setArchivedCalls, [
          (id: 'c1', archived: true),
          (id: 'c1', archived: false),
        ]);
      },
    );

    test('markChatRead: точечная пометка из меню чата', () async {
      controller.markChatRead('c1');
      expect(controller.read, {'c1'});
    });

    test(
      'syncCloudMuted: облачный DND переносится в локальный + настройки',
      () async {
        fake.mutedNotifier.value = {'x1', 'x2'};
        controller.syncCloudMuted();
        expect(controller.dnd, {'x1', 'x2'});
        expect(SettingsService.instance.mutedChats, containsAll(['x1', 'x2']));
      },
    );

    test('syncCloudArchive: облачный архив переносится локально', () async {
      fake.archivedNotifier.value = {'a1'};
      controller.syncCloudArchive();
      expect(controller.archived, {'a1'});
    });
  });

  group('presence-троттлинг (5.2)', () {
    int listChatsCalls() => fake.calls.where((c) => c == 'listChats').length;

    test(
      'шквал presence-событий: 1 мгновенная перезагрузка + хвост через паузу',
      () async {
        fake.chatList = [chat('c1')];
        await controller.load();
        expect(listChatsCalls(), 1);

        for (var i = 0; i < 5; i++) {
          fake.presenceNotifier.value++;
        }
        await pump();
        expect(listChatsCalls(), 2);

        await Future<void>.delayed(const Duration(milliseconds: 2500));
        expect(listChatsCalls(), 3);

        await Future<void>.delayed(const Duration(milliseconds: 3000));
        expect(listChatsCalls(), 3);
      },
    );

    test(
      'событие после паузы дольше интервала — мгновенная перезагрузка',
      () async {
        await controller.load();
        expect(listChatsCalls(), 1);

        fake.presenceNotifier.value++;
        await pump();
        expect(listChatsCalls(), 2);

        await Future<void>.delayed(const Duration(milliseconds: 2200));
        fake.presenceNotifier.value++;
        await pump();
        expect(listChatsCalls(), 3);

        await Future<void>.delayed(const Duration(milliseconds: 2500));
        expect(listChatsCalls(), 3);
      },
    );
  });

  group('дельта-обновление ленты (5.8)', () {
    test('идентичная копия с сервера — без notify и пересборки', () async {
      var notifies = 0;
      controller.addListener(() => notifies++);
      fake.chatList = [chat('c1'), chat('c2')];
      await controller.load();
      notifies = 0;

      await controller.loadChats();
      expect(notifies, 0);
      expect(controller.chats.length, 2);
      expect(controller.chats[1].id, 'c2');
    });

    test('изменение одной карточки — один notify со свежими данными', () async {
      var notifies = 0;
      controller.addListener(() => notifies++);
      fake.chatList = [chat('c1'), chat('c2')];
      await controller.load();
      notifies = 0;

      fake.chatList = [chat('c1', unread: 3), chat('c2')];
      await controller.loadChats();
      expect(notifies, 1);
      expect(controller.chats.first.unread, 3);
    });

    test('новый чат в ленте — полная замена с пересборкой', () async {
      var notifies = 0;
      controller.addListener(() => notifies++);
      fake.chatList = [chat('c1')];
      await controller.load();
      notifies = 0;

      fake.chatList = [chat('c2'), chat('c1')];
      await controller.loadChats();
      expect(notifies, 1);
      expect(controller.chats.first.id, 'c2');
    });
  });

  test('8.3.2: удалённый для себя чат исчезает из ленты и из кэша', () async {
    fake.chatList = [chat('c1'), chat('c2')];
    await controller.load();
    expect(controller.chats.map((c) => c.id), ['c1', 'c2']);

    final ids = [...SettingsService.instance.deletedChats, 'c2'];
    await SettingsService.instance.setDeletedChats(ids);
    await controller.loadChats();

    expect(
      controller.chats.map((c) => c.id),
      ['c1'],
      reason: 'удалённый чат не возвращается при перезагрузке ленты',
    );
  });

  test(
    'markArchived: архивирует ТОЛЬКО выбранные, не все ранее архивированные',
    () async {
      // Pre-populate archived with c5.
      fake.archivedNotifier.value = {'c5'};
      await controller.load();
      expect(controller.archived, {'c5'});

      // Select only c1 and archive.
      controller.toggleSelect('c1');
      controller.markArchived();

      // c5 must remain archived; c1 must be added; c2 must NOT be archived.
      expect(controller.archived, contains('c1'));
      expect(controller.archived, contains('c5'));
      expect(
        controller.archived.length,
        2,
        reason: 'only c1 and c5 should be archived, not c2',
      );
      expect(fake.setArchivedCalls, [(id: 'c1', archived: true)]);
    },
  );
}
