import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Trust state for a peer's identity key.
///
/// Stored locally — server CANNOT modify.
enum IdentityTrustState {
  unknown,
  verified,
  changed,
}

/// Result of key change detection.
enum KeyChangeResult {
  unchanged,
  changed,
  firstContact,
}

/// Abstract storage interface for identity verification data.
///
/// Allows injecting different storage backends:
/// - Production: FlutterSecureStorage
/// - Tests: In-memory map
abstract class IdentityVerificationStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<Map<String, String>> readAll();
}

/// In-memory storage for testing.
class InMemoryIdentityStorage extends IdentityVerificationStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.from(_data);
}

/// Identity verification service for V2 E2EE.
///
/// Provides:
/// - Fingerprint generation from identity public key
/// - Local trust state management (UNKNOWN/VERIFIED/CHANGED)
/// - Key change detection
/// - Safety code comparison for out-of-band verification
///
/// ## Security Properties
///
/// - Trust state is LOCAL ONLY — server cannot modify
/// - Fingerprint uses SHA-256 with domain separation
/// - Key change detection compares stored vs. received identity key
/// - Server cannot silently mark attacker identity as verified
class E2eV2IdentityVerification {
  E2eV2IdentityVerification._(this._storage);
  static final instance = E2eV2IdentityVerification._(InMemoryIdentityStorage());

  /// Creates an instance with custom storage (for testing or production).
  factory E2eV2IdentityVerification.withStorage(IdentityVerificationStorage storage) {
    return E2eV2IdentityVerification._(storage);
  }

  final IdentityVerificationStorage _storage;

  /// Domain separation label for identity fingerprint.
  static const String _domainLabel = 'VIBE-E2EE-IDENTITY-FINGERPRINT-V1';

  /// Storage key prefix for trust state.
  static const String _trustKeyPrefix = 'e2e_v2_trust_';

  /// Storage key prefix for stored identity keys (for change detection).
  static const String _storedKeyPrefix = 'e2e_v2_stored_ik_';

  // ===========================================================================
  // Fingerprint Generation
  // ===========================================================================

  /// Generates a deterministic fingerprint from an identity public key.
  ///
  /// Uses SHA-256 with domain separation:
  /// `SHA-256(domain_label || identity_public_key)`
  ///
  /// Returns 60-digit numeric safety code (12 groups of 5 digits).
  static Future<String> generateFingerprint(List<int> identityPublicKey) async {
    final sha256 = Sha256();
    final domainBytes = utf8.encode(_domainLabel);
    final hash = await sha256.hash([...domainBytes, ...identityPublicKey]);
    final hashBytes = hash.bytes;
    final numericStr = _bytesToNumericString(hashBytes, 25);
    return _formatSafetyCode(numericStr);
  }

  /// Generates fingerprint from base64-encoded identity public key.
  static Future<String> generateFingerprintFromBase64(String identityKeyB64) async {
    final keyBytes = base64Decode(identityKeyB64);
    return generateFingerprint(keyBytes);
  }

  /// Converts bytes to a numeric string of specified digit count.
  static String _bytesToNumericString(List<int> bytes, int maxBytes) {
    final limited = bytes.take(maxBytes).toList();
    var digits = <int>[];
    var remaining = limited.toList();

    while (remaining.any((b) => b != 0)) {
      var carry = 0;
      final newRemaining = <int>[];
      for (final byte in remaining) {
        final value = carry * 256 + byte;
        newRemaining.add(value ~/ 10);
        carry = value % 10;
      }
      digits.add(carry);
      remaining = newRemaining;
      while (remaining.isNotEmpty && remaining.first == 0) {
        remaining.removeAt(0);
      }
    }

    digits = digits.reversed.toList();
    final result = digits.join();
    return result.padLeft(60, '0').substring(0, 60);
  }

