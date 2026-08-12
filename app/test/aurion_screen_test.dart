import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/core/aurion/aurion_provider.dart';
import 'package:vibe_app/core/aurion/aurion_service.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/data/settings_service.dart';
import 'package:vibe_app/screens/aurion_screen.dart';

class FakeAurionProvider implements AurionProvider {
  FakeAurionProvider({this.fail = false, this.answer = 'Ответ Aurion'});

  bool fail;
  String answer;

  @override
  String get name => 'Fake';

  @override
  Set<AurionCapability> get capabilities => {AurionCapability.textGeneration};

  @override
  void configure(String apiKey) {}

  @override
  Future<String> complete(AurionRequest request) async {
    if (fail) throw const AurionException('Aurion временно недоступен.');
    return answer;
  }

  @override
  Future<bool> ping() async => !fail;
}

class InMemorySecretStorage implements SecretStorage {
  final _map = <String, String>{};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    AurionService.instance.secretStorage = InMemorySecretStorage();
    AurionService.instance.providerFactory = () => FakeAurionProvider();
    await AurionService.instance.init();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: VibeTheme.light(),
        home: AurionScreen(userName: 'Андрей'),
      ),
    );
    await tester.pump();
  }

  testWidgets('Aurion: disabled → карточка подключения, нет суггестий',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Подключите Aurion'), findsOneWidget);
    expect(find.text('Попробуй спросить'), findsNothing);
    expect(find.text('выключен'), findsOneWidget);
  });

  testWidgets('Aurion: невалидный ключ → ошибка в карточке',
      (tester) async {
    AurionService.instance.providerFactory = () => FakeAurionProvider(
          fail: true,
        );
    await pumpScreen(tester);

    await tester.enterText(
      find.byType(TextField).first,
      'bad-key',
    );
    await tester.ensureVisible(find.text('Подключить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подключить'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('проверьте ключ доступа'),
      findsOneWidget,
    );
  });

  testWidgets('Aurion: enabled → суггестии, запрос → AI_PREVIEW draft-first',
      (tester) async {
    final fake = FakeAurionProvider(answer: 'Пересказ готов');
    AurionService.instance.providerFactory = () => fake;
    await AurionService.instance.enable('good');

    await pumpScreen(tester);

    expect(find.text('Попробуй спросить'), findsOneWidget);
    expect(find.text('онлайн'), findsOneWidget);
    expect(find.text('Подключите Aurion'), findsNothing);

    await tester.enterText(
      find.byType(TextField).first,
      'Перескажи чат',
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Перескажи чат',
      reason: 'текст должен попасть в композер',
    );
    await tester.ensureVisible(
      find.byIcon(Icons.arrow_upward_rounded),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Ответ Aurion'), findsOneWidget);
    expect(find.text('Пересказ готов'), findsOneWidget);
    expect(find.text('Вставить в поле'), findsOneWidget);

    await tester.ensureVisible(find.text('Вставить в поле'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вставить в поле'));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Пересказ готов',
    );
    expect(find.text('Ответ Aurion'), findsNothing);
  });

  testWidgets('Aurion: сбой провайдера → ошибка + Повторить',
      (tester) async {
    final fake = FakeAurionProvider();
    AurionService.instance.providerFactory = () => fake;
    await AurionService.instance.enable('good');
    fake.fail = true;

    await pumpScreen(tester);

    await tester.enterText(
      find.byType(TextField).first,
      'Спроси меня',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    await tester.pump();

    expect(find.text('Aurion временно недоступен.'), findsOneWidget);
    expect(find.text('аварийный'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });
}