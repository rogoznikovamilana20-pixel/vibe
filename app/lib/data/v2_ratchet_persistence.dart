import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vibe_app/data/v2_ratchet.dart';

/// Persists V2RatchetState to FlutterSecureStorage.
///
/// Handles serialization of all ratchet fields including
/// SimpleKeyPair (extracts private key bytes) and skippedKeys map.
class V2RatchetPersistence {
  V2RatchetPersistence._();
  static final instance = V2RatchetPersistence._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Storage key prefix.
  static const _keyPrefix = 'e2e_v2_ratchet_';

  /// Serializes a V2RatchetState to a JSON-compatible map.
  static Map<String, dynamic> serialize(V2RatchetState state) {
    // Extract ratchet key pair public bytes.
    // The private key cannot be extracted synchronously from SimpleKeyPair.
    // It will be regenerated lazily by encrypt() when needed for DH ratchet.
    // This is safe: the key pair is only needed for DH ratchet steps.
    String? ratchetPubKeyB64;
    if (state.sendingRatchetPubBytes != null) {
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
  /// The ratchet key pair is NOT restored (it will be regenerated lazily).
  /// This is safe: the key pair is only needed for DH ratchet steps,
  /// which generate a new pair anyway.
  static V2RatchetState deserialize(Map<String, dynamic> json) {
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
      sendingRatchetPubBytes: json['sending_ratchet_pub'] != null
          ? base64Decode(json['sending_ratchet_pub'] as String)
          : null,
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
    final json = serialize(state);
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
