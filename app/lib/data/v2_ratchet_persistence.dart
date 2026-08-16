import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vibe_app/data/v2_ratchet.dart';

/// Persists V2RatchetState to FlutterSecureStorage.
///
/// Handles serialization of all ratchet fields including
/// SimpleKeyPair (extracts/reconstructs private key bytes) and skippedKeys map.
///
/// ## CRITICAL: sendingRatchetKeyPair serialization (Phase 12C.4)
///
/// The X25519 private key of `sendingRatchetKeyPair` IS serialized as
/// `sending_ratchet_priv` (base64). Without this, after process restart:
/// 1. `sendingChainKey` is restored → DH bootstrap is skipped
/// 2. `sendingRatchetKeyPair` is null → new random key pair generated
/// 3. New public key goes in message header
/// 4. Receiver sees new key → triggers unwanted DH ratchet step
/// 5. Sender never performs DH step → chains diverge permanently
/// 6. ALL subsequent messages fail to decrypt (GCM tag mismatch)
///
/// The private key is extracted via `extractPrivateKeyBytes()` and
/// reconstructed via `SimpleKeyPairData()` on deserialization.
class V2RatchetPersistence {
  V2RatchetPersistence._();
  static final instance = V2RatchetPersistence._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Storage key prefix.
  static const _keyPrefix = 'e2e_v2_ratchet_';

  /// Serializes a V2RatchetState to a JSON-compatible map.
  ///
  /// Async because `extractPrivateKeyBytes()` on SimpleKeyPair is async.
  static Future<Map<String, dynamic>> serialize(V2RatchetState state) async {
    // Extract ratchet key pair private + public bytes for full persistence.
    String? ratchetPrivKeyB64;
    String? ratchetPubKeyB64;
    if (state.sendingRatchetKeyPair != null) {
      final privBytes = await state.sendingRatchetKeyPair!.extractPrivateKeyBytes();
      ratchetPrivKeyB64 = base64Encode(privBytes);
      ratchetPubKeyB64 = state.sendingRatchetPubBytes != null
          ? base64Encode(state.sendingRatchetPubBytes!)
          : null;
    } else if (state.sendingRatchetPubBytes != null) {
      ratchetPubKeyB64 = base64Encode(state.sendingRatchetPubBytes!);
    }

    // Serialize skippedKeys: {messageNumber: base64(key)}
    final skippedKeysJson = <String, String>{};
    for (final entry in state.skippedKeys.entries) {
      skippedKeysJson[entry.key.toString()] = base64Encode(entry.value);
    }

    return {
      'session_id': state.sessionId,
      'root_key': base64Encode(state.rootKey),
      'sending_chain_key': state.sendingChainKey != null
          ? base64Encode(state.sendingChainKey!)
          : null,
      'receiving_chain_key': state.receivingChainKey != null
          ? base64Encode(state.receivingChainKey!)
          : null,
      'sending_ratchet_priv': ratchetPrivKeyB64,
      'sending_ratchet_pub': ratchetPubKeyB64,
      'receiving_ratchet_pub': state.receivingRatchetPublicKey != null
          ? base64Encode(state.receivingRatchetPublicKey!)
          : null,
      'sending_message_number': state.sendingMessageNumber,
      'receiving_message_number': state.receivingMessageNumber,
      'previous_sending_chain_length': state.previousSendingChainLength,
      'skipped_keys': skippedKeysJson,
      'protocol_version': state.protocolVersion,
      'ratchet_step': state.ratchetStep,
    };
  }

  /// Deserializes a map to V2RatchetState.
  ///
  /// Reconstructs `sendingRatchetKeyPair` from saved private key bytes
  /// using `SimpleKeyPairData`. This ensures the exact same key pair
  /// is used after restart, maintaining chain continuity.
  static V2RatchetState deserialize(Map<String, dynamic> json) {
    // Reconstruct ratchet key pair from saved private key bytes.
    SimpleKeyPair? ratchetKeyPair;
    List<int>? ratchetPubBytes;
    if (json['sending_ratchet_priv'] != null) {
      final privBytes = base64Decode(json['sending_ratchet_priv'] as String);
      ratchetPubBytes = json['sending_ratchet_pub'] != null
          ? base64Decode(json['sending_ratchet_pub'] as String)
          : null;
      if (ratchetPubBytes != null) {
        ratchetKeyPair = SimpleKeyPairData(
          privBytes,
          publicKey: SimplePublicKey(ratchetPubBytes, type: KeyPairType.x25519),
          type: KeyPairType.x25519,
        );
      }
    } else if (json['sending_ratchet_pub'] != null) {
      // Legacy state: only public key saved (no private key).
      // Key pair cannot be reconstructed — will be regenerated on first encrypt.
      // This is safe ONLY if no DH ratchet step depends on the old key pair.
      ratchetPubBytes = base64Decode(json['sending_ratchet_pub'] as String);
    }

    // Deserialize skippedKeys
    final skippedKeysJson = json['skipped_keys'] as Map<String, dynamic>? ?? {};
    final skippedKeys = <int, List<int>>{};
    for (final entry in skippedKeysJson.entries) {
      skippedKeys[int.parse(entry.key)] = base64Decode(entry.value as String);
    }

    return V2RatchetState(
      sessionId: json['session_id'] as String,
      rootKey: base64Decode(json['root_key'] as String),
      sendingChainKey: json['sending_chain_key'] != null
          ? base64Decode(json['sending_chain_key'] as String)
          : null,
      receivingChainKey: json['receiving_chain_key'] != null
          ? base64Decode(json['receiving_chain_key'] as String)
          : null,
      sendingRatchetKeyPair: ratchetKeyPair,
      sendingRatchetPubBytes: ratchetPubBytes,
      receivingRatchetPublicKey: json['receiving_ratchet_pub'] != null
          ? base64Decode(json['receiving_ratchet_pub'] as String)
          : null,
      sendingMessageNumber: json['sending_message_number'] as int? ?? 0,
      receivingMessageNumber: json['receiving_message_number'] as int? ?? 0,
      previousSendingChainLength:
          json['previous_sending_chain_length'] as int? ?? 0,
      skippedKeys: skippedKeys,
      protocolVersion: json['protocol_version'] as int? ?? 2,
      ratchetStep: json['ratchet_step'] as int? ?? 0,
    );
  }

  /// Saves ratchet state to SecureStorage.
  Future<void> save(V2RatchetState state) async {
    final json = await serialize(state);
    await _secureStorage.write(
      key: '$_keyPrefix${state.sessionId}',
      value: jsonEncode(json),
    );
  }

  /// Loads ratchet state from SecureStorage.
  ///
  /// Returns null if no state exists for this session.
  Future<V2RatchetState?> load(String sessionId) async {
    final data = await _secureStorage.read(key: '$_keyPrefix$sessionId');
    if (data == null) return null;
    final json = jsonDecode(data) as Map<String, dynamic>;
    return deserialize(json);
  }

  /// Deletes ratchet state from SecureStorage.
  Future<void> delete(String sessionId) async {
    await _secureStorage.delete(key: '$_keyPrefix$sessionId');
  }
}
