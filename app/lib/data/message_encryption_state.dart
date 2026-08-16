import 'package:vibe_app/data/v2_message_storage.dart';

/// Unified encryption state for a message row.
///
/// Source of truth for routing: one row → one state → one processing path.
/// No fallbacks, no silent version switching.
enum MessageEncryptionState {
  /// Unencrypted message (is_encrypted != true).
  plaintext,

  /// V1 E2EE encrypted (is_encrypted == true, e2ee_version == null or 1).
  encryptedV1,

  /// V2 E2EE encrypted (is_encrypted == true, e2ee_version == 2).
  encryptedV2,

  /// V2 claimed but ciphertext missing/invalid.
  encryptedV2Unavailable,

  /// V2 decrypt failed (corrupt state, bad tag, missing session, etc.).
  encryptedV2Failed,

  /// Future or unknown e2ee_version (>2 or invalid).
  unsupportedVersion,
}

/// V2 failure categories.
///
/// Maps low-level errors to the appropriate user-facing state.
/// Every V2 error MUST go through this mapping — no ad-hoc error handling.
enum V2FailureCategory {
  /// V2 session not found for sender.
  missingSession,

  /// encrypted_content is null or empty.
  missingCiphertext,

  /// Base64 decoding failed.
  invalidBase64,

  /// Envelope bytes too short or too long.
  truncatedEnvelope,

  /// e2ee_version > 2 or invalid.
  unsupportedVersion,

  /// Envelope version byte != 2.
  invalidProtocolVersion,

  /// Sender identity key mismatch or untrusted.
  invalidSenderIdentity,

  /// Device ID mismatch (AAD verification failed).
  wrongDevice,

  /// Session ID mismatch.
  wrongSession,

  /// AES-GCM authentication tag verification failed.
  invalidAuthenticationTag,

  /// Local ratchet state corrupted or unreadable.
  corruptedState,

  /// Disk persistence failed after successful decrypt.
  persistenceFailure,

  /// Edit/forward attempted on V2 message.
  unsupportedEncryptedOperation,

  /// Envelope exceeds max size.
  oversizedEnvelope,

  /// Message number jump exceeds DoS limit.
  excessiveMessageNumberJump,

  /// Previous chain length exceeds DoS limit.
  excessivePreviousChainLength,

  /// Skipped key store full.
  skippedKeyLimitExceeded,
}

/// Maps failure category to user-facing encryption state.
///
/// FAIL CLOSED: any V2 failure → safe placeholder, never plaintext/V1 fallback.
MessageEncryptionState v2FailureToState(V2FailureCategory category) {
  switch (category) {
    // === Unavailable: ciphertext or session missing ===
    case V2FailureCategory.missingSession:
    case V2FailureCategory.missingCiphertext:
      return MessageEncryptionState.encryptedV2Unavailable;

    // === Failed: decryption or validation error ===
    case V2FailureCategory.invalidBase64:
    case V2FailureCategory.truncatedEnvelope:
    case V2FailureCategory.invalidProtocolVersion:
    case V2FailureCategory.invalidSenderIdentity:
    case V2FailureCategory.wrongDevice:
    case V2FailureCategory.wrongSession:
    case V2FailureCategory.invalidAuthenticationTag:
    case V2FailureCategory.corruptedState:
    case V2FailureCategory.oversizedEnvelope:
    case V2FailureCategory.excessiveMessageNumberJump:
    case V2FailureCategory.excessivePreviousChainLength:
    case V2FailureCategory.skippedKeyLimitExceeded:
      return MessageEncryptionState.encryptedV2Failed;

    // === Unsupported: version or operation ===
    case V2FailureCategory.unsupportedVersion:
      return MessageEncryptionState.unsupportedVersion;

    case V2FailureCategory.unsupportedEncryptedOperation:
      return MessageEncryptionState.encryptedV2Failed;

    // === Persistence: retryable ===
    case V2FailureCategory.persistenceFailure:
      // Persistence failure does NOT change displayed state —
      // the message WAS decrypted successfully. The caller decides
      // whether to retry persistence or use in-memory cache.
      return MessageEncryptionState.encryptedV2;
  }
}

