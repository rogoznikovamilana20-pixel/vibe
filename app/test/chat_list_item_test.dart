// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/chats/widgets/chat_list_item.dart';
import 'package:vibe_app/chats/widgets/full_swipe.dart';
import 'package:vibe_app/core/theme/vibe_colors.dart';
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

  Widget item({
    required VibeChat c,
    bool selected = false,
    bool isArchived = false,
    bool isDnd = false,
    bool pinned = false,
    int unread = 0,
    bool selectionMode = false,
    ChatSwipeAction swipeAction = ChatSwipeAction.archive,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    VoidCallback? onSwipeLeft,
    VoidCallback? onSwipeRight,
    String? draft,
  }) {
    return ChatListItem(
      chat: c,
      selected: selected,
      isArchived: isArchived,
      isDnd: isDnd,
      pinned: pinned,
      unread: unread,
      selectionMode: selectionMode,
      density: 1,
      swipeAction: swipeAction,
      onTap: onTap ?? () {},
      onLongPress: onLongPress ?? () {},
      onSwipeLeft: onSwipeLeft ?? () {},
      onSwipeRight: onSwipeRight ?? () {},
      draft: draft,
    );
  }

  testWidgets('ChatListItem: имя, превью, время и бейдж непрочитанных',
      (tester) async {
    await tester.pumpWidget(
      wrap(item(c: chat(lastMessage: 'Как дела?', unread: 3), unread: 3)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Пир'), findsOneWidget);
    expect(find.text('Как дела?'), findsOneWidget);
    expect(find.text('12:30'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('ChatListItem: черновик вместо превью акцентным цветом',
      (tester) async {
    await tester.pumpWidget(
      wrap(item(c: chat(lastMessage: 'Как дела?'), draft: 'Недописанное')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Как дела?'), findsNothing);
    expect(find.textContaining('Недописанное'), findsOneWidget);
    expect(find.textContaining('Черновик: '), findsOneWidget);
  });

  testWidgets('ChatListItem: pin-иконка и DND', (tester) async {
    await tester.pumpWidget(
      wrap(item(c: chat(), isDnd: true, pinned: true, unread: 2)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(VibeIcons.pin), findsWidgets);
    expect(find.byIcon(Icons.notifications_off_rounded), findsWidgets);
  });

  testWidgets('ChatListItem: мультивыбор рисует галочку и отключает свайп',
      (tester) async {
    await tester.pumpWidget(
      wrap(item(c: chat(), selected: true, selectionMode: true)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    final swipe = tester.widget<FullSwipe>(find.byType(FullSwipe));
    expect(swipe.enabled, isFalse);
  });

  testWidgets('ChatListItem: архивный чат показывает «В архиве»',
      (tester) async {
    await tester.pumpWidget(
      wrap(item(c: chat(lastMessage: 'Секрет'), isArchived: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('В архиве'), findsOneWidget);
    expect(find.text('Секрет'), findsNothing);
  });

  testWidgets('ChatListItem: тап и длинный тап вызывают callbacks',
      (tester) async {
    var taps = 0;
    var longTaps = 0;
    await tester.pumpWidget(
      wrap(
        item(
          c: chat(),
          onTap: () => taps++,
          onLongPress: () => longTaps++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile));
    expect(taps, 1);

    await tester.longPress(find.byType(ListTile));
    expect(longTaps, 1);
  });

  testWidgets('ChatListItem: полный свайп влево зовёт onSwipeLeft',
      (tester) async {
    var left = 0;
    await tester.pumpWidget(
      wrap(
        item(
          c: chat(unread: 3),
          unread: 3,
          onSwipeLeft: () => left++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Фон действия (архив по умолчанию) скрыт под плиткой.
    expect(
      find.text('В архив').hitTestable(),
      findsNothing,
    );

    await tester.drag(find.byType(ListTile), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(left, 1);
  });

  testWidgets('ChatListItem: свайп вправо зовёт onSwipeRight', (tester) async {
    var right = 0;
    await tester.pumpWidget(
      wrap(
        item(
          c: chat(),
          onSwipeRight: () => right++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListTile), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(right, 1);
  });

  testWidgets('ChatListItem: короткий свайп отменяется (действие не зовётся)',
      (tester) async {
    var left = 0;
    var right = 0;
    await tester.pumpWidget(
      wrap(
        item(
          c: chat(),
          onSwipeLeft: () => left++,
          onSwipeRight: () => right++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListTile), const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(left, 0);
    expect(right, 0);
  });

  testWidgets('ChatListItem: delete-свайп рисует красный фон', (tester) async {
    await tester.pumpWidget(
      wrap(item(c: chat(), swipeAction: ChatSwipeAction.delete)),
    );
    await tester.pumpAndSettle();

    final red = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((b) => b.color == VibeColors.error);
    expect(red, isNotEmpty);
  });
}