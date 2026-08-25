// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/chat/chat_controller.dart';
import 'package:vibe_app/chat/chat_media_gallery_screen.dart';
import 'package:vibe_app/chat/models.dart';
import 'package:vibe_app/core/localization/vibe_localizations.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/settings_service.dart';

import 'fake_vibe_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVibeBackend fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    fake = FakeVibeBackend();
  });

  tearDown(() => fake.close());

  ChatMsg photoMsg({String serverId = 's1', int seed = 1}) => ChatMsg(
        type: MsgType.photo,
        incoming: false,
        time: '12:30',
        photoSeed: seed,
        serverId: serverId,
      );

  Widget wrapGallery(ChatController controller) => MaterialApp(
        locale: const Locale('ru'),
        theme: VibeTheme.light(),
        localizationsDelegates: const [
          VibeLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru'), Locale('en')],
        home: ChatMediaGalleryScreen(controller: controller, chatTitle: 'Тест'),
      );

  testWidgets('галерея: long-press плитки показывает меню действий', (tester) async {
    final controller = ChatController(chatId: 'c1', chatTitle: 'Тест', onError: (_) {}, backend: fake);
    controller.messages.addAll([photoMsg(serverId: 's1', seed: 1), photoMsg(serverId: 's2', seed: 2)]);
    await tester.pumpWidget(wrapGallery(controller));
    await tester.pumpAndSettle();

    expect(find.text('Медиа · 2'), findsOneWidget);

    // Long-press первой плитки (иконка water_drop внутри _MediaTile)
    await tester.longPress(find.byIcon(Icons.water_drop_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Поделиться'), findsOneWidget);
    expect(find.text('Сохранить в галерею'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);
  });

  testWidgets('галерея: пустое состояние', (tester) async {
    final controller = ChatController(chatId: 'c1', chatTitle: 'Тест', onError: (_) {}, backend: fake);
    await tester.pumpWidget(wrapGallery(controller));
    await tester.pumpAndSettle();
    expect(find.text('Пока нет медиа'), findsOneWidget);
  });

  testWidgets('viewer: long-press показывает то же меню', (tester) async {
    final controller = ChatController(chatId: 'c1', chatTitle: 'Тест', onError: (_) {}, backend: fake);
    controller.messages.add(photoMsg(serverId: 's1', seed: 1));
    final items = chatMediaItems(controller.messages);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      theme: VibeTheme.light(),
      localizationsDelegates: const [
        VibeLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')],
      home: MediaViewerScreen(items: items, initialIndex: 0, controller: controller),
    ));
    await tester.pumpAndSettle();

    // Long-press на viewer
    await tester.longPress(find.byType(MediaViewerScreen));
    await tester.pumpAndSettle();
    expect(find.text('Поделиться'), findsOneWidget);
  });
}