/// Whether a failure category allows safe retry.
///
/// Safe retry = transient, no side effects on retry.
/// Unsafe retry = would produce different result or cause harm.
bool v2FailureAllowsRetry(V2FailureCategory category) {
  switch (category) {
    case V2FailureCategory.persistenceFailure:
      return true; // Transient — retry persistence
    case V2FailureCategory.missingSession:
      return false; // Session must be established via X3DH (outgoing only)
    case V2FailureCategory.missingCiphertext:
      return false; // Data corruption — cannot retry
    case V2FailureCategory.invalidBase64:
    case V2FailureCategory.truncatedEnvelope:
    case V2FailureCategory.invalidProtocolVersion:
    case V2FailureCategory.invalidSenderIdentity:
    case V2FailureCategory.wrongDevice:
    case V2FailureCategory.wrongSession:
    case V2FailureCategory.invalidAuthenticationTag:
    case V2FailureCategory.corruptedState:
    case V2FailureCategory.unsupportedVersion:
    case V2FailureCategory.unsupportedEncryptedOperation:
    case V2FailureCategory.oversizedEnvelope:
    case V2FailureCategory.excessiveMessageNumberJump:
    case V2FailureCategory.excessivePreviousChainLength:
    case V2FailureCategory.skippedKeyLimitExceeded:
      return false; // Unsafe — must not retry
  }
}

/// Whether a failure category advances ratchet state.
///
/// Crypto authentication failure → state MUST remain unchanged.
/// Persistence failure after successful decrypt → state already advanced
/// (per 12C.3.2 policy: in-memory cache covers chain continuity).
bool v2FailureAdvancesState(V2FailureCategory category) {
  switch (category) {
    case V2FailureCategory.persistenceFailure:
      return true; // State advanced during decrypt, persistence failed
    // All other failures: state unchanged
    case V2FailureCategory.missingSession:
    case V2FailureCategory.missingCiphertext:
    case V2FailureCategory.invalidBase64:
    case V2FailureCategory.truncatedEnvelope:
    case V2FailureCategory.invalidProtocolVersion:
    case V2FailureCategory.invalidSenderIdentity:
    case V2FailureCategory.wrongDevice:
    case V2FailureCategory.wrongSession:
    case V2FailureCategory.invalidAuthenticationTag:
    case V2FailureCategory.corruptedState:
    case V2FailureCategory.unsupportedVersion:
    case V2FailureCategory.unsupportedEncryptedOperation:
    case V2FailureCategory.oversizedEnvelope:
    case V2FailureCategory.excessiveMessageNumberJump:
    case V2FailureCategory.excessivePreviousChainLength:
    case V2FailureCategory.skippedKeyLimitExceeded:
      return false;
  }
}

/// Central resolver: database row → encryption state.
///
/// Single source of truth. Pure function — no side effects, no ratchet mutation.
/// Used by: broadcast, history, outgoing result handling.
MessageEncryptionState resolveMessageEncryptionState(Map<String, dynamic> row) {
  final isEncrypted = row['is_encrypted'] == true;
  final e2eeVersion = row['e2ee_version'];

  if (!isEncrypted) {
    return MessageEncryptionState.plaintext;
  }

  // is_encrypted == true
  if (e2eeVersion == null || e2eeVersion == 1) {
    return MessageEncryptionState.encryptedV1;
  }

  if (e2eeVersion == 2) {
    // Check if encrypted_content is present and non-empty
    final encryptedContent = row['encrypted_content'];
    if (encryptedContent == null ||
        encryptedContent is! String ||
        encryptedContent.isEmpty) {
      return MessageEncryptionState.encryptedV2Unavailable;
    }
    return MessageEncryptionState.encryptedV2;
  }

  // e2ee_version > 2 or invalid
  return MessageEncryptionState.unsupportedVersion;
}

/// Maps encryption state to user-facing display text.
///
/// UI never sees crypto internals — only safe placeholders.
String encryptionStateToDisplayText(MessageEncryptionState state) {
  switch (state) {
    case MessageEncryptionState.plaintext:
      return ''; // Caller provides actual text
    case MessageEncryptionState.encryptedV1:
      return '[зашифровано]';
    case MessageEncryptionState.encryptedV2:
      return ''; // Caller decrypts and provides text
    case MessageEncryptionState.encryptedV2Unavailable:
      return 'Зашифрованное сообщение недоступно';
    case MessageEncryptionState.encryptedV2Failed:
      return 'Не удалось расшифровать сообщение';
    case MessageEncryptionState.unsupportedVersion:
      return 'Неподдерживаемая версия шифрования';
  }
}

/// Whether this encryption state allows edit operations.
bool canEditMessage(MessageEncryptionState state) {
  return state == MessageEncryptionState.plaintext ||
      state == MessageEncryptionState.encryptedV1;
}

/// Whether this encryption state allows forward operations.
bool canForwardMessage(MessageEncryptionState state) {
  return state == MessageEncryptionState.plaintext ||
      state == MessageEncryptionState.encryptedV1;
}
