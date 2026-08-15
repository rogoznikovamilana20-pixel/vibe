import 'dart:async';

import 'package:vibe_app/data/e2e_v2_service.dart';
import 'package:vibe_app/data/v2_message_storage.dart';
import 'package:vibe_app/data/v2_ratchet.dart';
import 'package:vibe_app/data/v2_ratchet_persistence.dart';
import 'package:vibe_app/data/v2_session_registry.dart';

/// V2 outgoing message handler.
///
/// Handles session bootstrap (X3DH), ratchet persistence,
/// encryption, and storage payload construction.
/// Does NOT handle DB INSERT or realtime — caller handles that.
class V2Outgoing {
  V2Outgoing._();
  static final instance = V2Outgoing._();

  /// Feature flag: V2 outgoing enabled.
  bool enabled = false;

  /// In-memory ratchet state cache, keyed by sessionId.
  final Map<String, V2RatchetState> _ratchetStates = {};

  /// Per-session send queue to prevent concurrent ratchet access.
  final Map<String, Completer<void>> _sendQueues = {};

  /// Per-peer bootstrap lock to prevent concurrent X3DH for same peer.
  final Map<String, Completer<void>> _bootstrapLocks = {};

  // ==========================================================================
  // Ratchet State Load / Save
  // ==========================================================================

  /// Loads ratchet state: cache → SecureStorage → X3DH fallback → fresh init.
  Future<V2RatchetState?> loadRatchetState(String sessionId) async {
    // 1. Check in-memory cache
    final cached = _ratchetStates[sessionId];
    if (cached != null) return cached;

    // 2. Load from SecureStorage (persisted after each encrypt)
    final persisted = await V2RatchetPersistence.instance.load(sessionId);
    if (persisted != null) {
      _ratchetStates[sessionId] = persisted;
      return persisted;
    }

    // 3. Load X3DH session and create initial ratchet state
    final session = await E2eV2Service.instance.loadSession(sessionId);
    if (session == null) return null;

    final state = V2Ratchet.createInitialState(
      sessionId: session.sessionId,
      rootKey: session.rootKey,
      chainKey: session.chainKey,
    );

    _ratchetStates[sessionId] = state;
    // Persist initial state
    await V2RatchetPersistence.instance.save(state);
    return state;
  }

  /// Saves ratchet state to cache AND SecureStorage.
  ///
  /// Policy: save BEFORE DB insert (pre-commit).
  /// If DB insert fails, message key is lost but ratchet state is consistent.
  Future<void> _saveRatchetState(V2RatchetState state) async {
    _ratchetStates[state.sessionId] = state;
    await V2RatchetPersistence.instance.save(state);
  }

  // ==========================================================================
  // Session Bootstrap
  // ==========================================================================

  /// Bootstraps a V2 session with a peer device via X3DH.
  ///
  /// If a session already exists, returns its ID.
  /// If not, performs X3DH handshake, persists session, initializes ratchet.
  ///
  /// Race-safe: concurrent calls for same peer serialize on bootstrap lock.
  Future<String> bootstrapSession({
    required String peerId,
    required String recipientDeviceId,
  }) async {
    final e2e = E2eV2Service.instance;
    if (!e2e.isReady) {
      throw V2OutgoingException('V2 E2E service not ready');
    }

    // Check if session already exists
    final existingSessionId = await V2SessionRegistry.instance.findSessionId(
      peerId: peerId,
      recipientDeviceId: recipientDeviceId,
    );
    if (existingSessionId != null) {
      final session = await e2e.loadSession(existingSessionId);
      if (session != null) return existingSessionId;
      // Session data missing — re-bootstrap
    }

    // Acquire bootstrap lock for this peer
    final lockKey = '$peerId:$recipientDeviceId';
    final pending = _bootstrapLocks[lockKey];
    if (pending != null) {
      await pending.future;
      // Check again after lock release
      final retrySessionId = await V2SessionRegistry.instance.findSessionId(
        peerId: peerId,
        recipientDeviceId: recipientDeviceId,
      );
      if (retrySessionId != null) {
        final session = await e2e.loadSession(retrySessionId);
        if (session != null) return retrySessionId;
      }
    }

    final completer = Completer<void>();
    _bootstrapLocks[lockKey] = completer;

    try {
      return await _performBootstrap(
        peerId: peerId,
        recipientDeviceId: recipientDeviceId,
      );
    } finally {
      completer.complete();
      _bootstrapLocks.remove(lockKey);
    }
  }

  /// Performs the actual X3DH handshake.
  Future<String> _performBootstrap({
    required String peerId,
    required String recipientDeviceId,
  }) async {
    final e2e = E2eV2Service.instance;

    try {
      // 1. Validate recipient bundle
      final bundle = await e2e.fetchKeyBundle(recipientDeviceId);
      if (bundle == null) {
        throw V2OutgoingException(
          'Recipient bundle not found: $recipientDeviceId',
        );
      }

      final valid = await e2e.validateKeyBundle(bundle);
      if (!valid) {
        throw V2OutgoingException(
          'Invalid recipient bundle: $recipientDeviceId',
        );
      }

      // 2. Perform X3DH — returns X3dhMessage with sessionId
      final x3dhMessage = await e2e.initiateX3dh(
        targetDeviceId: recipientDeviceId,
      );

      // 3. Load the persisted session to get rootKey + chainKey
      final session = await e2e.loadSession(x3dhMessage.sessionId);
      if (session == null) {
        throw V2OutgoingException(
          'Session not persisted after X3DH: ${x3dhMessage.sessionId}',
        );
      }

      // 4. Register session in registry
      await V2SessionRegistry.instance.register(
        peerId: peerId,
        recipientDeviceId: recipientDeviceId,
        sessionId: session.sessionId,
      );

      // 5. Initialize ratchet state from X3DH output
      final ratchetState = V2Ratchet.createInitialState(
        sessionId: session.sessionId,
        rootKey: session.rootKey,
        chainKey: session.chainKey,
      );

      // 6. Persist ratchet state
      _ratchetStates[session.sessionId] = ratchetState;
      await V2RatchetPersistence.instance.save(ratchetState);

      return session.sessionId;
    } catch (e) {
      if (e is V2OutgoingException) rethrow;
      throw V2OutgoingException('X3DH handshake failed: $e');
    }
  }

  // ==========================================================================
  // Encryption
  // ==========================================================================

  /// Encrypts plaintext with V2 and returns storage payload.
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

    // Get identity key public bytes
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

    // Save advanced ratchet state (pre-commit: before DB insert)
    await _saveRatchetState(result.state);

    // Build storage payload
    final payload = V2StoredMessage.buildInsertPayload(
      envelope: result.envelope,
      senderId: '',
      chatId: '',
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

  // ==========================================================================
  // Concurrency
  // ==========================================================================

  /// Acquires the send lock for a session.
  Future<Future<void> Function()> _acquireSendLock(String sessionId) async {
    final pending = _sendQueues[sessionId];
    if (pending != null) {
      await pending.future;
    }

    final completer = Completer<void>();
    _sendQueues[sessionId] = completer;

    return () async {
      completer.complete();
      _sendQueues.remove(sessionId);
    };
  }

  // ==========================================================================
  // Cleanup
  // ==========================================================================

  /// Clears cached ratchet state for a session.
  void clearSession(String sessionId) {
    _ratchetStates.remove(sessionId);
  }

  /// Clears all cached ratchet state.
  void clearAll() {
    _ratchetStates.clear();
    _sendQueues.clear();
    _bootstrapLocks.clear();
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
