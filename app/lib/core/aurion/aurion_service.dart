import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'aurion_provider.dart';
import 'gigachat_provider.dart';

/// Хранилище секретов (keyring). В проде — [FlutterSecureStorage],
/// в тестах — in-memory фейк.
abstract interface class SecretStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// [SecretStorage] поверх system keyring (flutter_secure_storage).
class KeyringSecretStorage implements SecretStorage {
  const KeyringSecretStorage();

  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Состояние AI-фичи (PRD 2.5.3):
///  - [AurionStatus.introspection] — первый запуск, мастер настройки;
///  - [AurionStatus.enabled] — ключ валиден, провайдер жив;
///  - [AurionStatus.degraded] — провайдер недоступен/лимиты (честный статус);
///  - [AurionStatus.disabled] — ключа нет/невалиден или пользователь off.
enum AurionStatus { introspection, enabled, degraded, disabled }

/// Единая точка доступа UI к Aurion. Хранит ключ в secure storage,
/// состояние — в ChangeNotifier (UI подписывается и честно показывает
/// enabled/degraded/disabled; в disabled AI-элементы скрыты — No fake features).
class AurionService extends ChangeNotifier {
  AurionService._();
  static final instance = AurionService._();

  static const _keyEnabled = 'vibe_aurion_enabled';
  static const _keyApiKey = 'vibe_aurion_api_key';

  late SharedPreferences _prefs;

  /// Фабрика провайдера — в тестах подменяется фейком.
  AurionProvider Function() providerFactory = () => GigaChatProvider();

  /// Хранилище ключа — в тестах in-memory фейк.
  SecretStorage secretStorage = const KeyringSecretStorage();

  AurionProvider? _provider;
  AurionStatus _status = AurionStatus.introspection;

  AurionStatus get status => _status;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final apiKey = await secretStorage.read(_keyApiKey);
    final enabled = _prefs.getBool(_keyEnabled) ?? false;
    if (!enabled || apiKey == null || apiKey.isEmpty) {
      _status = AurionStatus.disabled;
    } else {
      _status = AurionStatus.enabled;
      _bindProvider(apiKey);
    }
    notifyListeners();
  }

  void _bindProvider(String apiKey) {
    final provider = providerFactory();
    provider.configure(apiKey);
    _provider = provider;
  }

  /// Пользователь включил Aurion и ввёл ключ.
  Future<void> enable(String apiKey) async {
    await secretStorage.write(_keyApiKey, apiKey.trim());
    await _prefs.setBool(_keyEnabled, true);
    final provider = providerFactory();
    provider.configure(apiKey);
    var ok = false;
    try {
      ok = await provider.ping();
    } catch (_) {
      ok = false;
    }
    if (ok) {
      _provider = provider;
      _status = AurionStatus.enabled;
    } else {
      _status = AurionStatus.disabled;
    }
    notifyListeners();
    return;
  }

  /// Пользователь выключил Aurion (ключ стирается).
  Future<void> disable() async {
    await secretStorage.delete(_keyApiKey);
    await _prefs.setBool(_keyEnabled, false);
    _provider = null;
    _status = AurionStatus.disabled;
    notifyListeners();
  }

  /// Невалидный ключ / сбой провайдера — честный статус. Не сбрасывает
  /// ключ (пользователь может исправить, не вводя заново).
  void markDegraded() {
    if (_status == AurionStatus.enabled) {
      _status = AurionStatus.degraded;
      notifyListeners();
    }
  }

  void markRecovered() {
    if (_status == AurionStatus.degraded) {
      _status = AurionStatus.enabled;
      notifyListeners();
    }
  }

  /// Главный метод: запрос → ответ или [AurionException]. При ошибке
  /// статус уходит в degraded (честный статус в UI), исключение
  /// проскакивает для кнопки «Повторить».
  Future<String> complete(String prompt, {String? systemPrompt}) async {
    final provider = _provider;
    if (provider == null) {
      throw const AurionException('Aurion временно недоступен.');
    }
    try {
      final result = await provider.complete(
        AurionRequest(prompt: prompt, systemPrompt: systemPrompt),
      );
      markRecovered();
      return result;
    } on AurionException {
      markDegraded();
      rethrow;
    } catch (_) {
      markDegraded();
      throw const AurionException('Aurion временно недоступен.');
    }
  }

  @override
  void dispose() {
    _provider = null;
    super.dispose();
  }
}