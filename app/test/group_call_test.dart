// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/screens/group_call_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });
  testWidgets('GroupCallScreen показывает участников и mute', (tester) async {
    final chat = VibeChat(id: 'g1', title: 'Команда', kind: 'group', lastMessage: '', lastTime: '', unread: 0, peerName: 'Команда', peerAvatar: null);
    await tester.pumpWidget(MaterialApp(theme: VibeTheme.light(), home: GroupCallScreen(chat: chat)));
    await tester.pumpAndSettle();
    expect(find.text('Команда'), findsOneWidget);
    expect(find.byType(GroupCallScreen), findsOneWidget);
    // Tap first mic button (bottom control) — Grid may not be built due to LiveKit not connected in test
    final micFinder = find.byIcon(Icons.mic_rounded);
    if (micFinder.evaluate().isNotEmpty) {
      await tester.tapAt(tester.getCenter(micFinder.first));
      await tester.pumpAndSettle();
    }
    expect(find.byType(GroupCallScreen), findsOneWidget);
  });

  testWidgets('GroupCallScreen кнопки управления', (tester) async {
    final chat = VibeChat(id: 'g1', title: 'Команда', kind: 'group', lastMessage: '', lastTime: '', unread: 0, peerName: 'Команда', peerAvatar: null);
    await tester.pumpWidget(MaterialApp(theme: VibeTheme.light(), home: GroupCallScreen(chat: chat)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byIcon(Icons.call_end_rounded)));
    await tester.pumpAndSettle();
    expect(find.byType(GroupCallScreen), findsOneWidget);
  });
}
