import 'dart:async';

import 'package:vibe_app/data/e2e_v2_service.dart';
import 'package:vibe_app/data/v2_message_storage.dart';
import 'package:vibe_app/data/v2_ratchet.dart';

/// V2 outgoing message handler.
///
/// Handles V2 encryption + storage payload construction.
/// Does NOT handle DB INSERT or realtime — caller handles that.
class V2Outgoing {
  V2Outgoing._();
  static final instance = V2Outgoing._();

  /// Feature flag: V2 outgoing enabled.
  ///
  /// When false, sendText uses V1 path (existing behavior).
  /// When true, sendText attempts V2 encryption.
  bool enabled = false;

  /// In-memory ratchet state cache, keyed by sessionId.
  ///
  /// After X3DH, the initial ratchet state is created from session data.
  /// After each encrypt, the advanced state is stored here.
  /// Lost on app restart — re-initialized from X3DH session.
  final Map<String, V2RatchetState> _ratchetStates = {};

  /// Per-session send queue to prevent concurrent ratchet access.
  ///
  /// Dart is single-threaded, but async gaps between encrypt steps
  /// could allow interleaving. This queue serializes sends per session.
  final Map<String, Completer<void>> _sendQueues = {};

  /// Loads or creates ratchet state for a session.
  ///
  /// If state exists in cache, returns it.
  /// If not, creates initial state from X3DH session data.
  /// Returns null if session doesn't exist.
  Future<V2RatchetState?> loadRatchetState(String sessionId) async {
    // Check cache first
    final cached = _ratchetStates[sessionId];
    if (cached != null) return cached;

    // Load X3DH session
    final session = await E2eV2Service.instance.loadSession(sessionId);
    if (session == null) return null;

    // Create initial ratchet state from X3DH output
    // Initiator has sendingChainKey (can send first)
    final state = V2Ratchet.createInitialState(
      sessionId: session.sessionId,
      rootKey: session.rootKey,
      chainKey: session.chainKey,
    );

    _ratchetStates[sessionId] = state;
    return state;
  }

  /// Saves ratchet state to cache after encrypt.
  void _saveRatchetState(V2RatchetState state) {
    _ratchetStates[state.sessionId] = state;
  }

  /// Acquires the send lock for a session.
  ///
  /// Returns a release function that must be called when done.
  Future<Future<void> Function()> _acquireSendLock(String sessionId) async {
    // Wait for any pending send on this session
    final pending = _sendQueues[sessionId];
    if (pending != null) {
      await pending.future;
    }

    // Create new lock
    final completer = Completer<void>();
    _sendQueues[sessionId] = completer;

    return () async {
      completer.complete();
      _sendQueues.remove(sessionId);
    };
  }

  /// Encrypts plaintext with V2 and returns storage payload.
  ///
  /// Returns null if V2 encryption is not possible (no session, etc.).
  /// Throws controlled exceptions on encryption failure.
  ///
  /// The caller must handle DB INSERT and ratchet state persistence.
  Future<V2EncryptResult> encrypt({
    required String sessionId,
    required String plaintext,
    required String recipientDeviceId,
  }) async {
    final e2e = E2eV2Service.instance;
    if (!e2e.isReady) {
      throw V2OutgoingException('V2 E2E service not ready');
    }

    // Load ratchet state
    var state = await loadRatchetState(sessionId);
    if (state == null) {
      throw V2OutgoingException('V2 session not found: $sessionId');
    }

    // Get identity key public bytes (for AAD + envelope header)
    final identityKeyPublic = await e2e.getIdentityKeyPublicBytes();
    if (identityKeyPublic == null) {
      throw V2OutgoingException('Identity key not available');
    }

    // Get device IDs
    final senderDeviceId = await e2e.getDeviceId();
    if (senderDeviceId == null) {
      throw V2OutgoingException('Device ID not available');
    }

    // Encrypt with Double Ratchet
    final result = await V2Ratchet.encryptToEnvelope(
      state: state,
      plaintext: plaintext,
      identityKeyPublic: identityKeyPublic,
      senderDeviceId: senderDeviceId,
      recipientDeviceId: recipientDeviceId,
    );

    // Save advanced ratchet state
    _saveRatchetState(result.state);

    // Build storage payload
    final payload = V2StoredMessage.buildInsertPayload(
      envelope: result.envelope,
      senderId: '', // caller fills in
      chatId: '', // caller fills in
    );

    return V2EncryptResult(
      payload: payload,
      envelope: result.envelope,
      newState: result.state,
    );
  }

  /// Encrypts with concurrency control.
  ///
  /// Serializes sends per session to prevent ratchet state races.
  Future<V2EncryptResult> encryptSerialized({
    required String sessionId,
    required String plaintext,
    required String recipientDeviceId,
  }) async {
    final release = await _acquireSendLock(sessionId);
    try {
      return await encrypt(
        sessionId: sessionId,
        plaintext: plaintext,
        recipientDeviceId: recipientDeviceId,
      );
    } finally {
      await release();
    }
  }

  /// Clears cached ratchet state for a session.
  ///
  /// Used when session is deleted or reset.
  void clearSession(String sessionId) {
    _ratchetStates.remove(sessionId);
  }

  /// Clears all cached ratchet state.
  void clearAll() {
    _ratchetStates.clear();
    _sendQueues.clear();
  }
}

/// Result of V2 encryption.
class V2EncryptResult {
  final Map<String, dynamic> payload;
  final V2MessageEnvelope envelope;
  final V2RatchetState newState;

  const V2EncryptResult({
    required this.payload,
    required this.envelope,
    required this.newState,
  });
}

/// V2 outgoing error.
class V2OutgoingException implements Exception {
  final String message;
  const V2OutgoingException(this.message);

  @override
  String toString() => 'V2OutgoingException: $message';
}
