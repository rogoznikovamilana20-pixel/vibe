import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Maps (peerId, recipientDeviceId) → sessionId.
///
/// Used to find existing V2 sessions without knowing the session ID
/// (which depends on ephemeral key from X3DH).
class V2SessionRegistry {
  V2SessionRegistry._();
  static final instance = V2SessionRegistry._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const _storageKey = 'e2e_v2_session_registry';

  /// In-memory cache of the registry.
  Map<String, String>? _cache;

  /// Storage key for a peer+device combination.
  String _entryKey(String peerId, String recipientDeviceId) =>
      '$peerId:$recipientDeviceId';

  /// Loads registry from SecureStorage.
  Future<Map<String, String>> _load() async {
    if (_cache != null) return _cache!;
    final data = await _secureStorage.read(key: _storageKey);
    if (data == null) {
      _cache = {};
      return _cache!;
    }
    _cache = Map<String, String>.from(
      jsonDecode(data) as Map<String, dynamic>,
    );
    return _cache!;
  }

  /// Saves registry to SecureStorage.
  Future<void> _save(Map<String, String> registry) async {
    _cache = registry;
    await _secureStorage.write(
      key: _storageKey,
      value: jsonEncode(registry),
    );
  }

  /// Registers a session for a peer+device combination.
  Future<void> register({
    required String peerId,
    required String recipientDeviceId,
    required String sessionId,
  }) async {
    final registry = await _load();
    registry[_entryKey(peerId, recipientDeviceId)] = sessionId;
    await _save(registry);
  }

  /// Finds the session ID for a peer+device combination.
  Future<String?> findSessionId({
    required String peerId,
    required String recipientDeviceId,
  }) async {
    final registry = await _load();
    return registry[_entryKey(peerId, recipientDeviceId)];
  }

  /// Finds all session IDs for a given peer.
  Future<List<String>> findSessionsByPeer(String peerId) async {
    final registry = await _load();
    final sessions = <String>[];
    for (final entry in registry.entries) {
      final parts = entry.key.split(':');
      if (parts.length == 2 && parts[0] == peerId) {
        sessions.add(entry.value);
      }
    }
    return sessions;
  }

  /// Removes a session registration.
  Future<void> remove({
    required String peerId,
    required String recipientDeviceId,
  }) async {
    final registry = await _load();
    registry.remove(_entryKey(peerId, recipientDeviceId));
    await _save(registry);
  }

  /// Clears the in-memory cache (for testing).
  void clearCache() {
    _cache = null;
  }
}
