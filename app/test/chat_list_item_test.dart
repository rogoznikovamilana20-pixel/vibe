import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/chats/widgets/chat_list_item.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';

import 'test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  VibeChat chat({
    String id = 'c1',
    String title = 'Пир',
    String kind = 'pm',
    String lastMessage = 'Привет',
    String lastTime = '12:30',
    int unread = 0,
  }) {
    return VibeChat(
      id: id,
      title: title,
      kind: kind,
      lastMessage: lastMessage,
      lastTime: lastTime,
      unread: unread,
      peerName: title,
      peerAvatar: null,
    );
  }

  Widget wrap(Widget child) {
    return wrapWithApp(
      SizedBox(width: 400, child: child),
    );
  }

  testWidgets('ChatListItem: имя, превью, время и бейдж непрочитанных',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        ChatListItem(
          chat: chat(lastMessage: 'Как дела?', unread: 3),
          selected: false,
          isArchived: false,
          isDnd: false,
          pinned: false,
          unread: 3,
          selectionMode: false,
          density: 1,
          onTap: () {},
          onLongPress: () {},
          onDismissed: (_) {},
        ),
      ),
    );

    expect(find.text('Пир'), findsOneWidget);
    expect(find.text('Как дела?'), findsOneWidget);
    expect(find.text('12:30'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('ChatListItem: черновик вместо превью акцентным цветом',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        ChatListItem(
          chat: chat(lastMessage: 'Как дела?'),
          selected: false,
          isArchived: false,
          isDnd: false,
          pinned: false,
          unread: 0,
          selectionMode: false,
          density: 1,
          onTap: () {},
          onLongPress: () {},
          onDismissed: (_) {},
          draft: 'Недописанное сообщение',
        ),
      ),
    );

    expect(find.text('Как дела?'), findsNothing);
    expect(
      find.textContaining('Недописанное сообщение'),
      findsOneWidget,
    );
    expect(find.textContaining('Черновик: '), findsOneWidget);
  });

  testWidgets('ChatListItem: pin-иконка и DND', (tester) async {
    await tester.pumpWidget(
      wrap(
        ChatListItem(
          chat: chat(),
          selected: false,
          isArchived: false,
          isDnd: true,
          pinned: true,
          unread: 2,
          selectionMode: false,
          density: 1,
          onTap: () {},
          onLongPress: () {},
          onDismissed: (_) {},
        ),
      ),
    );

    expect(find.byIcon(VibeIcons.pin), findsWidgets);
    expect(find.byIcon(Icons.notifications_off_rounded), findsWidgets);
  });

  testWidgets('ChatListItem: мультивыбор рисует галочку и отключает свайп',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        ChatListItem(
          chat: chat(),
          selected: true,
          isArchived: false,
          isDnd: false,
          pinned: false,
          unread: 0,
          selectionMode: true,
          density: 1,
          onTap: () {},
          onLongPress: () {},
          onDismissed: (_) {},
        ),
      ),
    );

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    final dismissible = tester.widget<Dismissible>(
      find.byType(Dismissible),
    );
    expect(dismissible.direction, DismissDirection.none);
  });

  testWidgets('ChatListItem: архивный чат показывает «В архиве»',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        ChatListItem(
          chat: chat(lastMessage: 'Секрет'),
          selected: false,
          isArchived: true,
          isDnd: false,
          pinned: false,
          unread: 0,
          selectionMode: false,
          density: 1,
          onTap: () {},
          onLongPress: () {},
          onDismissed: (_) {},
        ),
      ),
    );

    expect(find.text('В архиве'), findsOneWidget);
    expect(find.text('Секрет'), findsNothing);
  });

  testWidgets('ChatListItem: тап и длинный тап вызывают callbacks',
      (tester) async {
    var taps = 0;
    var longTaps = 0;
    await tester.pumpWidget(
      wrap(
        ChatListItem(
          chat: chat(),
          selected: false,
          isArchived: false,
          isDnd: false,
          pinned: false,
          unread: 0,
          selectionMode: false,
          density: 1,
          onTap: () => taps++,
          onLongPress: () => longTaps++,
          onDismissed: (_) {},
        ),
      ),
    );

    await tester.tap(find.byType(ListTile));
    expect(taps, 1);

    await tester.longPress(find.byType(ListTile));
    expect(longTaps, 1);
  });
}
