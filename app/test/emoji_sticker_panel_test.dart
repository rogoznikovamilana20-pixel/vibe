// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/chat/models.dart';
import 'package:vibe_app/core/localization/vibe_localizations.dart';
import 'package:vibe_app/core/services/scheduled_service.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/core/widgets/vibe_avatar.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/screens/chat_screen.dart';
import 'package:vibe_app/screens/emoji_sticker_panel.dart';

import 'fake_vibe_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVibeBackend fake;

  setUp(() async {
    // Гифка копируется во временный файл синхронно (в FakeAsync реальный
    // асинхронный файловый I/O не завершается).
    ChatScreen.writeGifTemp = (name) async {
      final b = await rootBundle.load('assets/gifs/$name');
      final tmp = File('${Directory.systemTemp.path}/vibe_gifs/$name');
      tmp.parent.createSync(recursive: true);
      tmp.writeAsBytesSync(b.buffer.asUint8List());
      return tmp;
    };
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
        locale: const Locale('ru'),
        localizationsDelegates: const [
          VibeLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru')],
        theme: VibeTheme.light(),
        home: ChatScreen(chat: chatFor(), backend: fake),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
    await tester.pumpAndSettle();
  }

  testWidgets('8.3.4 панель: три таба — Эмодзи, Стикеры, Гифки',
      (tester) async {
    await pumpChat(tester);
    expect(find.text('Гифки'), findsNothing);
    await openPanel(tester);

    expect(find.text('Эмодзи'), findsOneWidget);
    expect(find.text('Стикеры'), findsOneWidget);
    expect(find.text('Гифки'), findsOneWidget);
  });

  testWidgets('8.3.4 эмодзи: тап по эмодзи дописывает в поле',
      (tester) async {
    await pumpChat(tester);
    await openPanel(tester);

    final picker = find.byType(EmojiPicker);
    expect(picker, findsOneWidget);
    final emojiTexts = find.descendant(
      of: picker,
      matching: find.byType(Text),
    );
    final emoji = tester
        .widgetList<Text>(emojiTexts)
        .map((t) => t.data ?? '')
        .firstWhere((d) => d.isNotEmpty && d.length == 2);
    expect(emoji.isNotEmpty, isTrue);

    await tester.tap(find.text(emoji).first);
    await tester.pump(const Duration(milliseconds: 300));

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, contains(emoji));
  });

  testWidgets('8.3.4 стикеры: тап по стикеру шлёт сразу', (tester) async {
    await pumpChat(tester);
    await openPanel(tester);
    await tester.tap(find.text('Стикеры'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('👍'));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(fake.calls, contains('sendSticker(c1)'));
    expect(fake.lastStickerSent, '👍');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('8.3.4 гифки: превью на месте, тап шлёт анимированным медиа',
      (tester) async {
    await pumpChat(tester);
    await openPanel(tester);
    await tester.tap(find.text('Гифки'));
    await tester.pumpAndSettle();

    // Грид ленивый: первые 9 превью видимы на экране (10-е — под скроллом).
    // Ищем именно превью гифок: в дереве живут и картинки вкладки эмодзи.
    final gifImgs = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.startsWith('assets/gifs/'),
    );
    expect(gifImgs, findsAtLeastNWidgets(9));

    // Реальный файловый I/O (rootBundle → temp-файл) в FakeAsync завершается
    // только между pump'ами — прогоняем несколько итераций.
    await tester.tap(gifImgs.first);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Гифка — анимированный медиа-пузырь с бейджем GIF, не карточка-файл.
    expect(
      find.textContaining('Не удалось отправить гифку'),
      findsNothing,
      reason: 'snack не должен появляться',
    );
    expect(fake.calls, contains('sendGif(c1)'));
    expect(find.text('GIF'), findsOneWidget);
    expect(find.text('gif1.gif'), findsNothing);
    expect(find.text('28.0 КБ'), findsNothing);
    // После подтверждения сервера — сетевой рендер анимации.
    expect(find.byType(VibeNetImage), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  test('kGifAssets: все файлы объявлены в ассетах', () {
    expect(kGifAssets, hasLength(10));
    for (final a in kGifAssets) {
      expect(a, startsWith('assets/gifs/'));
      expect(a.endsWith('.gif'), isTrue);
    }
  });

  testWidgets('8.3.4 гифка с URL: медиа-пузырь с бейджем GIF',
      (tester) async {
    await pumpChat(tester);
    fake.streamCtrl.add(
      VibeMessage(
        id: 'gif-in',
        chatId: 'c1',
        senderId: 'peer',
        senderName: 'Иван',
        senderAvatar: null,
        voicePath: null,
        photoPath: null,
        videoPath: null,
        stickerEmoji: null,
        text: AttachmentData.encode(
          kind: AttachmentKind.gif,
          name: 'gif9.gif',
          size: 28701,
          mime: 'image/gif',
          url: 'media/c1/gif9.gif',
        ),
        created: DateTime(2026, 8, 13, 12),
        incoming: true,
        status: MsgStatus.sent,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('GIF'), findsOneWidget);
    expect(find.text('gif9.gif'), findsNothing);
    expect(find.byType(VibeNetImage), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}