// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter/gestures.dart';
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

  Widget wrap(
    ChatMsg msg, {
    VoidCallback? onReplyTap,
    VoidCallback? onPhotoTap,
  }) {
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
            onHeart: () => null,
            onLongPress: () {},
            onReply: () {},
            onReplyTap: onReplyTap,
            onPhotoTap: onPhotoTap,
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

  testWidgets('MessageBubble: квитанции delivered/read/failed', (tester) async {
    await tester.pumpWidget(wrap(textMsg(status: MsgStatus.delivered)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final deliveredTick = tester.widget<MessageStatusTick>(
      find.byType(MessageStatusTick),
    );
    expect(deliveredTick.status, MsgStatus.delivered);

    await tester.pumpWidget(wrap(textMsg(status: MsgStatus.read)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final readTick = tester.widget<MessageStatusTick>(
      find.byType(MessageStatusTick),
    );
    expect(readTick.status, MsgStatus.read);

    await tester.pumpWidget(wrap(textMsg(status: MsgStatus.failed)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('MessageBubble: у входящего нет галочек статуса', (tester) async {
    await tester.pumpWidget(
      wrap(textMsg(incoming: true, status: MsgStatus.read)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(VibeIcons.checkAll), findsNothing);
    expect(find.byIcon(VibeIcons.check), findsNothing);
  });

  testWidgets('MessageBubble: превью ответа (replyText)', (tester) async {
    await tester.pumpWidget(wrap(textMsg(replyText: 'На что я отвечаю')));
    await tester.pumpAndSettle();

    expect(findAnyTextContaining('На что я отвечаю'), findsOneWidget);
  });

  testWidgets('MessageBubble: тап по цитате ответа вызывает onReplyTap (G4)', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        textMsg(replyText: 'На что я отвечаю'),
        onReplyTap: () => tapped = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(findAnyTextContaining('На что я отвечаю'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tapped, isTrue);
  });

  testWidgets('MessageBubble: без onReplyTap тап по цитате не падает', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(textMsg(replyText: 'На что я отвечаю')));
    await tester.pumpAndSettle();

    await tester.tap(findAnyTextContaining('На что я отвечаю'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  ChatMsg photoMsg() => ChatMsg(
    type: MsgType.photo,
    incoming: false,
    time: '12:30',
    text: '',
    status: MsgStatus.sent,
    photoSeed: 3,
  );

  testWidgets('MessageBubble: тап по фото вызывает onPhotoTap (G9)', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(wrap(photoMsg(), onPhotoTap: () => tapped = true));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.image_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tapped, isTrue);
  });

  testWidgets(
    'MessageBubble: в режиме выбора тап по фото не зовёт onPhotoTap',
    (tester) async {
      var tapped = false;
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
                msg: photoMsg(),
                onHeart: () => null,
                onLongPress: () {},
                onReply: () {},
                onPhotoTap: () => tapped = true,
                onOpenUrl: (_) {},
                scrollController: ScrollController(),
                selectionMode: true,
                isSelected: false,
                onToggleSelect: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.image_rounded));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tapped, isFalse);
    },
  );

  testWidgets('MessageBubble: длинный ответ (>50 симв.) не ломает верстку', (
    tester,
  ) async {
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
    await tester.pumpWidget(wrap(textMsg(forwardedFrom: 'Иван')));
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
              onHeart: () {
                hearts++;
                return '❤️';
              },
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

  testWidgets('MessageBubble: burst-эмодзи при двойном тапе', (tester) async {
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
              onHeart: () => '❤️',
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
    await tester.pump(const Duration(milliseconds: 200));

    // Большой burst-эмодзи появился над пузырём (44px, не чип).
    final bigEmoji = find.text('❤️');
    expect(bigEmoji, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 950));
    expect(bigEmoji, findsNothing);
  });

  test('buildLinkSpans: URL, @mention и #hashtag кликабельны', () {
    var tapped = '';
    final spans = buildLinkSpans(
      'Привет @ivan смотри https://example.com и #vibe',
      Colors.blue,
      (s) => tapped = s,
    );
    // Должно быть 5 кусков: "Привет ", "@ivan", " смотри ", "https://...", " и ", "#vibe"
    // Но минимум — 3 кликабельных span с recognizer.
    final linkSpans = spans.where((s) => s is TextSpan && s.recognizer != null).toList();
    expect(linkSpans.length, 3);

    // Тап по первому линку (@ivan)
    ((linkSpans[0] as TextSpan).recognizer as TapGestureRecognizer).onTap?.call();
    expect(tapped, '@ivan');

    // Тап по URL
    ((linkSpans[1] as TextSpan).recognizer as TapGestureRecognizer).onTap?.call();
    expect(tapped, 'https://example.com');

    // Тап по хэштегу
    ((linkSpans[2] as TextSpan).recognizer as TapGestureRecognizer).onTap?.call();
    expect(tapped, '#vibe');
  });

  test('buildLinkSpans: кириллический #хэштег', () {
    final spans = buildLinkSpans('Тренд #привет', Colors.blue, (_) {});
    final linkSpans = spans.where((s) => s is TextSpan && s.recognizer != null).toList();
    expect(linkSpans.length, 1);
    expect((linkSpans[0] as TextSpan).text, '#привет');
  });

  testWidgets('MessageBubble: @mention в пузыре рендерится без краша', (tester) async {
    await tester.pumpWidget(
      wrap(textMsg(text: 'Привет @ivan смотри #vibe https://ex.com')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(findSelectableTextContaining('@ivan'), findsOneWidget);
    expect(findSelectableTextContaining('#vibe'), findsOneWidget);
  });
}
