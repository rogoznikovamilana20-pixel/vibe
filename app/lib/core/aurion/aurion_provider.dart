/// Aurion — intelligence layer Vibe. Провайдер не знает про UI:
/// только запрос → ответ (или ошибка). Состояния фичи живут в
/// [AurionService], ключи — в secure storage (не в коде).
library;

/// Ошибка провайдера Aurion. UI показывает только [AurionException.userMessage]
/// («Aurion временно недоступен»), никогда — внутренние детали.
class AurionException implements Exception {
  const AurionException(this.userMessage, [this.cause]);

  final String userMessage;

  /// Техническая причина (логи, не UI).
  final Object? cause;

  @override
  String toString() => 'AurionException: $userMessage';
}

/// Запрос к провайдеру: системный промпт + одиночное сообщение пользователя.
class AurionRequest {
  const AurionRequest({
    required this.prompt,
    this.systemPrompt,
    this.timeout = const Duration(seconds: 45),
  });

  final String prompt;
  final String? systemPrompt;
  final Duration timeout;
}

/// Интерфейс AI-провайдера. Реализации: GigaChat (сейчас), позже
/// Claude/Gemini/Local (on-device 2027).
abstract interface class AurionProvider {
  /// Полное имя провайдера (для настроек/диагностики).
  String get name;

  /// Обязательные capabilities (vision, streaming…) — по мере реализации.
  Set<AurionCapability> get capabilities;

  /// Передать API-ключ в рантайме (secure storage → провайдер).
  void configure(String apiKey);

  /// Ответ на [request]. Бросает [AurionException] с пользовательским
  /// сообщением.
  Future<String> complete(AurionRequest request);

  /// Проверка подключения (для «теста ключа» в настройках).
  Future<bool> ping();
}

/// Возможности провайдера: отсутствующая capability прячет
/// соответствующие AI-действия в UI (принцип No fake features).
enum AurionCapability {
  textGeneration,
  streaming,
  vision,
  transcription,
  documents,
}