import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/core/localization/vibe_localizations.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/screens/settings_screen.dart';

/// 2.8 (MASTER_PLAN): ключи локализации в шапках секций настроек.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  Future<void> pumpSettings(WidgetTester tester, String languageCode) async {
    SettingsService.instance.setLanguageCode(languageCode);
    await tester.pumpWidget(
      MaterialApp(
        theme: VibeTheme.light(),
        locale: Locale(languageCode),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          VibeLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ru: шапка секции не дублирует заголовок экрана',
      (tester) async {
    await pumpSettings(tester, 'ru');

    expect(find.text('Настройки'), findsOneWidget,
        reason: 'заголовок экрана — единственный «Настройки»');
    expect(find.text('ОСНОВНЫЕ НАСТРОЙКИ'), findsOneWidget);
    expect(find.text('ПОДДЕРЖКА'), findsOneWidget);
  });

  testWidgets('en: секции переведены', (tester) async {
    await pumpSettings(tester, 'en');

    expect(find.text('Settings'), findsOneWidget,
        reason: 'заголовок экрана — единственный «Settings»');
    expect(find.text('GENERAL SETTINGS'), findsOneWidget);
    expect(find.text('SUPPORT'), findsOneWidget);
  });
}