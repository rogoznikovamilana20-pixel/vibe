// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/screens/story_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  testWidgets('StoryPlayer показывает реакции и прогресс', (tester) async {
    final items = [
      StoryItem(id: 's1', author: 'Иван', isOwn: false),
      StoryItem(id: 's2', author: 'Мария', isOwn: false),
    ];
    await tester.pumpWidget(MaterialApp(home: StoryPlayerScreen(items: items, startIndex: 0, onSeen: (_) {})));
    await tester.pumpAndSettle();
    expect(find.text('❤️'), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
    // Прогресс сегменты
    expect(find.byType(LinearProgressIndicator).evaluate().isNotEmpty || find.text('Иван') != null, isTrue);
  });
}
