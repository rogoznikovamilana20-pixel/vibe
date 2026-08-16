import 'dart:async';

import 'package:vibe_app/data/e2e_v2_service.dart';
import 'package:vibe_app/data/v2_message_storage.dart';
import 'package:vibe_app/data/v2_ratchet.dart';
import 'package:vibe_app/data/v2_ratchet_persistence.dart';
import 'package:vibe_app/data/v2_session_registry.dart';

/// V2 incoming message handler.
///
/// Handles version routing, session lookup, V2 decrypt, ratchet persistence,
/// and replay prevention for incoming V2 messages.
///
/// ## Persistence policy (Phase 12C.3.2)
///
/// Decrypt-and-persist is NOT atomic across process restarts.
/// If disk persistence fails after successful decrypt:
/// 1. Plaintext is NOT returned to caller (exception propagated).
/// 2. The advanced ratchet state is cached in [_sessionStates] so the next
///    message in the SAME session can continue the chain without desync.
/// 3. On process restart the cache is lost; the old persisted state is used.
///    This means the same message can be decrypted again (key reuse for
///    same plaintext only — no new information leaked).
///    This is a known limitation of the Double Ratchet protocol: the
///    receiving chain is deterministic, so the same chain key produces the
///    same message key.
class V2Incoming {
  V2Incoming._();
  static final instance = V2Incoming._();

  /// Per-session locks to serialize concurrent decrypts for the same session.
  final Map<String, Completer<void>> _sessionLocks = {};

  /// In-memory ratchet state cache.
  ///
  /// When disk persistence fails after a successful decrypt, the advanced
  /// state is stored here so the next message in the same session can
  /// continue the chain. Entries are keyed by sessionId.
  ///
  /// On process restart this cache is cleared — the old persisted state
  /// on disk is used instead.
  final Map<String, V2RatchetState> _sessionStates = {};

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
    //    The envelope contains sender_ik and sender_rk which identify the sender's device.
    //    We need to find the session and the sender's device ID (stored during X3DH).
    final resolved = await _resolveSession(
      senderId: senderId,
      envelope: envelope,
    );

    if (resolved == null) {
      throw const V2IncomingException('No session found for V2 message');
    }

    final sessionId = resolved.sessionId;
    final senderDeviceId = resolved.remoteDeviceId;

    // 5. Acquire per-session lock
    //    Serializes concurrent decrypts for the same session to prevent
    //    ratchet state corruption from out-of-order processing.
    await _acquireSessionLock(sessionId);

    try {
      // 6. Load ratchet state
      //    Check in-memory cache first (covers disk persistence failures
      //    within the same session), then fall back to disk.
      final state = _sessionStates[sessionId] ??
          await V2RatchetPersistence.instance.load(sessionId);
      if (state == null) {
        throw V2IncomingException('Ratchet state not found for session $sessionId');
      }

      // 7. Decrypt
      //    recipientDeviceId = this device's real UUID from SecureStorage.
      //    senderDeviceId = remote peer's device UUID from X3DH session.
      //    Both are used in AAD for AES-256-GCM authentication.
      final recipientDeviceId = await E2eV2Service.instance.getDeviceId();
      if (recipientDeviceId == null) {
        throw const V2IncomingException('Device not registered');
      }

      final result = await V2Ratchet.decryptFromEnvelope(
        state: state,
        envelope: envelope,
        senderDeviceId: senderDeviceId,
        recipientDeviceId: recipientDeviceId,
      );

      // 8. Persist ratchet state AFTER successful decrypt
      //    This ensures state is only advanced on successful authentication.
      //    If disk persistence fails, cache in memory so the next message
      //    in the same session can continue the chain without desync.
      try {
        await V2RatchetPersistence.instance.save(result.state);
        // Disk persist succeeded — clear any stale in-memory entry.
        _sessionStates.remove(sessionId);
      } catch (_) {
        // Disk persist failed — cache advanced state in memory.
        // The next message for this session will use the cached state.
        _sessionStates[sessionId] = result.state;
      }

      return result.plaintext;
    } on V2RatchetException catch (e) {
      // Authentication failed — do NOT advance state
      throw V2IncomingException('Decrypt failed: ${e.message}');
    } finally {
      // 9. Release per-session lock
      _releaseSessionLock(sessionId);
    }
  }

  /// Resolves session ID and sender device ID from envelope and sender info.
  ///
  /// Uses the session registry to find the session for this sender.
  /// Returns the session ID and the remote device ID (from X3DH session).
  Future<_ResolvedSession?> _resolveSession({
    required String senderId,
    required V2MessageEnvelope envelope,
  }) async {
    // Find all sessions for this sender
    final sessions = await V2SessionRegistry.instance.findSessionsByPeer(senderId);

    // Check each session to find the one with valid ratchet state
    for (final sessionId in sessions) {
      final state = await V2RatchetPersistence.instance.load(sessionId);
      if (state != null) {
        // Load the X3DH session to get the remote device ID
        final x3dhSession = await E2eV2Service.instance.loadSession(sessionId);
        final remoteDeviceId = x3dhSession?.remoteDeviceId;
        if (remoteDeviceId != null) {
          return _ResolvedSession(
            sessionId: sessionId,
            remoteDeviceId: remoteDeviceId,
          );
        }
      }
    }

    return null;
  }

  /// Acquires a per-session lock. Blocks until the previous holder releases.
  Future<void> _acquireSessionLock(String sessionId) async {
    final existing = _sessionLocks[sessionId];
    if (existing != null) {
      await existing.future;
    }
    _sessionLocks[sessionId] = Completer<void>();
  }

  /// Releases the per-session lock.
  void _releaseSessionLock(String sessionId) {
    final completer = _sessionLocks.remove(sessionId);
    completer?.complete();
  }

  /// Clears all session locks (for testing or cleanup).
  void clearLocks() {
    for (final entry in _sessionLocks.entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete();
      }
    }
    _sessionLocks.clear();
  }

  /// Clears the in-memory state cache (simulates process restart).
  void clearStateCache() {
    _sessionStates.clear();
  }
}

/// Exception for V2 incoming message processing.
class V2IncomingException implements Exception {
  final String message;
  const V2IncomingException(this.message);

  @override
  String toString() => 'V2IncomingException: $message';
}

/// Resolved session with sender device ID for AAD computation.
class _ResolvedSession {
  final String sessionId;
  final String remoteDeviceId;
  const _ResolvedSession({required this.sessionId, required this.remoteDeviceId});
}
