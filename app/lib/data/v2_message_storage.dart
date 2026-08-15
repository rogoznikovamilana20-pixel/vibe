import 'dart:convert';

import 'package:vibe_app/data/v2_ratchet.dart';

/// V2 message storage contract.
///
/// Handles conversion between V2MessageEnvelope (binary) and
/// Supabase TEXT column (base64). Includes validation and payload limits.
class V2StoredMessage {
  /// Protocol version for V2 messages.
  static const int protocolVersion = 2;

  /// Maximum envelope size in bytes (after base64 decoding).
  /// Prevents memory abuse and parser attacks.
  /// V2 text-only: header(73) + nonce(12) + max_ciphertext(65536) + tag(16) = 65637.
  /// Rounded up to 66000 for safety margin.
  static const int maxEnvelopeBytes = 66000;

  /// Maximum base64 string length (ceil(66000 * 4/3) + padding).
  static const int maxBase64Length = 88000;

  /// Minimum envelope size: header(73) + nonce(12) + tag(16) = 101 bytes.
  static const int minEnvelopeBytes = 101;

  /// Encodes a V2MessageEnvelope to base64 for storage.
  ///
  /// Returns base64 string suitable for TEXT column.
  static String encodeToBase64(V2MessageEnvelope envelope) {
    final bytes = envelope.toBytes();
    return base64Encode(bytes);
  }

  /// Decodes a base64 string from storage to V2MessageEnvelope.
  ///
  /// Throws [V2RatchetException] if:
  /// - base64 is malformed
  /// - decoded bytes are too short or too long
  /// - envelope version is not 2
  /// - envelope structure is invalid
  static V2MessageEnvelope decodeFromBase64(String base64String) {
    if (base64String.isEmpty) {
      throw const V2RatchetException('Envelope base64 is empty');
    }

    if (base64String.length > maxBase64Length) {
      throw V2RatchetException(
        'Envelope base64 too long: ${base64String.length} > $maxBase64Length',
      );
    }

    final List<int> bytes;
    try {
      bytes = base64Decode(base64String);
    } catch (e) {
      throw const V2RatchetException('Invalid base64 encoding');
    }

    if (bytes.length < minEnvelopeBytes) {
      throw V2RatchetException(
        'Envelope too short: ${bytes.length} < $minEnvelopeBytes',
      );
    }

    if (bytes.length > maxEnvelopeBytes) {
      throw V2RatchetException(
        'Envelope too large: ${bytes.length} > $maxEnvelopeBytes',
      );
    }

    final envelope = V2MessageEnvelope.fromBytes(bytes);

    if (envelope.version != protocolVersion) {
      throw V2RatchetException(
        'Unsupported protocol version: ${envelope.version} (expected $protocolVersion)',
      );
    }

    return envelope;
  }

  /// Validates a raw byte envelope without fully parsing it.
  ///
  /// Quick checks for structural validity:
  /// - version byte == 2
  /// - minimum length
  /// - maximum length
  /// Returns true if valid, throws [V2RatchetException] if not.
  static bool validateBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const V2RatchetException('Envelope is empty');
    }

    if (bytes[0] != protocolVersion) {
      throw V2RatchetException(
        'Invalid version: ${bytes[0]} (expected $protocolVersion)',
      );
    }

    if (bytes.length < minEnvelopeBytes) {
      throw V2RatchetException(
        'Envelope too short: ${bytes.length} < $minEnvelopeBytes',
      );
    }

    if (bytes.length > maxEnvelopeBytes) {
      throw V2RatchetException(
        'Envelope too large: ${bytes.length} > $maxEnvelopeBytes',
      );
    }

    return true;
  }

  /// Validates a base64 string without fully decoding.
  ///
  /// Quick checks:
  /// - not empty
  /// - length within bounds
  /// - valid base64 characters
  /// Returns true if valid, throws [V2RatchetException] if not.
  static bool validateBase64(String base64String) {
    if (base64String.isEmpty) {
      throw const V2RatchetException('Envelope base64 is empty');
    }

    if (base64String.length > maxBase64Length) {
      throw V2RatchetException(
        'Envelope base64 too long: ${base64String.length} > $maxBase64Length',
      );
    }

    // Check valid base64 characters (A-Z, a-z, 0-9, +, /, =)
    final base64Regex = RegExp(r'^[A-Za-z0-9+/=]+$');
    if (!base64Regex.hasMatch(base64String)) {
      throw const V2RatchetException('Invalid base64 characters');
    }

    return true;
  }

  /// Builds the insert payload for a V2 message.
  ///
  /// Returns a map suitable for Supabase .insert().
  /// The caller must add chat_id, sender_id, and timestamp.
  static Map<String, dynamic> buildInsertPayload({
    required V2MessageEnvelope envelope,
    required String senderId,
    required String chatId,
  }) {
    final encryptedContent = encodeToBase64(envelope);

    return {
      'chat_id': chatId,
      'sender_id': senderId,
      'text': null, // V2 never stores plaintext
      'is_encrypted': true,
      'e2ee_version': protocolVersion,
      'encrypted_content': encryptedContent,
    };
  }

  /// Extracts V2 envelope from a database row.
  ///
  /// Returns null if the row is not a V2 message.
  /// Throws [V2RatchetException] if the row claims V2 but has invalid data.
  static V2MessageEnvelope? extractFromRow(Map<String, dynamic> row) {
    final e2eeVersion = row['e2ee_version'];
    if (e2eeVersion != protocolVersion) {
      return null;
    }

    final encryptedContent = row['encrypted_content'] as String?;
    if (encryptedContent == null || encryptedContent.isEmpty) {
      throw const V2RatchetException(
        'V2 message missing encrypted_content',
      );
    }

    return decodeFromBase64(encryptedContent);
  }

  /// Checks if a database row is a V2 encrypted message.
  static bool isV2Message(Map<String, dynamic> row) {
    return row['e2ee_version'] == protocolVersion &&
        row['is_encrypted'] == true;
  }

  /// Checks if a database row is a V1 encrypted message.
  static bool isV1Message(Map<String, dynamic> row) {
    return row['is_encrypted'] == true &&
        (row['e2ee_version'] == null || row['e2ee_version'] == 1);
  }

  /// Checks if a database row is an unencrypted message.
  static bool isPlaintextMessage(Map<String, dynamic> row) {
    return row['is_encrypted'] != true;
  }
}