  /// Formats a 60-digit string as safety code: XXXXX XXXXX ...
  static String _formatSafetyCode(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < 60; i += 5) {
      if (i > 0) buf.write(' ');
      buf.write(digits.substring(i, i + 5));
    }
    return buf.toString();
  }

  // ===========================================================================
  // Trust State Management
  // ===========================================================================

  /// Gets the trust state for a peer's identity key.
  Future<IdentityTrustState> getTrustState(String peerId) async {
    final data = await _storage.read('$_trustKeyPrefix$peerId');
    if (data == null) return IdentityTrustState.unknown;
    return IdentityTrustState.values.firstWhere(
      (e) => e.name == data,
      orElse: () => IdentityTrustState.unknown,
    );
  }

  /// Sets the trust state for a peer's identity key.
  /// LOCAL ONLY operation — server cannot trigger this.
  Future<void> setTrustState(String peerId, IdentityTrustState state) async {
    await _storage.write('$_trustKeyPrefix$peerId', state.name);
  }

  /// Stores a peer's identity key for change detection.
  Future<void> storeIdentityKey(String peerId, List<int> identityKey) async {
    await _storage.write('$_storedKeyPrefix$peerId', base64Encode(identityKey));
  }

  /// Loads a peer's stored identity key.
  Future<List<int>?> loadStoredIdentityKey(String peerId) async {
    final data = await _storage.read('$_storedKeyPrefix$peerId');
    if (data == null) return null;
    return base64Decode(data);
  }

  // ===========================================================================
  // Key Change Detection
  // ===========================================================================

  /// Checks if the received identity key matches the stored key.
  Future<KeyChangeResult> checkKeyChange({
    required String peerId,
    required List<int> receivedIdentityKey,
  }) async {
    final storedKey = await loadStoredIdentityKey(peerId);

    if (storedKey == null) {
      await storeIdentityKey(peerId, receivedIdentityKey);
      return KeyChangeResult.firstContact;
    }

    if (_listEquals(storedKey, receivedIdentityKey)) {
      return KeyChangeResult.unchanged;
    }

    return KeyChangeResult.changed;
  }

  /// Handles a detected key change.
  Future<IdentityTrustState> handleKeyChange({
    required String peerId,
    required List<int> newIdentityKey,
  }) async {
    final currentState = await getTrustState(peerId);

    if (currentState == IdentityTrustState.verified) {
      await setTrustState(peerId, IdentityTrustState.changed);
      return IdentityTrustState.changed;
    }

    await storeIdentityKey(peerId, newIdentityKey);
    return currentState;
  }

  /// Verifies a peer's identity key via safety code comparison.
  Future<void> verifyIdentity({
    required String peerId,
    required List<int> identityKey,
  }) async {
    await setTrustState(peerId, IdentityTrustState.verified);
    await storeIdentityKey(peerId, identityKey);
  }

  /// Returns all peer IDs that have trust state stored locally.
  Future<List<String>> getAllPeerIds() async {
    final all = await _storage.readAll();
    final peerIds = <String>{};
    for (final key in all.keys) {
      if (key.startsWith(_trustKeyPrefix)) {
        final peerId = key.substring(_trustKeyPrefix.length);
        if (peerId.isNotEmpty) {
          peerIds.add(peerId);
        }
      }
    }
    return peerIds.toList();
  }

  /// Transitions all VERIFIED peers to CHANGED after local identity rotation.
  ///
  /// Called by rotateIdentity() to ensure that peers who trusted the old
  /// identity do not silently trust the new one without re-verification.
  ///
  /// ## Security Policy
  ///
  /// - VERIFIED → CHANGED (requires explicit re-verification)
  /// - UNKNOWN → UNKNOWN (no change)
  /// - CHANGED → CHANGED (no change)
  /// - Server CANNOT trigger this operation.
  Future<int> transitionAllVerifiedAfterRotation() async {
    final peerIds = await getAllPeerIds();
    var changedCount = 0;
    for (final peerId in peerIds) {
      final state = await getTrustState(peerId);
      if (state == IdentityTrustState.verified) {
        await setTrustState(peerId, IdentityTrustState.changed);
        changedCount++;
      }
    }
    return changedCount;
  }

  /// Resets trust state for a peer.
  Future<void> resetTrustState(String peerId) async {
    await _storage.delete('$_trustKeyPrefix$peerId');
    await _storage.delete('$_storedKeyPrefix$peerId');
  }

  /// Clears all trust data (for testing).
  Future<void> clearAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_trustKeyPrefix) || key.startsWith(_storedKeyPrefix)) {
        await _storage.delete(key);
      }
    }
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
