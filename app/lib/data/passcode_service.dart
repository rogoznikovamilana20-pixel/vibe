import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PasscodeService {
  PasscodeService._();
  static final instance = PasscodeService._();

  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();
  final _random = Random.secure();

  static const _keyPasscode = 'vibe_passcode';
  static const _keyBiometrics = 'vibe_biometrics_enabled';
  static const _keyAttempts = 'vibe_passcode_attempts';
  static const _keyLockedUntil = 'vibe_passcode_locked_until';
  static const _keyAutoLockSec = 'vibe_passcode_auto_lock_sec';

  /// Длина код-пароля (используется и при задании, и при вводе).
  static const int passcodeLength = 4;

  /// Максимум неудачных попыток до временной блокировки.
  static const int maxAttempts = 5;

  /// Длительность блокировки после [maxAttempts] ошибок.
  static const Duration lockDuration = Duration(seconds: 30);

  String? _cachedSalt;
  String? _cachedHash;
  bool _biometricsEnabled = false;
  int _attempts = 0;
  DateTime? _lockedUntil;
  int _autoLockSec = 0;

  DateTime? _lastPausedAt;

  Future<void> init() async {
    final raw = await _storage.read(key: _keyPasscode);
    if (raw != null) {
      final parts = raw.split(':');
      if (parts.length == 2) {
        _cachedSalt = parts[0];
        _cachedHash = parts[1];
      }
    }
    final bio = await _storage.read(key: _keyBiometrics);
    _biometricsEnabled = bio == 'true';
    final attempts = await _storage.read(key: _keyAttempts);
    _attempts = int.tryParse(attempts ?? '') ?? 0;
    final lockedUntil = await _storage.read(key: _keyLockedUntil);
    final ts = int.tryParse(lockedUntil ?? '');
    _lockedUntil = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;
    final prefs = await SharedPreferences.getInstance();
    _autoLockSec = prefs.getInt(_keyAutoLockSec) ?? 60;
  }

  bool get hasPasscode => _cachedSalt != null && _cachedHash != null;
  bool get biometricsEnabled => _biometricsEnabled;

  /// Оставшееся время блокировки (если активна).
  Duration? get lockRemaining {
    final until = _lockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get isLocked => (lockRemaining ?? Duration.zero).inSeconds > 0;

  /// Сколько неудачных попыток осталось до блокировки.
  int get attemptsRemaining => max(maxAttempts - _attempts, 0);

  /// Интервал автоблокировки после сворачивания приложения (0 = отключено).
  int get autoLockSeconds => _autoLockSec;

  Future<void> setPasscode(String passcode) async {
    final salt = _randomBytesHex(16);
    final hash = _hash(passcode, salt);
    await _storage.write(key: _keyPasscode, value: '$salt:$hash');
    _cachedSalt = salt;
    _cachedHash = hash;
    await _resetAttempts();
  }

  Future<void> removePasscode() async {
    await _storage.delete(key: _keyPasscode);
    _cachedSalt = null;
    _cachedHash = null;
    await setBiometricsEnabled(false);
    await _resetAttempts();
  }

  Future<bool> verifyPasscode(String passcode) async {
    if (isLocked) return false;
    final salt = _cachedSalt;
    final hash = _cachedHash;
    if (salt == null || hash == null) return false;
    final ok = _hash(passcode, salt) == hash;
    if (ok) {
      await _resetAttempts();
    } else {
      await _registerFailedAttempt();
    }
    return ok;
  }

  String _hash(String passcode, String salt) {
    return sha256.convert(utf8.encode('$salt:$passcode')).toString();
  }

  String _randomBytesHex(int length) {
    final bytes = List<int>.generate(length, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _registerFailedAttempt() async {
    _attempts += 1;
    await _storage.write(key: _keyAttempts, value: '$_attempts');
    if (_attempts >= maxAttempts) {
      _lockedUntil = DateTime.now().add(lockDuration);
      await _storage.write(
        key: _keyLockedUntil,
        value: '${_lockedUntil!.millisecondsSinceEpoch}',
      );
    }
  }

  Future<void> _resetAttempts() async {
    _attempts = 0;
    _lockedUntil = null;
    await _storage.delete(key: _keyAttempts);
    await _storage.delete(key: _keyLockedUntil);
  }

  /// Отметить момент сворачивания приложения (для автоблокировки).
  void onAppPaused() {
    _lastPausedAt = DateTime.now();
  }

  /// Нужно ли показать экран блокировки при возврате в приложение.
  Future<bool> shouldLockOnResume() async {
    if (!hasPasscode || _autoLockSec <= 0) return false;
    final pausedAt = _lastPausedAt;
    if (pausedAt == null) return false;
    return DateTime.now().difference(pausedAt) >=
        Duration(seconds: _autoLockSec);
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    _autoLockSec = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoLockSec, seconds);
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometrics, value: enabled.toString());
    _biometricsEnabled = enabled;
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_biometricsEnabled) return false;
    try {
      return await _auth.authenticate(
        localizedReason: 'Подтвердите личность для входа в Vibe',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> canUseBiometrics() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
