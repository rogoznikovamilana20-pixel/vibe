import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/message_encryption_state.dart';
import 'package:vibe_app/data/v2_ratchet.dart';

void main() {
  // ===========================================================================
  // 1. FAILURE CATEGORY → STATE MAPPING
  // ===========================================================================

  group('V2FailureCategory → MessageEncryptionState', () {
    test('missingSession → encryptedV2Unavailable', () {
      expect(
        v2FailureToState(V2FailureCategory.missingSession),
        MessageEncryptionState.encryptedV2Unavailable,
      );
    });

    test('missingCiphertext → encryptedV2Unavailable', () {
      expect(
        v2FailureToState(V2FailureCategory.missingCiphertext),
        MessageEncryptionState.encryptedV2Unavailable,
      );
    });

    test('invalidBase64 → encryptedV2Failed', () {
      expect(
        v2FailureToState(V2FailureCategory.invalidBase64),
        MessageEncryptionState.encryptedV2Failed,
      );
    });

    test('truncatedEnvelope → encryptedV2Failed', () {
      expect(
        v2FailureToState(V2FailureCategory.truncatedEnvelope),
        MessageEncryptionState.encryptedV2Failed,
      );
    });

    test('unsupportedVersion → unsupportedVersion', () {
      expect(
        v2FailureToState(V2FailureCategory.unsupportedVersion),
        MessageEncryptionState.unsupportedVersion,
      );
    });

    test('invalidProtocolVersion → encryptedV2Failed', () {
      expect(
        v2FailureToState(V2FailureCategory.invalidProtocolVersion),
        MessageEncryptionState.encryptedV2Failed,
      );
    });

    test('invalidSenderIdentity → encryptedV2Failed', () {
      expect(
        v2FailureToState(V2FailureCategory.invalidSenderIdentity),
        MessageEncryptionState.encryptedV2Failed,
      );
    });

    test('wrongDevice → encryptedV2Failed', () {
      expect(
        v2FailureToState(V2FailureCategory.wrongDevice),
        MessageEncryptionState.encryptedV2Failed,
      );
    });

    test('wrongSession → encryptedV2Failed', () {
      expect(
        v2FailureToState(V2FailureCategory.wrongSession),
        MessageEncryptionState.encryptedV2Failed,
      );
    });

    test('invalidAuthenticationTag → encryptedV2Failed', () {
      expect(
        v2FailureToState(V2FailureCategory.invalidAuthenticationTag),
        MessageEncryptionState.encryptedV2Failed,
      );
    });

    test('corruptedState → encryptedV2Failed', () {
      expect(
        v2FailureToState(V2FailureCategory.corruptedState),
        MessageEncryptionState.encryptedV2Failed,
      );
    });

    test('persistenceFailure → encryptedV2 (decrypt succeeded)', () {
      // Persistence failure: decrypt WAS successful, state already advanced.
      // The message is displayed — only persistence failed.
      expect(
        v2FailureToState(V2FailureCategory.persistenceFailure),
        MessageEncryptionState.encryptedV2,
      );
    });

    test('unsupportedEncryptedOperation → encryptedV2Failed', () {
      expect(
        v2FailureToState(V2FailureCategory.unsupportedEncryptedOperation),
        MessageEncryptionState.encryptedV2Failed,
      );
    });

    test('oversizedEnvelope → encryptedV2Failed', () {
      expect(
        v2FailureToState(V2FailureCategory.oversizedEnvelope),
        MessageEncryptionState.encryptedV2Failed,
      );
    });

    test('excessiveMessageNumberJump → encryptedV2Failed', () {
      expect(
        v2FailureToState(V2FailureCategory.excessiveMessageNumberJump),
        MessageEncryptionState.encryptedV2Failed,
      );
    });

    test('excessivePreviousChainLength → encryptedV2Failed', () {
      expect(
        v2FailureToState(V2FailureCategory.excessivePreviousChainLength),
        MessageEncryptionState.encryptedV2Failed,
      );
    });

    test('skippedKeyLimitExceeded → encryptedV2Failed', () {
      expect(
        v2FailureToState(V2FailureCategory.skippedKeyLimitExceeded),
        MessageEncryptionState.encryptedV2Failed,
      );
    });
  });

  // ===========================================================================
  // 2. RETRY POLICY
  // ===========================================================================

  group('v2FailureAllowsRetry', () {
    test('persistenceFailure: retry allowed', () {
      expect(v2FailureAllowsRetry(V2FailureCategory.persistenceFailure), true);
    });

    test('missingSession: no retry', () {
      expect(v2FailureAllowsRetry(V2FailureCategory.missingSession), false);
    });

    test('invalidAuthenticationTag: no retry', () {
      expect(v2FailureAllowsRetry(V2FailureCategory.invalidAuthenticationTag), false);
    });

    test('corruptedState: no retry', () {
      expect(v2FailureAllowsRetry(V2FailureCategory.corruptedState), false);
    });

    test('unsupportedVersion: no retry', () {
      expect(v2FailureAllowsRetry(V2FailureCategory.unsupportedVersion), false);
    });

    test('invalidBase64: no retry', () {
      expect(v2FailureAllowsRetry(V2FailureCategory.invalidBase64), false);
    });

    test('truncatedEnvelope: no retry', () {
      expect(v2FailureAllowsRetry(V2FailureCategory.truncatedEnvelope), false);
    });

    test('wrongDevice: no retry', () {
      expect(v2FailureAllowsRetry(V2FailureCategory.wrongDevice), false);
    });

    test('wrongSession: no retry', () {
      expect(v2FailureAllowsRetry(V2FailureCategory.wrongSession), false);
    });

    test('oversizedEnvelope: no retry', () {
      expect(v2FailureAllowsRetry(V2FailureCategory.oversizedEnvelope), false);
    });

    test('excessiveMessageNumberJump: no retry', () {
      expect(v2FailureAllowsRetry(V2FailureCategory.excessiveMessageNumberJump), false);
    });
  });

  // ===========================================================================
  // 3. STATE SAFETY
  // ===========================================================================

  group('v2FailureAdvancesState', () {
    test('persistenceFailure: state advanced (decrypt succeeded)', () {
      expect(v2FailureAdvancesState(V2FailureCategory.persistenceFailure), true);
    });

    test('invalidAuthenticationTag: state NOT advanced', () {
      expect(v2FailureAdvancesState(V2FailureCategory.invalidAuthenticationTag), false);
    });

    test('missingSession: state NOT advanced', () {
      expect(v2FailureAdvancesState(V2FailureCategory.missingSession), false);
    });

    test('corruptedState: state NOT advanced', () {
      expect(v2FailureAdvancesState(V2FailureCategory.corruptedState), false);
    });

    test('wrongDevice: state NOT advanced', () {
      expect(v2FailureAdvancesState(V2FailureCategory.wrongDevice), false);
    });

    test('unsupportedVersion: state NOT advanced', () {
      expect(v2FailureAdvancesState(V2FailureCategory.unsupportedVersion), false);
    });
  });

  // ===========================================================================
  // 4. NO FALLBACK
  // ===========================================================================

  group('No fallback — V2 failure stays V2', () {
    test('V2 failure never becomes plaintext', () {
      for (final category in V2FailureCategory.values) {
        final state = v2FailureToState(category);
        expect(
          state,
          isNot(MessageEncryptionState.plaintext),
          reason: '$category should not map to plaintext',
        );
      }
    });

    test('V2 failure never becomes V1', () {
      for (final category in V2FailureCategory.values) {
        final state = v2FailureToState(category);
        expect(
          state,
          isNot(MessageEncryptionState.encryptedV1),
          reason: '$category should not map to V1',
        );
      }
    });

    test('V2 failure never becomes encryptedV2 (except persistenceFailure)', () {
      for (final category in V2FailureCategory.values) {
        final state = v2FailureToState(category);
        if (category == V2FailureCategory.persistenceFailure) {
          // Persistence failure legitimately maps to encryptedV2
          // because decrypt succeeded — the message IS decrypted.
          expect(state, MessageEncryptionState.encryptedV2);
        } else {
          expect(
            state,
            isNot(MessageEncryptionState.encryptedV2),
            reason: '$category should not map to encryptedV2',
          );
        }
      }
    });
  });

  // ===========================================================================
  // 5. DOS LIMITS
  // ===========================================================================

  group('DoS limits — constants', () {
    test('v2MaxSkippedKeys is reasonable', () {
      expect(v2MaxSkippedKeys, greaterThanOrEqualTo(100));
      expect(v2MaxSkippedKeys, lessThanOrEqualTo(10000));
    });

    test('v2MaxMessageNumberJump is reasonable', () {
      expect(v2MaxMessageNumberJump, greaterThanOrEqualTo(100));
      expect(v2MaxMessageNumberJump, lessThanOrEqualTo(100000));
    });

    test('v2MaxPreviousChainLength is reasonable', () {
      expect(v2MaxPreviousChainLength, greaterThanOrEqualTo(100));
      expect(v2MaxPreviousChainLength, lessThanOrEqualTo(100000));
    });
  });

  // ===========================================================================
  // 6. ERROR ABSTRACTION — no raw exceptions leak
  // ===========================================================================

  group('Error abstraction — UI sees safe strings', () {
    test('all states map to non-empty or empty string (no null)', () {
      for (final state in MessageEncryptionState.values) {
        final text = encryptionStateToDisplayText(state);
        expect(text, isA<String>());
      }
    });

    test('no state exposes crypto internals', () {
      for (final state in MessageEncryptionState.values) {
        final text = encryptionStateToDisplayText(state);
        expect(text, isNot(contains('key')));
        expect(text, isNot(contains('session')));
        expect(text, isNot(contains('root')));
        expect(text, isNot(contains('chain')));
        expect(text, isNot(contains('private')));
        expect(text, isNot(contains('secret')));
      }
    });
  });

  // ===========================================================================
  // 7. UI STATE COMPLETENESS
  // ===========================================================================

  group('UI state completeness', () {
    test('every failure category maps to a valid state', () {
      for (final category in V2FailureCategory.values) {
        final state = v2FailureToState(category);
        expect(
          MessageEncryptionState.values.contains(state),
          true,
          reason: '$category maps to invalid state $state',
        );
      }
    });

    test('every state has a display text', () {
      for (final state in MessageEncryptionState.values) {
        final text = encryptionStateToDisplayText(state);
        expect(text, isA<String>());
      }
    });
  });

  // ===========================================================================
  // 8. V2RatchetException — no plaintext leak
  // ===========================================================================

  group('V2RatchetException — no plaintext', () {
    test('exception message does not contain plaintext', () {
      const ex = V2RatchetException('Decrypt failed: tag mismatch');
      expect(ex.message, isNot(contains('Hello')));
      expect(ex.message, isNot(contains('secret')));
    });

    test('exception toString does not leak keys', () {
      const ex = V2RatchetException('No receiving chain key');
      expect(ex.toString(), contains('V2RatchetException'));
      expect(ex.toString(), isNot(contains('0x')));
    });
  });

  // ===========================================================================
  // 9. EDIT/FORWARD BLOCKED FOR V2
  // ===========================================================================

  group('Edit/Forward blocked for V2', () {
    test('canEditMessage returns false for encryptedV2', () {
      expect(canEditMessage(MessageEncryptionState.encryptedV2), false);
    });

    test('canForwardMessage returns false for encryptedV2', () {
      expect(canForwardMessage(MessageEncryptionState.encryptedV2), false);
    });

    test('canEditMessage returns true for plaintext', () {
      expect(canEditMessage(MessageEncryptionState.plaintext), true);
    });

    test('canForwardMessage returns true for V1', () {
      expect(canForwardMessage(MessageEncryptionState.encryptedV1), true);
    });
  });
}
