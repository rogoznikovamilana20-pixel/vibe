// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/core/localization/vibe_localizations.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/screens/add_contact_screen.dart';

import 'fake_vibe_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVibeBackend fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    fake = FakeVibeBackend();
  });

  Future<void> pump(WidgetTester tester) async {
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
        home: AddContactScreen(backend: fake),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('8.3.1: поиск по имени находит людей и открывает чат',
      (tester) async {
    fake.searchResults = [
      VibeProfile(
        id: 'u1',
        username: 'ivan',
        displayName: 'Иван Петров',
        emoji: null,
        avatar: null,
        bio: '',
        online: true,
      ),
    ];
    fake.pmChatForPeer['u1'] = 'c9';
    fake.chatList = [
      VibeChat(
        id: 'c9',
        title: 'Иван Петров',
        kind: 'pm',
        lastMessage: '',
        lastTime: '',
        unread: 0,
        peerName: 'Иван Петров',
        peerAvatar: null,
      ),
    ];
    await pump(tester);

    expect(find.text('Новый контакт'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'Иван');
    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('searchUsers(Иван)'));
    expect(find.text('Иван Петров'), findsOneWidget);

    await tester.tap(find.text('Иван Петров'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('ensurePmChat(u1)'));
  });

  testWidgets('8.3.1: пустой результат — кнопка приглашения друга',
      (tester) async {
    fake.searchResults = const [];
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'noone');
    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();

    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(find.text('Пригласить друга'), findsOneWidget);

    await tester.tap(find.text('Пригласить друга'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Приглашение скопировано — отправьте его другу'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });
}