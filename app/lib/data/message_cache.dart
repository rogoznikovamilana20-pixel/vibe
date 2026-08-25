import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Шифрованный персистентный кеш чатов/сообщений + курсоры для gap-recovery.
/// Использует Hive + AES-256 (HiveAesCipher) с ключом 32 байта из SecureStorage.
/// Один бокс `vibe_cache` на устройство+аккаунт, отдельный для каждого myProfileId.
class VibeMessageCache {
  VibeMessageCache._();
  static final VibeMessageCache instance = VibeMessageCache._();

  static const _keyStorageKey = 'vibe_hive_key';
  static const _boxPrefix = 'vibe_cache';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  Box<dynamic>? _box;
  String? _currentAccountId;
  bool _initialized = false;

  bool get isReady => _initialized && _box != null && _box!.isOpen;

  Future<void> init({String? accountId}) async {
    if (_initialized && _currentAccountId == accountId && _box?.isOpen == true) return;
    _currentAccountId = accountId;
    try {
      await Hive.initFlutter();
      final key = await _getOrCreateKey();
      final cipher = HiveAesCipher(key);
      final boxName = accountId == null ? _boxPrefix : '${_boxPrefix}_$accountId';
      if (Hive.isBoxOpen(boxName)) {
        _box = Hive.box(boxName);
      } else {
        _box = await Hive.openBox<dynamic>(boxName, encryptionCipher: cipher);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[VibeMessageCache] init failed: $e');
      _initialized = false;
    }
  }

  Future<Uint8List> _getOrCreateKey() async {
    try {
      final existing = await _secureStorage.read(key: _keyStorageKey);
      if (existing != null && existing.isNotEmpty) {
        final bytes = base64Decode(existing);
        if (bytes.length == 32) return bytes;
      }
    } catch (_) {}
    final rnd = Random.secure();
    final key = Uint8List.fromList(List.generate(32, (_) => rnd.nextInt(256)));
    try {
      await _secureStorage.write(key: _keyStorageKey, value: base64Encode(key));
    } catch (_) {}
    return key;
  }

  // ── Чаты ────────────────────────────────────────────────────────────────
  Future<void> putChats(List<Map<String, dynamic>> chats) async {
    if (!isReady) return;
    try {
      await _box!.put('chats', jsonEncode(chats));
      await _box!.put('chats_updated_at', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  List<Map<String, dynamic>>? getChats() {
    if (!isReady) return null;
    try {
      final raw = _box!.get('chats');
      if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return null;
  }

  // ── Сообщения per chat ────────────────────────────────────────────────
  Future<void> putMessages(String chatId, List<Map<String, dynamic>> msgs) async {
    if (!isReady) return;
    try {
      await _box!.put('msgs_$chatId', jsonEncode(msgs));
      if (msgs.isNotEmpty) {
        // курсор = max created_at
        String? maxTs;
        for (final m in msgs) {
          final ts = m['created_at'] as String?;
          if (ts != null && (maxTs == null || ts.compareTo(maxTs) > 0)) maxTs = ts;
        }
        if (maxTs != null) await _box!.put('cursor_$chatId', maxTs);
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>>? getMessages(String chatId) {
    if (!isReady) return null;
    try {
      final raw = _box!.get('msgs_$chatId');
      if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return null;
  }

  String? getCursor(String chatId) {
    if (!isReady) return null;
    try {
      return _box!.get('cursor_$chatId') as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> setCursor(String chatId, String isoTs) async {
    if (!isReady) return;
    try {
      await _box!.put('cursor_$chatId', isoTs);
    } catch (_) {}
  }

  // ── Утилиты ───────────────────────────────────────────────────────────
  Future<void> clear() async {
    if (!isReady) return;
    try {
      await _box!.clear();
    } catch (_) {}
  }

  Future<void> clearChat(String chatId) async {
    if (!isReady) return;
    try {
      await _box!.delete('msgs_$chatId');
      await _box!.delete('cursor_$chatId');
    } catch (_) {}
  }

  // Generic raw (для миграции старого file-cache)
  Future<void> putRaw(String key, Object data) async {
    if (!isReady) return;
    try {
      await _box!.put(key, jsonEncode(data));
    } catch (_) {}
  }

  dynamic getRaw(String key) {
    if (!isReady) return null;
    try {
      final raw = _box!.get(key);
      if (raw is String && raw.isNotEmpty) return jsonDecode(raw);
    } catch (_) {}
    return null;
  }

  Future<void> dispose() async {
    try {
      await _box?.close();
    } catch (_) {}
    _box = null;
    _initialized = false;
  }
}
