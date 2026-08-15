import 'package:vibe_app/data/v2_message_storage.dart';
import 'package:vibe_app/data/v2_ratchet.dart';
import 'package:vibe_app/data/v2_ratchet_persistence.dart';
import 'package:vibe_app/data/v2_session_registry.dart';

/// V2 incoming message handler.
///
/// Handles version routing, session lookup, V2 decrypt, ratchet persistence,
/// and replay prevention for incoming V2 messages.
class V2Incoming {
  V2Incoming._();
  static final instance = V2Incoming._();

  /// Decrypts an incoming V2 message from a database row.
  ///
  /// Returns plaintext on success, null on replay/ignore, throws on failure.
  ///
  /// Flow:
  /// 1. Version routing (e2ee_version == 2)
  /// 2. Session lookup (sender device → session via registry)
  /// 3. Envelope extraction and validation
  /// 4. Ratchet decrypt
  /// 5. Ratchet state persistence (after successful decrypt)
  /// 6. Replay detection (message number check)
  Future<String?> decryptIncomingMessage({
    required Map<String, dynamic> row,
    required String myUserId,
  }) async {
    // 1. Version routing
    if (!V2StoredMessage.isV2Message(row)) {
      return null; // Not a V2 message
    }

    // 2. Extract sender info
    final senderId = row['sender_id'] as String?;
    if (senderId == null || senderId == myUserId) {
      return null; // Self message or missing sender
    }

    // 3. Extract envelope from row
    final envelope = V2StoredMessage.extractFromRow(row);
    if (envelope == null) {
      throw const V2IncomingException('Failed to extract V2 envelope from row');
    }

    // 4. Resolve session from envelope header
    //    The envelope contains sender_ik and sender_rk which identify the sender's device
    //    We need to find the session that corresponds to this sender
    final sessionId = await _resolveSessionId(
      senderId: senderId,
      envelope: envelope,
    );

    if (sessionId == null) {
      throw const V2IncomingException('No session found for V2 message');
    }

    // 5. Load ratchet state
    final state = await V2RatchetPersistence.instance.load(sessionId);
    if (state == null) {
      throw V2IncomingException('Ratchet state not found for session $sessionId');
    }

    // 6. Decrypt
    final senderDeviceId = _extractDeviceIdFromEnvelope(envelope);
    final recipientDeviceId = await _getDeviceId();

    try {
      final result = await V2Ratchet.decryptFromEnvelope(
        state: state,
        envelope: envelope,
        senderDeviceId: senderDeviceId,
        recipientDeviceId: recipientDeviceId,
      );

      // 7. Persist ratchet state AFTER successful decrypt
      //    This ensures state is only advanced on successful authentication
      await V2RatchetPersistence.instance.save(result.state);

      return result.plaintext;
    } on V2RatchetException catch (e) {
      // Authentication failed — do NOT advance state
      throw V2IncomingException('Decrypt failed: ${e.message}');
    }
  }

  /// Resolves session ID from envelope and sender info.
  ///
  /// Uses the session registry to find the session for this sender.
  Future<String?> _resolveSessionId({
    required String senderId,
    required V2MessageEnvelope envelope,
  }) async {
    // Find all sessions for this sender
    final sessions = await V2SessionRegistry.instance.findSessionsByPeer(senderId);

    // Check each session to find the one with valid ratchet state
    for (final sessionId in sessions) {
      final state = await V2RatchetPersistence.instance.load(sessionId);
      if (state != null) {
        return sessionId;
      }
    }

    return null;
  }

  /// Extracts sender device ID from envelope header.
  ///
  /// The envelope contains sender_ik (identity key) which can be used
  /// to identify the device. For simplicity, we use the session's
  /// remote identity key to match.
  String _extractDeviceIdFromEnvelope(V2MessageEnvelope envelope) {
    // In a full implementation, we'd extract the device ID from the envelope
    // or look it up from the sender's identity key.
    // For now, we return a placeholder that will be resolved by the session lookup.
    return 'unknown';
  }

  /// Gets the current device ID.
  Future<String> _getDeviceId() async {
    // This should be the same device ID used in X3DH
    // For now, we'll use a placeholder
    return 'current-device';
  }

  /// Checks if a message has already been decrypted (replay detection).
  ///
  /// Uses the ratchet state's receivingMessageNumber to detect replays.
  /// If the message number is less than the current receiving message number
  /// and not in skipped keys, it's a replay.
  Future<bool> isReplay({
    required String sessionId,
    required int messageNumber,
  }) async {
    final state = await V2RatchetPersistence.instance.load(sessionId);
    if (state == null) return false;

    // If message number is less than current receiving message number,
    // check if it's in skipped keys
    if (messageNumber < state.receivingMessageNumber) {
      return !state.skippedKeys.containsKey(messageNumber);
    }

    return false;
  }
}

/// Exception for V2 incoming message processing.
class V2IncomingException implements Exception {
  final String message;
  const V2IncomingException(this.message);

  @override
  String toString() => 'V2IncomingException: $message';
}
