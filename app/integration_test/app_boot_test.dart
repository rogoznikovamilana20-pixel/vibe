import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:vibe_app/main.dart' as app;

/// 9.4 (MASTER_PLAN): integration-тесты.
///
/// Smoke-boot реального приложения на Windows-десктопе БЕЗ живого бэкенда:
/// `flutter test integration_test -d windows \
///   --dart-define=SUPABASE_URL=http://127.0.0.1:9 \
///   --dart-define=SUPABASE_ANON_KEY=test-anon-key`
///
/// Ожидание: приложение стартует, сплэш отрабатывает, при недоступном
/// сервере честно деградирует на онбординг — без крахов и зависаний.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boot без сети: сплэш → онбординг, без падений', (tester) async {
    app.main();

    // Сплэш живёт 1.4s + сетевые таймауты бэкенда; крутим до 30s.
    var onOnboarding = false;
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (tester.any(find.text('Квантовая безопасность')) ||
          tester.any(find.text('Начать'))) {
        onOnboarding = true;
        break;
      }
    }

    expect(onOnboarding, isTrue,
        reason: 'без сети приложение должно дойти до онбординга, а не висеть');

    // Приложение живо: нет заглушек-крашей, можно скроллить онбординг.
    await tester.tap(find.text('Дальше'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Бизнес прямо в чатах'), findsOneWidget);
  });
}
