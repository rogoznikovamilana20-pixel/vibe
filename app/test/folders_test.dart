import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/core/localization/vibe_localizations.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/screens/chat_list_screen.dart';
import 'package:vibe_app/screens/folders_screen.dart';

import 'fake_vibe_backend.dart';

VibeChat chatX(String id, String title) {
  return VibeChat(
    id: id,
    title: title,
    kind: 'pm',
    lastMessage: '',
    lastTime: '12:00',
    unread: 0,
    peerName: title,
    peerAvatar: null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  group('SettingsService: папки (8.3.7)', () {
    test('addFolder → chatFolders, folderOf, renameFolder, removeFolder', () async {
      final s = SettingsService.instance;
      expect(s.chatFolders, isEmpty);

      await s.addFolder('Работа', emoji: '💼');
      await s.addFolder('Учёба', emoji: '📚');
      expect(s.chatFolders.length, 2);
      expect(s.chatFolders.first.title, 'Работа');
      expect(s.chatFolders.first.emoji, '💼');

      final work = s.chatFolders.first.id;
      await s.setFolderForChat('c1', work);
      expect(s.folderOf('c1'), work);
      expect(s.folderOf('c2'), isNull);

      await s.renameFolder(work, 'Офис', emoji: '🏢');
      expect(s.chatFolders.first.title, 'Офис');
      expect(s.chatFolders.first.emoji, '🏢');
      expect(s.folderOf('c1'), work);

      await s.removeFolder(work);
      expect(s.chatFolders.length, 1);
      // Назначение удалённой папки очищено.
      expect(s.folderOf('c1'), isNull);
    });

    test('назначение — один чат в одной папке; перенос меняет папку', () async {
      final s = SettingsService.instance;
      await s.addFolder('A');
      await s.addFolder('B');
      final a = s.chatFolders[0].id;
      final b = s.chatFolders[1].id;

      await s.setFolderForChat('c1', a);
      await s.setFolderForChat('c1', b);
      expect(s.folderOf('c1'), b);
    });

    test('папки переживают перезапуск (переинициализация prefs)', () async {
      final s = SettingsService.instance;
      await s.addFolder('Дом', emoji: '🏠');
      final id = s.chatFolders.single.id;
      await s.setFolderForChat('c9', id);

      // Эмуляция перезапуска: новый инстанс с тем же хранилищем.
      SettingsService.instance.appearanceVersion; // тронуть синглтон
      await SettingsService.instance.init();
      expect(SettingsService.instance.chatFolders.single.title, 'Дом');
      expect(SettingsService.instance.folderOf('c9'), id);
    });
  });

  group('FoldersScreen (8.3.7)', () {
    Future<void> pumpFolders(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3240);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          theme: VibeTheme.light(),
          localizationsDelegates: const [
            VibeLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('en')],
          home: FoldersScreen(
            chats: [chatX('c1', 'Анна'), chatX('c2', 'Борис')],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('пустое состояние с CTA «Создать папку»', (tester) async {
      await pumpFolders(tester);
      expect(find.text('Папок пока нет'), findsOneWidget);
      expect(find.text('Создать папку'), findsOneWidget);
    });

    testWidgets('тайл папки со счётчиком чатов; создание через экран', (tester) async {
      await SettingsService.instance.addFolder('Работа', emoji: '💼');
      final id = SettingsService.instance.chatFolders.single.id;
      await SettingsService.instance.setFolderForChat('c1', id);

      await pumpFolders(tester);
      expect(find.text('Работа'), findsOneWidget);
      expect(find.text('1 чат'), findsOneWidget);

      // Редактор открывается с чатом в папке.
      await tester.tap(find.text('Работа'));
      await tester.pumpAndSettle();
      expect(find.text('Чаты в папке — 1'), findsOneWidget);
      expect(find.text('Анна'), findsOneWidget);

      // Снимаем чат → «Сохранить» → счётчик сброшен.
      await tester.tap(find.text('Анна'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(SettingsService.instance.folderOf('c1'), isNull);
      expect(find.text('1 чат'), findsNothing);
    });

    testWidgets('удаление папки из редактора', (tester) async {
      await SettingsService.instance.addFolder('Старая');
      final id = SettingsService.instance.chatFolders.single.id;
      await SettingsService.instance.setFolderForChat('c1', id);

      await pumpFolders(tester);
      await tester.tap(find.text('Старая'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Удалить папку'));
      await tester.pumpAndSettle();

      expect(SettingsService.instance.chatFolders, isEmpty);
      expect(SettingsService.instance.folderOf('c1'), isNull);
    });
  });

  group('Лента: папки (8.3.7)', () {
    late FakeVibeBackend fake;

    setUp(() async {
      fake = FakeVibeBackend();
    });

    tearDown(() {
      fake.close();
    });

    Future<void> pumpList(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3240);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          theme: VibeTheme.light(),
          localizationsDelegates: const [
            VibeLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('en')],
          home: ChatListScreen(userName: 'Тест', backend: fake),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('чип папки фильтрует ленту; возврат во «Все»',
        (tester) async {
      fake.chatList = [chatX('c1', 'Анна'), chatX('c2', 'Борис')];
      await SettingsService.instance.addFolder('Работа', emoji: '💼');
      final folderId = SettingsService.instance.chatFolders.single.id;
      await SettingsService.instance.setFolderForChat('c1', folderId);

      await pumpList(tester);

      // Широкий экран: все чипы табов помещаются без скролла.
      tester.view.physicalSize = const Size(2160, 3240);
      tester.view.devicePixelRatio = 3.0;
      await tester.pumpAndSettle();
      // В «Все» видны оба чата + чип папки в табах.
      expect(find.text('Анна'), findsOneWidget);
      expect(find.text('Борис'), findsOneWidget);
      expect(find.text('💼 Работа'), findsOneWidget);

      // Выбор папки: только назначенный чат.
      await tester.tap(find.text('💼 Работа'));
      await tester.pumpAndSettle();
      expect(find.text('Анна'), findsOneWidget);
      expect(find.text('Борис'), findsNothing);

      // Обратно во «Все».
      await tester.tap(find.text('Все'));
      await tester.pumpAndSettle();
      expect(find.text('Борис'), findsOneWidget);
    });
  });
}