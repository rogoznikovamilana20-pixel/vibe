import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/chat/widgets/message_bubble.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/core/widgets/vibe_avatar.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/screens/chat_screen.dart';

import 'fake_vibe_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVibeBackend fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    fake = FakeVibeBackend();
    VibeNetImage.resolveUrl = (_) async => null;
  });

  tearDown(() {
    fake.close();
  });

  VibeChat chatFor({int unread = 0}) => VibeChat(
        id: 'c1',
        title: 'Иван',
        kind: 'pm',
        lastMessage: '',
        lastTime: '',
        unread: unread,
        peerName: 'Иван',
        peerAvatar: null,
      );

  VibeMessage msg({
    required String id,
    required String text,
    bool incoming = true,
    DateTime? created,
    String? localId,
    MsgStatus status = MsgStatus.sent,
    bool edited = false,
  }) {
    return VibeMessage(
      id: id,
      chatId: 'c1',
      senderId: incoming ? 'peer' : 'me',
      senderName: incoming ? 'Иван' : 'Я',
      senderAvatar: null,
      text: text,
      voicePath: null,
      photoPath: null,
      videoPath: null,
      created: created ?? DateTime(2026, 8, 13, 12),
      incoming: incoming,
      status: status,
      localId: localId,
      stickerEmoji: null,
      edited: edited,
    );
  }

  Future<void> pumpChat(WidgetTester tester, {int unread = 0}) async {
    tester.view.physicalSize = const Size(1080, 3240);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: VibeTheme.light(),
        home: ChatScreen(chat: chatFor(unread: unread), backend: fake),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('вход: заголовок, лента сообщений, композер', (tester) async {
    fake.messagesByChat['c1'] = [
      msg(id: 'm1', text: 'Позже всех'),
      msg(id: 'm2', text: 'Раньше', incoming: false),
    ];

    await pumpChat(tester);

    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('Позже всех'), findsOneWidget);
    expect(find.text('Раньше'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });

  testWidgets('пустой ввод: кнопка — микрофон, отправка недоступна',
      (tester) async {
    await pumpChat(tester);

    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
  });

  testWidgets('отправка текста: sendText + сообщение в ленте', (tester) async {
    await pumpChat(tester);

    await tester.enterText(find.byType(TextField), 'привет');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(fake.lastTextSent, 'привет');
    expect(fake.calls, contains('sendText(c1)'));
    expect(find.text('привет'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
      reason: 'поле очищается после отправки',
    );
  });

  testWidgets('realtime: входящее сообщение появляется в ленте',
      (tester) async {
    await pumpChat(tester);

    fake.streamCtrl.add(fake.incomingMessage(chatId: 'c1', text: 'внезапно'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('внезапно'), findsOneWidget);
  });

  testWidgets('realtime: подтверждение исходящего (ack по localId)',
      (tester) async {
    await pumpChat(tester);

    await tester.enterText(find.byType(TextField), 'в пути');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(find.text('в пути'), findsOneWidget);
  });

  testWidgets('сетевой сбой отправки: ошибка не роняет экран, snack показан',
      (tester) async {
    fake.throwOnSendText = true;
    await pumpChat(tester);

    await tester.enterText(find.byType(TextField), 'упасть');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('плашка «Непрочитанные: N» видна и прыгает к первому',
      (tester) async {
    fake.messagesByChat['c1'] = [
      msg(id: 'm1', text: 'новое-1'),
      msg(id: 'm2', text: 'новое-2'),
      msg(id: 'm3', text: 'старое-1'),
    ];

    await pumpChat(tester, unread: 2);

    expect(find.textContaining('Непрочитанные: 2'), findsOneWidget);

    await tester.tap(find.textContaining('Непрочитанные: 2'));
    await tester.pumpAndSettle();
  });

  testWidgets('правка сообщения по меню → updateMessage', (tester) async {
    fake.messagesByChat['c1'] = [
      msg(id: 'm1', text: 'исправь меня', incoming: false),
    ];

    await pumpChat(tester);

    await tester.longPress(find.text('исправь меня'));
    await tester.pumpAndSettle();

    expect(find.text('Редактировать'), findsOneWidget);
    await tester.ensureVisible(find.text('Редактировать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'исправь меня',
      reason: 'текст подставляется в композер для правки',
    );
  });

  testWidgets('удаление по меню: «Удалить для всех» → deleteMessage',
      (tester) async {
    fake.messagesByChat['c1'] = [
      msg(id: 'm1', text: 'удалить меня', incoming: false),
    ];

    await pumpChat(tester);

    await tester.longPress(find.text('удалить меня'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Удалить для всех'));
    await tester.pumpAndSettle();

    expect(fake.deleteCalls, ['m1']);
    expect(find.text('удалить меня'), findsNothing);
  });

  testWidgets('удаление по меню: «Удалить для меня» — только локально',
      (tester) async {
    fake.messagesByChat['c1'] = [
      msg(id: 'm1', text: 'удалить локально', incoming: false),
    ];

    await pumpChat(tester);

    await tester.longPress(find.text('удалить локально'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Удалить для меня'));
    await tester.pumpAndSettle();

    expect(fake.deleteCalls, isEmpty);
    expect(find.text('удалить локально'), findsNothing);
  });

  testWidgets('закрепление по меню: плашка «Закреплённое», открепление',
      (tester) async {
    fake.messagesByChat['c1'] = [
      msg(id: 'm1', text: 'закрепи меня', incoming: false),
    ];

    await pumpChat(tester);

    await tester.longPress(find.text('закрепи меня'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Закрепить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закрепить'));
    await tester.pumpAndSettle();

    expect(
      find.text('закрепи меня'),
      findsNWidgets(2),
      reason: 'текст в пузыре + плашка закреплённого под шапкой',
    );

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('закрепи меня'), findsOneWidget);
  });

  testWidgets('отмена отправки: пилюля в окне, тап удаляет и возвращает текст',
      (tester) async {
    await pumpChat(tester);

    await tester.enterText(find.byType(TextField), 'ошибочное сообщение');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Отменить отправку'), findsOneWidget,
        reason: 'окно отмены открыто после отправки');

    await tester.tap(find.text('Отменить отправку'));
    await tester.pumpAndSettle();

    expect(find.text('ошибочное сообщение'), findsOneWidget,
        reason: 'пузырь удалён, текст остался только в поле ввода');
    expect(fake.deleteCalls, isNotEmpty, reason: 'серверное удаление');
    expect(find.text('Отменить отправку'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'ошибочное сообщение',
      reason: 'текст вернулся в поле ввода',
    );
  });

  testWidgets('два закрепа: баннер «ещё 1», тап → список всех, откреп',
      (tester) async {
    fake.messagesByChat['c1'] = [
      msg(id: 'm1', text: 'первый закреп'),
      msg(id: 'm2', text: 'второй закреп'),
    ];
    fake.pinsByChat['c1'] = ['m2', 'm1'];

    await pumpChat(tester);

    expect(find.text('ещё 1'), findsOneWidget,
        reason: 'баннер: верхний закреп + счётчик остальных');

    await tester.tap(find.byIcon(Icons.push_pin_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Закреплённые сообщения'), findsOneWidget);
    final inSheet = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.textContaining('закреп'),
    );
    expect(inSheet, findsNWidgets(2), reason: 'в шите обе строки закрепов');

    await tester.tap(find.descendant(
      of: find.widgetWithText(ListTile, 'первый закреп'),
      matching: find.byIcon(Icons.close_rounded),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Закреплённые сообщения'), findsNothing);
    expect(fake.unpinCalls, [(chatId: 'c1', messageId: 'm1')]);
  });

  testWidgets('пересылка: меню → выбор чата → forwardMessage в цель',
      (tester) async {
    fake.messagesByChat['c1'] = [
      msg(id: 'm1', text: 'перешли меня', incoming: false),
    ];
    fake.chatList = [
      VibeChat(
        id: 'c2',
        title: 'Мария',
        kind: 'pm',
        lastMessage: '',
        lastTime: '',
        unread: 0,
        peerName: 'Мария',
        peerAvatar: null,
      ),
    ];

    await pumpChat(tester);

    await tester.longPress(find.text('перешли меня'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Переслать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переслать'));
    await tester.pumpAndSettle();

    expect(find.text('Выберите чаты'), findsOneWidget);

    await tester.tap(find.text('Мария'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отправить'));
    await tester.pumpAndSettle();

    expect(fake.forwardCalls, [(chatId: 'c2', text: 'перешли меня')]);
  });

  testWidgets('история правок: меню у изменённого → снимки текста в шите',
      (tester) async {
    fake.messagesByChat['c1'] = [
      msg(id: 'm1', text: 'текущая версия', incoming: false, edited: true),
    ];
    fake.messageEditsByMessage['m1'] = [
      MessageEdit(
        messageId: 'm1',
        text: 'вторая версия',
        editedAt: DateTime(2026, 8, 13, 11),
      ),
      MessageEdit(
        messageId: 'm1',
        text: 'первая версия',
        editedAt: DateTime(2026, 8, 13, 10),
      ),
    ];

    await pumpChat(tester);

    await tester.longPress(find.text('текущая версия'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('История правок'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('История правок'));
    await tester.pumpAndSettle();

    expect(find.text('вторая версия'), findsOneWidget);
    expect(find.text('первая версия'), findsOneWidget);
    expect(fake.calls, contains('listMessageEdits(m1)'));
  });

  testWidgets('очистить историю: меню чата → подтверждение → clearHistory',
      (tester) async {
    fake.messagesByChat['c1'] = [
      msg(id: 'm1', text: 'старое сообщение'),
    ];

    await pumpChat(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Очистить историю'), findsOneWidget);
    await tester.tap(find.text('Очистить историю'));
    await tester.pumpAndSettle();

    expect(find.text('Очистить историю?'), findsOneWidget);

    await tester.tap(find.text('Очистить'));
    await tester.pumpAndSettle();

    expect(fake.clearHistoryCalls, ['c1']);
    expect(find.text('старое сообщение'), findsNothing);
  });

  testWidgets('свёртка цепочек: флаги группы у пузырей', (tester) async {
    final t0 = DateTime(2026, 8, 13, 12);
    fake.messagesByChat['c1'] = [
      msg(
        id: 'm1',
        text: 'третье',
        created: t0.add(const Duration(minutes: 2)),
      ),
      msg(
        id: 'm2',
        text: 'второе',
        created: t0.add(const Duration(minutes: 1)),
      ),
      msg(id: 'm3', text: 'первое', created: t0),
      msg(
        id: 'm4',
        text: 'своё',
        incoming: false,
        created: t0.subtract(const Duration(minutes: 1)),
      ),
    ];

    await pumpChat(tester);

    final bubbles = tester
        .widgetList<MessageBubble>(find.byType(MessageBubble))
        .toList();
    expect(bubbles, hasLength(4));
    expect(bubbles.map((b) => b.msg.text).toList(),
        ['третье', 'второе', 'первое', 'своё']);

    expect(bubbles[0].isFirstInGroup, isFalse);
    expect(bubbles[0].isLastInGroup, isTrue,
        reason: 'нижнее сообщение группы входящих — последнее');
    expect(bubbles[1].isFirstInGroup, isFalse);
    expect(bubbles[1].isLastInGroup, isFalse,
        reason: 'середина группы — не край');
    expect(bubbles[2].isFirstInGroup, isTrue,
        reason: 'верхнее сообщение группы — первое');
    expect(bubbles[2].isLastInGroup, isFalse);
    expect(bubbles[3].isFirstInGroup, isTrue);
    expect(bubbles[3].isLastInGroup, isTrue,
        reason: 'одиночное исходящее — и первое, и последнее');
  });
}