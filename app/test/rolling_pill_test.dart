import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vibe_app/chat/widgets/chat_composer.dart';

void main() {
  testWidgets('RollingPill: таймер тикает внутри пилюли (5.6)', (tester) async {
    final ticks = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RollingPill(
          locked: false,
          onCancel: () {},
          onSend: () {},
          onTick: ticks.add,
        ),
      ),
    ));
    expect(find.text('0:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:01'), findsOneWidget);
    expect(ticks, [1]);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('0:03'), findsOneWidget);
    expect(ticks, [1, 2, 3]);

    // Убираем пилюлю — таймер должен отмениться, иначе pending timer.
    await tester.pumpWidget(const SizedBox());
  });
}