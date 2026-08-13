import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/chat/chat_controller.dart';
import 'package:vibe_app/chat/models.dart';
import 'package:vibe_app/core/services/scheduled_service.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/core/widgets/vibe_avatar.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/screens/chat_screen.dart';

import 'fake_vibe_backend.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVibeBackend fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    fake = FakeVibeBackend();
    VibeNetImage.resolveUrl = (_) async => null;
    ScheduledService.instance.debugReset();
    ScheduledService.instance.backendProvider = () => fake;
  });

  tearDown(() {
    ScheduledService.instance.debugReset();
    fake.close();
  });

  VibeChat chatFor() => VibeChat(
        id: 'c1',
        title: 'Иван',
        kind: 'pm',
        lastMessage: '',
        lastTime: '',
        unread: 0,
        peerName: 'Иван',
        peerAvatar: null,
      );

  Future<void> pumpChat(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3240);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: VibeTheme.light(),
        home: ChatScreen(chat: chatFor(), backend: fake),
      ),
    );
    await tester.pumpAndSettle();
  }

Future<void> openAttachmentMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(VibeIcons.attach));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('8.3.3 меню вложений: все плитки на месте', (tester) async {
    await pumpChat(tester);
    await openAttachmentMenu(tester);

    for (final label in ['Фото', 'Голос', 'Медиа', 'Файл', 'Локация', 'Контакт', 'Опрос']) {
      expect(find.text(label), findsOneWidget, reason: 'плитка $label');
    }
  });

  testWidgets('8.3.3 файл: sendFile → карточка с именем и размером',
      (tester) async {
    final f = File('${Directory.systemTemp.path}/vibe_doc.pdf')
      ..writeAsStringSync('hello');
    addTearDown(() {
      if (f.existsSync()) f.deleteSync();
    });

    final c = ChatController(
      chatId: 'c1',
      chatTitle: 'Иван',
      onError: (_) {},
      backend: fake,
    );
    await c.sendFile(f);

    expect(fake.calls, contains('sendFile(c1)'));
    final m = c.messages.first;
    expect(m.type, MsgType.file);
    expect(m.attachment, isNotNull);
    expect(m.attachment!.kind, AttachmentKind.file);
    expect(m.attachment!.name, 'vibe_doc.pdf');
    expect(m.attachment!.size, 5);

    await pumpChat(tester);
    fake.streamCtrl.add(
      VibeMessage(
        id: 'file-1',
        chatId: 'c1',
        senderId: 'peer',
        senderName: 'Иван',
        senderAvatar: null,
        voicePath: null,
        photoPath: null,
        videoPath: null,
        stickerEmoji: null,
        text: AttachmentData.encode(
          kind: AttachmentKind.file,
          name: 'док.pdf',
          size: 2048,
          mime: 'application/pdf',
          url: 'media/c1/док.pdf',
        ),
        created: DateTime(2026, 8, 13, 12),
        incoming: true,
        status: MsgStatus.sent,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

expect(find.text('док.pdf'), findsOneWidget);
    expect(find.text('2.0 КБ'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('8.3.3 локация: диалог координат → карточка + карты',
      (tester) async {
    await pumpChat(tester);
    await openAttachmentMenu(tester);

    await tester.tap(find.text('Локация'));
    await tester.pumpAndSettle();

    final locFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(locFields.at(0), '55.7558');
    await tester.enterText(locFields.at(1), '37.6173');
    await tester.enterText(locFields.at(2), 'Москва');
    await tester.tap(find.text('Отправить'));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(fake.lastTextSent, contains('"kind":"location"'));
    expect(find.text('Москва'), findsWidgets);
    expect(find.text('55.755800, 37.617300'), findsOneWidget);
    expect(find.text('Открыть в картах'), findsOneWidget);
    expect(fake.calls, contains('sendText(c1)'));
  });

  testWidgets('8.3.3 локация: невалидные координаты — подсказка, без отправки',
      (tester) async {
    await pumpChat(tester);
    await openAttachmentMenu(tester);
    await tester.tap(find.text('Локация'));
    await tester.pumpAndSettle();

    final locFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(locFields.at(0), '999');
    await tester.enterText(locFields.at(1), '999');
    await tester.tap(find.text('Отправить'));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(fake.lastTextSent, isNull);
    expect(find.text('Введите валидные координаты'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('8.3.3 контакт: выбор из контактов → визитка с кнопкой',
      (tester) async {
    fake.contacts = [
      const VibeProfile(
        id: 'u9',
        username: 'masha',
        displayName: 'Маша',
      ),
    ];
    await pumpChat(tester);
    await openAttachmentMenu(tester);
    await tester.tap(find.text('Контакт'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('listContacts()'));
    await tester.tap(find.text('Маша'));
    await tester.pumpAndSettle();

    expect(fake.lastTextSent, contains('"kind":"contact"'));
    expect(find.text('@masha'), findsOneWidget);
    expect(find.text('Написать'), findsOneWidget);
  });

  testWidgets('8.3.3 опрос: создание, голосование, счётчик', (tester) async {
    await pumpChat(tester);
    await openAttachmentMenu(tester);
    await tester.tap(find.text('Опрос'));
    await tester.pumpAndSettle();

    final pollFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(pollFields.at(0), 'Чай или кофе?');
    await tester.enterText(pollFields.at(1), 'Чай');
    await tester.enterText(pollFields.at(2), 'Кофе');
    await tester.tap(find.text('Опубликовать'));
    await tester.pumpAndSettle();

    expect(fake.lastTextSent, contains('"kind":"poll"'));
    expect(find.text('Чай или кофе?'), findsOneWidget);
    expect(find.text('Чай'), findsOneWidget);
    expect(find.text('Кофе'), findsOneWidget);
    expect(find.text('0 голосов'), findsOneWidget);

    // Голосуем за «Чай».
    final before = fake.lastTextSent;
    await tester.tap(find.text('Чай'));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(fake.lastTextSent, isNot(before));
    expect(fake.lastTextSent, contains('"kind":"pollVote"'));
    expect(fake.lastTextSent, contains('"opt":0'));
    expect(find.text('1 голос'), findsOneWidget);
  });

  testWidgets('8.3.3 опрос: входящие голоса считаются (2 голоса)',
      (tester) async {
    final pollJson = AttachmentData.encode(
      kind: AttachmentKind.poll,
      question: 'Куда поедем?',
      options: const ['Море', 'Горы'],
    );
    fake.messagesByChat['c1'] = [
      VibeMessage(
        id: 'poll-1',
        chatId: 'c1',
        senderId: 'peer',
        senderName: 'Иван',
        senderAvatar: null,
        voicePath: null,
        photoPath: null,
        videoPath: null,
        stickerEmoji: null,
        text: pollJson,
        created: DateTime(2026, 8, 13, 12),
        incoming: true,
        status: MsgStatus.sent,
      ),
      VibeMessage(
        id: 'vote-1',
        chatId: 'c1',
        senderId: 'peer',
        senderName: 'Иван',
        senderAvatar: null,
        voicePath: null,
        photoPath: null,
        videoPath: null,
        stickerEmoji: null,
        text: AttachmentData.encode(
          kind: AttachmentKind.pollVote,
          pollId: 'poll-1',
          opt: 1,
        ),
        created: DateTime(2026, 8, 13, 12, 1),
        incoming: true,
        status: MsgStatus.sent,
      ),
      VibeMessage(
        id: 'vote-2',
        chatId: 'c1',
        senderId: 'other',
        senderName: 'Петя',
        senderAvatar: null,
        voicePath: null,
        photoPath: null,
        videoPath: null,
        stickerEmoji: null,
        text: AttachmentData.encode(
          kind: AttachmentKind.pollVote,
          pollId: 'poll-1',
          opt: 1,
        ),
        created: DateTime(2026, 8, 13, 12, 2),
        incoming: true,
        status: MsgStatus.sent,
      ),
    ];

    await pumpChat(tester);

    expect(find.text('Куда поедем?'), findsOneWidget);
    expect(find.text('2 голоса'), findsOneWidget);
    // Скрытые голоса не дают пузырей.
    expect(find.textContaining('poll_vote'), findsNothing);
  });

  test('computePollVotes: считает голоса по вариантам', () {
    final msgs = [
      ChatMsg(
        type: MsgType.pollVote,
        incoming: true,
        time: '12:00',
        serverId: 'v1',
        attachment: const AttachmentData(
          kind: AttachmentKind.pollVote,
          pollId: 'p1',
          opt: 0,
        ),
      ),
      ChatMsg(
        type: MsgType.pollVote,
        incoming: true,
        time: '12:01',
        serverId: 'v2',
        attachment: const AttachmentData(
          kind: AttachmentKind.pollVote,
          pollId: 'p1',
          opt: 2,
        ),
      ),
      ChatMsg(
        type: MsgType.pollVote,
        incoming: false,
        time: '12:02',
        serverId: 'v3',
        attachment: const AttachmentData(
          kind: AttachmentKind.pollVote,
          pollId: 'p1',
          opt: 0,
        ),
      ),
      ChatMsg(
        type: MsgType.pollVote,
        incoming: true,
        time: '12:03',
        serverId: 'v4',
        attachment: const AttachmentData(
          kind: AttachmentKind.pollVote,
          pollId: 'other',
          opt: 0,
        ),
      ),
    ];

    expect(computePollVotes(msgs, 'p1'), [2, 0, 1]);
    expect(myPollVote(msgs, 'p1'), 0);
    expect(myPollVote(msgs, 'other'), null);
  });

  test('AttachmentData: круговая кодировка/декодировка', () {
    final json = AttachmentData.encode(
      kind: AttachmentKind.location,
      lat: 55.7558,
      lng: 37.6173,
      label: 'Москва',
    );
    final parsed = AttachmentData.tryParse(json);
    expect(parsed, isNotNull);
    expect(parsed!.kind, AttachmentKind.location);
    expect(parsed.lat, closeTo(55.7558, 1e-9));
    expect(parsed.lng, closeTo(37.6173, 1e-9));
    expect(parsed.label, 'Москва');

    expect(AttachmentData.tryParse('просто текст'), isNull);
    expect(AttachmentData.tryParse('{"no":"kind"}'), isNull);
    expect(AttachmentData.tryParse('{broken'), isNull);
  });
}