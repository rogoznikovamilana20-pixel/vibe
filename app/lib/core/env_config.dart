/// Конфигурация окружения Vibe.
///
/// Все секреты и внешние адреса передаются на этапе сборки/запуска через
/// `--dart-define` и НЕ хранятся в коде/репозитории:
///
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///
/// Заготовка значений — в файле `.env.example` (см. README).
class EnvConfig {
  EnvConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String tenorApiKey = String.fromEnvironment('TENOR_API_KEY');

  static bool get isReady => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Понятная ошибка при запуске без конфигурации.
  static StateError missingError() => StateError(
        'SUPABASE_URL / SUPABASE_ANON_KEY не заданы. '
        'Запустите с --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... '
        '(примеры — в .env.example и README.md).',
      );
}