// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/core/localization/vibe_localizations.dart';
import 'package:vibe_app/core/profile_avatar.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/screens/profile_setup_screen.dart';

/// 2.11 (MASTER_PLAN): кликабельная аватарка в profile_setup.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  Future<void> pumpSetup(WidgetTester tester) async {
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
        home: ProfileSetupScreen(phoneNumber: '+79990001122'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('тап по аватарке открывает шит смены (галерея/камера/удалить)',
      (tester) async {
    await pumpSetup(tester);

    await tester.tap(find.text('🙂'));
    await tester.pumpAndSettle();

    expect(find.text('Выбрать из галереи'), findsOneWidget);
    expect(find.text('Сделать фото'), findsOneWidget);
    expect(find.text('Удалить аватар'), findsOneWidget);

    // Закрываем шит без выбора (клик скролла) — экран жив.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Выбрать из галереи'), findsNothing);
  });

  testWidgets('выбор эмодзи из сетки меняет аватарку', (tester) async {
    await pumpSetup(tester);

    expect(find.text('🙂'), findsOneWidget);
    await tester.tap(find.text('🔥'));
    await tester.pumpAndSettle();

    expect(find.text('🔥'), findsNWidgets(2),
        reason: 'эмодзи в аватарке и в сетке выбора');
  });

  testWidgets('сохранённое фото показывается в аватарке', (tester) async {
    final onePxPng = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
    ProfileAvatar.myPhoto.value = onePxPng;

    await pumpSetup(tester);
    await tester.pump();

    expect(find.byType(Image), findsWidgets);
    expect(find.text('🙂'), findsNothing);

    addTearDown(() => ProfileAvatar.myPhoto.value = null);
  });
}