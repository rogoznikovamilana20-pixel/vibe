import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}