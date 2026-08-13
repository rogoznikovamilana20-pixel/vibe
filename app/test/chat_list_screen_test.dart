import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/core/localization/vibe_localizations.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/passcode_service.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/screens/chat_list_screen.dart';

import 'fake_vibe_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVibeBackend fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    fake = FakeVibeBackend();
  });

  tearDown(() {
    fake.close();
  });

  VibeChat chatX({
    required String id,
    required String title,
    String lastMessage = '',
    int unread = 0,
  }) {
    return VibeChat(
      id: id,
      title: title,
      kind: 'pm',
      lastMessage: lastMessage,
      lastTime: '12:00',
      unread: unread,
      peerName: title,
      peerAvatar: null,
    );
  }

  Future<void> pumpList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3240);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: VibeTheme.light(),
        localizationsDelegates: const [VibeLocalizationsDelegate()],
        supportedLocales: const [Locale('ru'), Locale('en')],
        home: ChatListScreen(userName: 'Андрей', backend: fake),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('лента: названия, превью, непрочитанные', (tester) async {
    fake.chatList = [
      chatX(id: 'c1', title: 'Иван', lastMessage: 'Привет!', unread: 2),
      chatX(id: 'c2', title: 'Мария'),
    ];

    await pumpList(tester);

    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('Мария'), findsOneWidget);
    expect(find.text('Привет!'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('плитка «Сохранённые» — первый элемент основного списка',
      (tester) async {
    fake.chatList = [chatX(id: 'c1', title: 'Иван')];

    await pumpList(tester);

    expect(find.text('Сохранённые'), findsOneWidget);
    expect(find.text('Избранные сообщения'), findsOneWidget);
  });

  testWidgets('realtime: новое входящее обновляет превью чата',
      (tester) async {
    fake.chatList = [chatX(id: 'c1', title: 'Иван', lastMessage: 'старое')];

    await pumpList(tester);
    expect(find.text('старое'), findsOneWidget);

    fake.streamCtrl.add(fake.incomingMessage(chatId: 'c1', text: 'живое'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('живое'), findsOneWidget);
    expect(find.text('старое'), findsNothing);
  });

  testWidgets('свайп вправо по чату → архив (setChatArchived)', (tester) async {
    fake.chatList = [
      chatX(id: 'c1', title: 'Иван', lastMessage: 'Привет!'),
    ];

    await pumpList(tester);

    await tester.drag(find.text('Иван'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(fake.setArchivedCalls, isNotEmpty);
    expect(fake.setArchivedCalls.first.id, 'c1');
    expect(fake.setArchivedCalls.first.archived, isTrue);
  });

  testWidgets('длинное нажатие → меню → «Выбрать чаты» → режим выбора',
      (tester) async {
    fake.chatList = [
      chatX(id: 'c1', title: 'Иван', lastMessage: 'Привет!'),
      chatX(id: 'c2', title: 'Мария'),
    ];

    await pumpList(tester);

    await tester.longPress(find.text('Иван'));
    await tester.pumpAndSettle();

    expect(find.text('Выбрать чаты'), findsOneWidget);
    await tester.tap(find.text('Выбрать чаты'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.clear_rounded), findsNothing);
  });

  testWidgets('навигация: тап по чату → ChatScreen с тем же backend → назад',
      (tester) async {
    fake.chatList = [chatX(id: 'c1', title: 'Иван', lastMessage: 'Привет!')];
    fake.messagesByChat['c1'] = [
      fake.incomingMessage(chatId: 'c1', text: 'сообщение из чата', id: 'm1'),
    ];

    await pumpList(tester);

    await tester.tap(find.text('Иван'));
    await tester.pumpAndSettle();

    expect(find.text('сообщение из чата'), findsOneWidget,
        reason: 'ChatScreen должен получить от чат-листа тот же backend');
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('Привет!'), findsOneWidget);
  });

  testWidgets('скрытые чаты: нет в ленте, чип-счётчик, без пасскода — диалог',
      (tester) async {
    fake.chatList = [
      chatX(id: 'c1', title: 'Иван'),
      chatX(id: 'c2', title: 'Мария'),
    ];
    await SettingsService.instance.setHiddenChats(['c2']);

    await pumpList(tester);

    expect(find.text('Мария'), findsNothing,
        reason: 'скрытый чат не показывается в основном списке');
    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('Скрытые чаты'), findsOneWidget);

    await tester.tap(find.text('Скрытые чаты'));
    await tester.pumpAndSettle();

    expect(find.text('Защита скрытых чатов'), findsOneWidget,
        reason: 'без пасскода — предложение установить код-пароль');
    expect(find.text('Мария'), findsNothing,
        reason: 'папка скрытых не открылась без пароля');
  });

  testWidgets('скрытые чаты: ввод пасскода в LockScreen открывает папку',
      (tester) async {
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final store = <String, String>{
      'vibe_passcode':
          'salt:${sha256.convert(utf8.encode('salt:1234')).toString()}',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'read':
          return store[call.arguments['key']];
        case 'write':
          store[call.arguments['key']] = call.arguments['value'] as String;
          return null;
        case 'delete':
          store.remove(call.arguments['key']);
          return null;
        case 'readAll':
          return store;
      }
      return null;
    });
    await PasscodeService.instance.init();
    expect(PasscodeService.instance.hasPasscode, isTrue);

    fake.chatList = [
      chatX(id: 'c1', title: 'Иван'),
      chatX(id: 'c2', title: 'Мария'),
    ];
    await SettingsService.instance.setHiddenChats(['c2']);

    await pumpList(tester);

    await tester.tap(find.text('Скрытые чаты'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(Pinput), findsOneWidget,
        reason: 'перед папкой скрытых — полноэкранный ввод пасскода');

    await tester.enterText(find.byType(Pinput), '1234');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Мария'), findsOneWidget,
        reason: 'после разблокировки скрытый чат виден в папке');
    expect(find.text('Иван'), findsNothing);
  });
}