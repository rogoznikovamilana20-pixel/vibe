import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/screens/my_links_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
  });

  tearDown(() {
    VibeBackend.myProfileNotifier.value = null;
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    VibeProfile? profile,
    String userName = 'ivan',
  }) async {
    VibeBackend.myProfileNotifier.value = profile;
    tester.view.physicalSize = const Size(1080, 3240);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: VibeTheme.light(),
        home: MyLinksScreen(userName: userName),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('список: vibe.me-ссылка, @ник, телефон и кнопка QR',
      (tester) async {
    await pumpScreen(
      tester,
      profile: VibeProfile(
        id: 'p1',
        username: 'ivan_petrov',
        displayName: 'Иван Петров',
        phone: '+79990001122',
      ),
    );

    expect(find.text('Мои ссылки'), findsOneWidget);
    expect(find.text('Ссылка на профиль'), findsOneWidget);
    expect(find.text('vibe.me/@ivan_petrov'), findsOneWidget);
    expect(find.text('Имя пользователя'), findsOneWidget);
    expect(find.text('@ivan_petrov'), findsOneWidget);
    expect(find.text('Телефон'), findsOneWidget);
    expect(find.text('+79990001122'), findsOneWidget);
    expect(find.text('QR-код профиля'), findsOneWidget);
  });

  testWidgets('тап по ссылке копирует значение (snack)', (tester) async {
    await pumpScreen(
      tester,
      profile: VibeProfile(
        id: 'p1',
        username: 'ivan_petrov',
        displayName: 'Иван Петров',
        phone: '+79990001122',
      ),
    );

    tester.widget<ListTile>(find.byType(ListTile).first).onTap!();
    await tester.pumpAndSettle();

    expect(find.text('Скопировано: vibe.me/@ivan_petrov'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('QR: шит с кодом и кнопкой копирования', (tester) async {
    await pumpScreen(
      tester,
      profile: VibeProfile(
        id: 'p1',
        username: 'ivan_petrov',
        displayName: 'Иван Петров',
      ),
    );

    await tester.tap(find.text('QR-код профиля'));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Копировать ссылку'), findsOneWidget);
  });
}