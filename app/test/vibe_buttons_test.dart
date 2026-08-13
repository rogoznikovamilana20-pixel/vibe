import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/core/widgets/vibe_button.dart';
import 'package:vibe_app/core/widgets/vibe_icon_button.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  Widget wrap(Widget child) => MaterialApp(
        theme: VibeTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('8.2.1: пресеты высоты VibeButton 56/44/36', (tester) async {
    await tester.pumpWidget(
      wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VibeButton(label: 'L', onPressed: () {}, size: VibeButtonSize.l),
            VibeButton(label: 'M', onPressed: () {}),
            VibeButton(label: 'S', onPressed: () {}, size: VibeButtonSize.s),
          ],
        ),
      ),
    );
    final l = tester.getSize(find.widgetWithText(VibeButton, 'L'));
    final m = tester.getSize(find.widgetWithText(VibeButton, 'M'));
    final s = tester.getSize(find.widgetWithText(VibeButton, 'S'));
    expect(l.height, 56);
    expect(m.height, 44);
    expect(s.height, 36);
  });

  testWidgets('8.2.2: VibeIconButton — hit-target 48, сжатие 86% при нажатии',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(VibeIconButton(icon: VibeIcons.search, onPressed: () => taps++)),
    );
    final size = tester.getSize(find.byType(VibeIconButton));
    expect(size.width, 48, reason: 'hit-target не меньше 48');
    expect(size.height, 48);

    await tester.tap(find.byType(VibeIconButton));
    expect(taps, 1);
  });

  testWidgets('8.2.2: pressed scale 0.86 и возврат 1.0', (tester) async {
    await tester.pumpWidget(
      wrap(VibeIconButton(icon: VibeIcons.edit, onPressed: () {})),
    );
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(VibeIconButton)));
    await tester.pump(const Duration(milliseconds: 150));
    final scaled = tester
        .widget<AnimatedScale>(find.byType(AnimatedScale).first)
        .scale;
    expect(scaled, closeTo(0.86, 0.001));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 150));
    final restored = tester
        .widget<AnimatedScale>(find.byType(AnimatedScale).first)
        .scale;
    expect(restored, 1.0);
  });
}