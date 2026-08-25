// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibe_app/chat/widgets/chat_app_bar.dart';
import 'package:vibe_app/core/localization/vibe_localizations.dart';
import 'package:vibe_app/core/widgets/vibe_icon_button.dart';
import 'package:vibe_app/core/services/back_history_service.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    BackHistoryService.instance.clear();
  });

  test('BackHistoryService pushChat и pushTab', () {
    final s = BackHistoryService.instance;
    s.pushChat(chatId: 'c1', title: 'Иван');
    s.pushChat(chatId: 'c2', title: 'Мария');
    s.pushTab(2, 'Настройки');
    expect(s.entries.length, 3);
    expect(s.entries.first.key, 'tab:2');
    // Дубликат chat c1 должен подняться наверх
    s.pushChat(chatId: 'c1', title: 'Иван');
    expect(s.entries.first.key, 'chat:c1');
    expect(s.entries.length, 3);
  });

  test('BackHistoryService maxSize 10', () {
    final s = BackHistoryService.instance;
    for (var i = 0; i < 15; i++) {
      s.pushChat(chatId: 'c$i', title: 'Chat $i');
    }
    expect(s.entries.length, 10);
    expect(s.entries.first.key, 'chat:c14');
  });

  testWidgets('ChatAppBar long-press back вызывает onBackLongPress', (tester) async {
    var longPressed = false;
    final chat = VibeChat(id: 'c1', title: 'Иван', kind: 'pm', lastMessage: '', lastTime: '', unread: 0, peerName: 'Иван', peerAvatar: null);
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
        home: Scaffold(
          body: ChatAppBar(
            chat: chat,
            onBack: () {},
            onBackLongPress: () => longPressed = true,
            onOpenProfile: () {},
            onOpenGroupInfo: () {},
            onOpenSearch: () {},
            onChooseCall: () {},
            onShowMenu: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(VibeIconButton).first);
    await tester.pumpAndSettle();
    expect(longPressed, isTrue);
  });
}
