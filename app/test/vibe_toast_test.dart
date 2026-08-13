import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: child);

  testWidgets('показывает тост и скрывает по таймеру', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(host(Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () {
              tapped = true;
              VibeToast.show(context, 'Сохранено');
            },
            child: const Text('tap'),
          ),
        ),
      ),
    )));

    await tester.tap(find.text('tap'));
    expect(tapped, isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Сохранено'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Сохранено'), findsNothing);
  });

  testWidgets('новый тост заменяет предыдущий', (tester) async {
    await tester.pumpWidget(host(Scaffold(
      body: Builder(
        builder: (context) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => VibeToast.show(context, 'Первый'),
              child: const Text('one'),
            ),
            ElevatedButton(
              onPressed: () => VibeToast.show(context, 'Второй'),
              child: const Text('two'),
            ),
          ],
        ),
      ),
    )));

    await tester.tap(find.text('one'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Первый'), findsOneWidget);

    await tester.tap(find.text('two'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Первый'), findsNothing);
    expect(find.text('Второй'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Второй'), findsNothing);
  });

  testWidgets('работает без Scaffold (root overlay)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => VibeToast.show(context, 'Из чистой ноды'),
            child: const Text('plain'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('plain'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Из чистой ноды'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('с иконкой успеха рисуется капсула', (tester) async {
    await tester.pumpWidget(host(Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => VibeToast.show(
              context,
              'Отправлено',
              icon: VibeToastIcons.success,
              iconColor: VibeToastIcons.successColor,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    )));

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Отправлено'), findsOneWidget);
    expect(find.byIcon(VibeIcons.check), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 500));
  });
}