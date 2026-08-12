import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/chat/models.dart';
import 'package:vibe_app/chat/widgets/message_bubble.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  ChatMsg textMsg({
    String text = 'Привет',
    bool incoming = false,
    MsgStatus status = MsgStatus.sent,
    bool edited = false,
    String? replyText,
    String? forwardedFrom,
  }) {
    return ChatMsg(
      type: MsgType.text,
      incoming: incoming,
      time: '12:30',
      text: text,
      status: status,
      edited: edited,
      replyText: replyText,
      replyAuthor: replyText != null ? 'Пир' : null,
      forwardedFrom: forwardedFrom,
    );
  }

  Widget wrap(ChatMsg msg) {
    return MaterialApp(
      theme: VibeTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          controller: ScrollController(),
          child: MessageBubble(
            msg: msg,
            onHeart: () {},
            onLongPress: () {},
            onReply: () {},
            onOpenUrl: (_) {},
            scrollController: ScrollController(),
          ),
        ),
      ),
    );
  }

  testWidgets('MessageBubble: текст, время и галочка sent', (tester) async {
    await tester.pumpWidget(wrap(textMsg()));

    expect(find.text('Привет'), findsOneWidget);
    expect(find.text('12:30'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('MessageBubble: квитанции delivered/read/failed',
      (tester) async {
    await tester.pumpWidget(wrap(textMsg(status: MsgStatus.delivered)));
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);

    await tester.pumpWidget(wrap(textMsg(status: MsgStatus.read)));
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    expect(
      tester
          .widget<Icon>(find.byIcon(Icons.done_all_rounded))
          .color
          ?.toARGB32(),
      const Color(0xFF8AB4F8).toARGB32(),
    );

    await tester.pumpWidget(wrap(textMsg(status: MsgStatus.failed)));
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('MessageBubble: у входящего нет галочек статуса',
      (tester) async {
    await tester.pumpWidget(wrap(textMsg(incoming: true, status: MsgStatus.read)));

    expect(find.byIcon(Icons.done_all_rounded), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('MessageBubble: превью ответа (replyText)', (tester) async {
    await tester.pumpWidget(
      wrap(textMsg(replyText: 'На что я отвечаю')),
    );

    expect(find.textContaining('На что я отвечаю'), findsOneWidget);
  });

  testWidgets('MessageBubble: метка «изменено»', (tester) async {
    await tester.pumpWidget(wrap(textMsg(edited: true)));

    expect(find.text('изменено'), findsOneWidget);
  });

  testWidgets('MessageBubble: «Переслано от …»', (tester) async {
    await tester.pumpWidget(
      wrap(textMsg(forwardedFrom: 'Иван')),
    );

    expect(find.text('Переслано от Иван'), findsOneWidget);
  });

  testWidgets('MessageBubble: двойной тап зовёт onHeart', (tester) async {
    var hearts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: VibeTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            controller: ScrollController(),
            child: MessageBubble(
              msg: textMsg(),
              onHeart: () => hearts++,
              onLongPress: () {},
              onReply: () {},
              onOpenUrl: (_) {},
              scrollController: ScrollController(),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Привет'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Привет'));
    await tester.pump(const Duration(milliseconds: 950));

    expect(hearts, 1);
  });
}
