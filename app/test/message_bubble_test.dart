import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/chat/models.dart';
import 'package:vibe_app/chat/widgets/message_bubble.dart';
import 'package:vibe_app/chat/widgets/message_status_tick.dart';
import 'package:vibe_app/core/localization/vibe_localizations.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

Finder findSelectableTextContaining(String text) {
  return find.byWidgetPredicate((w) {
    if (w is EditableText && w.controller.text.contains(text)) return true;
    if (w is Text && w.data != null && w.data!.contains(text)) return true;
    return false;
  });
}

Finder findAnyTextContaining(String text) {
  return find.byWidgetPredicate((w) {
    if (w is EditableText && w.controller.text.contains(text)) return true;
    if (w is Text && w.data != null && w.data!.contains(text)) return true;
    return false;
  });
}

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
      localizationsDelegates: const [
        VibeLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru')],
      locale: const Locale('ru'),
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
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(findSelectableTextContaining('Привет'), findsOneWidget);
    expect(findAnyTextContaining('12:30'), findsOneWidget);
    expect(find.byType(MessageStatusTick), findsOneWidget);
  });

  testWidgets('MessageBubble: квитанции delivered/read/failed',
      (tester) async {
    await tester.pumpWidget(wrap(textMsg(status: MsgStatus.delivered)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final deliveredTick =
        tester.widget<MessageStatusTick>(find.byType(MessageStatusTick));
    expect(deliveredTick.status, MsgStatus.delivered);

    await tester.pumpWidget(wrap(textMsg(status: MsgStatus.read)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final readTick =
        tester.widget<MessageStatusTick>(find.byType(MessageStatusTick));
    expect(readTick.status, MsgStatus.read);

    await tester.pumpWidget(wrap(textMsg(status: MsgStatus.failed)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('MessageBubble: у входящего нет галочек статуса',
      (tester) async {
    await tester.pumpWidget(wrap(textMsg(incoming: true, status: MsgStatus.read)));
    await tester.pumpAndSettle();

    expect(find.byIcon(VibeIcons.checkAll), findsNothing);
    expect(find.byIcon(VibeIcons.check), findsNothing);
  });

  testWidgets('MessageBubble: превью ответа (replyText)', (tester) async {
    await tester.pumpWidget(
      wrap(textMsg(replyText: 'На что я отвечаю')),
    );
    await tester.pumpAndSettle();

    expect(findAnyTextContaining('На что я отвечаю'), findsOneWidget);
  });

  testWidgets('MessageBubble: длинный ответ (>50 симв.) не ломает верстку',
      (tester) async {
    final long = List.filled(12, 'очень длинный ответ-цитата').join(' ');
    expect(long.length, greaterThan(50));

    await tester.pumpWidget(wrap(textMsg(replyText: long)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(findAnyTextContaining('очень длинный ответ-цитата'), findsOneWidget);
  });

  testWidgets('MessageBubble: метка «изменено»', (tester) async {
    await tester.pumpWidget(wrap(textMsg(edited: true)));
    await tester.pumpAndSettle();

    expect(findAnyTextContaining('изменено'), findsOneWidget);
  });

  testWidgets('MessageBubble: «Переслано от …»', (tester) async {
    await tester.pumpWidget(
      wrap(textMsg(forwardedFrom: 'Иван')),
    );
    await tester.pumpAndSettle();

    expect(findAnyTextContaining('Переслано от Иван'), findsOneWidget);
  });

  testWidgets('MessageBubble: двойной тап зовёт onHeart', (tester) async {
    var hearts = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          VibeLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru')],
        locale: const Locale('ru'),
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
    await tester.pumpAndSettle();

    final bubbleFinder = findSelectableTextContaining('Привет');
    await tester.tap(bubbleFinder);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(bubbleFinder);
    await tester.pump(const Duration(milliseconds: 950));

    expect(hearts, 1);
  });
}
