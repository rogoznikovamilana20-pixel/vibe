import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/screens/chat_list_screen.dart';
import 'package:vibe_app/screens/chat_screen.dart';
import 'package:vibe_app/chat/models.dart';

import 'fake_vibe_backend.dart';

/// 9.6 (MASTER_PLAN): PERF-регрессионные бенчмарки в widget-тестах.
/// Бюджеты щедрые (CI-машины медленные): цель — ловить O(n²)/регрессии
/// рендера, а не микро-профилировать.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  VibeChat chatX(String id, String title) => VibeChat(
        id: id,
        title: title,
        kind: 'pm',
        lastMessage: 'сообщение #$id',
        lastTime: '12:00',
        unread: 0,
        peerName: title,
        peerAvatar: null,
      );

  testWidgets('PERF: старт ленты — 300 чатов рендерятся в бюджете',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3240);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final fake = FakeVibeBackend();
    addTearDown(fake.close);
    fake.chatList = [for (var i = 0; i < 300; i++) chatX('c$i', 'Чат $i')];

    final sw = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        theme: VibeTheme.light(),
        home: ChatListScreen(userName: 'Андрей', backend: fake),
      ),
    );
    await tester.pumpAndSettle();
    sw.stop();

    // ignore: avoid_print
    print('PERF лента(300): ${sw.elapsedMilliseconds} мс');
    expect(sw.elapsed, lessThan(const Duration(seconds: 8)),
        reason: '300 чатов должны отрисоваться без деградации рендера');
    expect(find.text('Чат 0'), findsOneWidget);
  });

  testWidgets('PERF: скролл ленты 300 чатов — без падений и зависаний',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3240);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final fake = FakeVibeBackend();
    addTearDown(fake.close);
    fake.chatList = [for (var i = 0; i < 300; i++) chatX('c$i', 'Чат $i')];

    await tester.pumpWidget(
      MaterialApp(
        theme: VibeTheme.light(),
        home: ChatListScreen(userName: 'Андрей', backend: fake),
      ),
    );
    await tester.pumpAndSettle();

    final sw = Stopwatch()..start();
    var total = 0.0;
    for (var i = 0; i < 5; i++) {
      await tester.fling(
          find.byType(CustomScrollView).hitTestable().first,
          const Offset(0, -1200),
          6000);
      await tester.pumpAndSettle();
      total += 1200;
    }
    sw.stop();

    // ignore: avoid_print
    print('PERF скролл(300, x5 флинг): ${sw.elapsedMilliseconds} мс');
    expect(sw.elapsed, lessThan(const Duration(seconds: 8)),
        reason: 'флинговые скроллы не должны деградировать');
    expect(tester.takeException(), isNull);
  });

  testWidgets('PERF: чат со 150 сообщениями — старт и прокрутка вниз',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3240);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final fake = FakeVibeBackend();
    addTearDown(fake.close);
    fake.messagesByChat['c1'] = [
      for (var i = 0; i < 150; i++)
        VibeMessage(
          id: 'm$i',
          chatId: 'c1',
          senderId: i.isEven ? 'peer' : 'me',
          senderName: i.isEven ? 'Пир' : 'Я',
          senderAvatar: null,
          text: 'сообщение номер $i',
          voicePath: null,
          photoPath: null,
          videoPath: null,
          created: DateTime.now().subtract(Duration(minutes: 150 - i)),
          incoming: i.isEven,
          status: MsgStatus.sent,
        ),
    ];

    final sw = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        theme: VibeTheme.light(),
        home: ChatScreen(chat: chatX('c1', 'Иван'), backend: fake),
      ),
    );
    await tester.pumpAndSettle();
    sw.stop();

    // ignore: avoid_print
    print('PERF чат(150): ${sw.elapsedMilliseconds} мс');
    expect(sw.elapsed, lessThan(const Duration(seconds: 8)),
        reason: 'лента 150 сообщений должна отрисоваться быстро');
    expect(tester.takeException(), isNull);
  });
}