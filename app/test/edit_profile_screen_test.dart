import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/screens/edit_profile_screen.dart';

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

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3240);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: VibeTheme.light(),
        home: EditProfileScreen(backend: fake),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('занятый ник: live-ошибка после дебаунса, сохранение блокируется',
      (tester) async {
    fake.takenUsernames.add('ivan');
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Иван Петров');
    await tester.enterText(find.byType(TextField).at(1), 'ivan');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(
      find.text('Этот никнейм уже занят'),
      findsOneWidget,
      reason: 'подпись занятости появляется под полем',
    );

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(fake.updateProfileCalls, 0, reason: 'занятый ник не уходит на сервер');
    expect(find.text('Этот никнейм уже занят'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('свободный ник: ошибки нет, сохранение уходит с выбранным ником',
      (tester) async {
    fake.takenUsernames.add('ivan');
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Иван Петров');
    await tester.enterText(find.byType(TextField).at(1), 'ivan_petrov');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Этот никнейм уже занят'), findsNothing);

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(fake.updateProfileCalls, 1);
    expect(fake.lastUsernameUpdated, 'ivan_petrov');

    await tester.pump(const Duration(seconds: 3));
  });
}