import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/message_encryption_state.dart';

void main() {
  // ===========================================================================
  // 1. RESOLVER — NO V2→V1 FALLBACK
  // ===========================================================================

  group('Resolver — V2 rows never resolve to V1', () {
    test('V2 row with valid ciphertext → encryptedV2, not V1', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.encryptedV2);
      expect(state, isNot(MessageEncryptionState.encryptedV1));
    });

    test('V2 row with missing ciphertext → encryptedV2Unavailable, not V1', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': null,
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.encryptedV2Unavailable);
      expect(state, isNot(MessageEncryptionState.encryptedV1));
    });

    test('V2 row with empty ciphertext → encryptedV2Unavailable, not V1', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': '',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.encryptedV2Unavailable);
      expect(state, isNot(MessageEncryptionState.encryptedV1));
    });

    test('V2 row without ciphertext field → encryptedV2Unavailable, not V1', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.encryptedV2Unavailable);
      expect(state, isNot(MessageEncryptionState.encryptedV1));
    });
  });

  // ===========================================================================
  // 2. RESOLVER — NO V2→PLAINTEXT FALLBACK
  // ===========================================================================

  group('Resolver — V2 rows never resolve to plaintext', () {
    test('V2 row with valid ciphertext → encryptedV2, not plaintext', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
        'text': 'Hello',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.encryptedV2);
      expect(state, isNot(MessageEncryptionState.plaintext));
    });

    test('V2 row with text field still resolves to encryptedV2', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
        'text': 'This is a secret',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.encryptedV2);
    });

    test('V2 row with missing ciphertext never becomes plaintext', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'text': 'Fallback attempt',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.encryptedV2Unavailable);
      expect(state, isNot(MessageEncryptionState.plaintext));
    });
  });

  // ===========================================================================
  // 3. RESOLVER — V1 ROWS STAY V1 (NO CROSS-PROTOCOL)
  // ===========================================================================

  group('Resolver — V1 rows never resolve to V2 or plaintext', () {
    test('V1 row with null version → encryptedV1', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': null,
        'encrypted_content': '{}',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.encryptedV1);
      expect(state, isNot(MessageEncryptionState.encryptedV2));
      expect(state, isNot(MessageEncryptionState.plaintext));
    });

    test('V1 row with version=1 → encryptedV1', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 1,
        'encrypted_content': '{}',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.encryptedV1);
    });

    test('Plaintext row stays plaintext, not V1 or V2', () {
      final row = {
        'is_encrypted': false,
        'text': 'Hello',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.plaintext);
      expect(state, isNot(MessageEncryptionState.encryptedV1));
      expect(state, isNot(MessageEncryptionState.encryptedV2));
    });
  });

  // ===========================================================================
  // 4. RESOLVER — UNSUPPORTED VERSION ISolATED
  // ===========================================================================

  group('Resolver — unsupported version never falls back', () {
    test('e2ee_version=3 → unsupportedVersion', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 3,
        'encrypted_content': 'dGVzdA==',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.unsupportedVersion);
    });

    test('e2ee_version=99 → unsupportedVersion', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 99,
        'encrypted_content': 'dGVzdA==',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.unsupportedVersion);
    });

    test('unsupportedVersion never becomes V1 or plaintext', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 5,
        'encrypted_content': 'dGVzdA==',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, isNot(MessageEncryptionState.encryptedV1));
      expect(state, isNot(MessageEncryptionState.plaintext));
      expect(state, isNot(MessageEncryptionState.encryptedV2));
    });
  });

  // ===========================================================================
  // 5. FAILURE CATEGORY → STATE MAPPING (NO V1/PLAINTEXT LEAK)
  // ===========================================================================

  group('v2FailureToState — every failure maps to V2 or unsupported state', () {
    final allV2Failures = [
      V2FailureCategory.missingSession,
      V2FailureCategory.missingCiphertext,
      V2FailureCategory.invalidBase64,
      V2FailureCategory.truncatedEnvelope,
      V2FailureCategory.unsupportedVersion,
      V2FailureCategory.invalidProtocolVersion,
      V2FailureCategory.invalidSenderIdentity,
      V2FailureCategory.wrongDevice,
      V2FailureCategory.wrongSession,
      V2FailureCategory.invalidAuthenticationTag,
      V2FailureCategory.corruptedState,
      V2FailureCategory.persistenceFailure,
      V2FailureCategory.unsupportedEncryptedOperation,
      V2FailureCategory.oversizedEnvelope,
      V2FailureCategory.excessiveMessageNumberJump,
      V2FailureCategory.excessivePreviousChainLength,
      V2FailureCategory.skippedKeyLimitExceeded,
    ];

    for (final failure in allV2Failures) {
      test('$failure → never V1', () {
        final state = v2FailureToState(failure);
        expect(state, isNot(MessageEncryptionState.encryptedV1));
      });

      test('$failure → never plaintext', () {
        final state = v2FailureToState(failure);
        expect(state, isNot(MessageEncryptionState.plaintext));
      });
    }

    test('all failures → V2 state or unsupportedVersion', () {
      final validStates = {
        MessageEncryptionState.encryptedV2,
        MessageEncryptionState.encryptedV2Failed,
        MessageEncryptionState.encryptedV2Unavailable,
        MessageEncryptionState.unsupportedVersion,
      };
      for (final failure in allV2Failures) {
        final state = v2FailureToState(failure);
        expect(
          validStates.contains(state),
          isTrue,
          reason: '$failure maps to $state, expected V2 state',
        );
      }
    });
  });

  // ===========================================================================
  // 6. DISPLAY TEXT — V2 FAILURES NEVER SHOW PLAINTEXT
  // ===========================================================================

  group('encryptionStateToDisplayText — V2 failures never show plaintext', () {
    test('encryptedV2Failed → safe placeholder, not empty', () {
      final text = encryptionStateToDisplayText(
        MessageEncryptionState.encryptedV2Failed,
      );
      expect(text, isNotEmpty);
      expect(text, 'Не удалось расшифровать сообщение');
    });

    test('encryptedV2Unavailable → safe placeholder, not empty', () {
      final text = encryptionStateToDisplayText(
        MessageEncryptionState.encryptedV2Unavailable,
      );
      expect(text, isNotEmpty);
      expect(text, 'Зашифрованное сообщение недоступно');
    });

    test('unsupportedVersion → safe placeholder, not empty', () {
      final text = encryptionStateToDisplayText(
        MessageEncryptionState.unsupportedVersion,
      );
      expect(text, isNotEmpty);
      expect(text, 'Неподдерживаемая версия шифрования');
    });

    test('encryptedV2 → empty (caller provides decrypted text)', () {
      final text = encryptionStateToDisplayText(
        MessageEncryptionState.encryptedV2,
      );
      expect(text, isEmpty);
    });

    test('plaintext → empty (caller provides actual text)', () {
      final text = encryptionStateToDisplayText(
        MessageEncryptionState.plaintext,
      );
      expect(text, isEmpty);
    });

    test('encryptedV1 → placeholder', () {
      final text = encryptionStateToDisplayText(
        MessageEncryptionState.encryptedV1,
      );
      expect(text, '[зашифровано]');
    });
  });

  // ===========================================================================
  // 7. EDIT/FORWARD — V2 BLOCKED, V1/PLAINTEXT ALLOWED
  // ===========================================================================

  group('canEditMessage / canForwardMessage — V2 is always blocked', () {
    test('canEditMessage(encryptedV2) = false', () {
      expect(canEditMessage(MessageEncryptionState.encryptedV2), false);
    });

    test('canEditMessage(encryptedV2Failed) = false', () {
      expect(canEditMessage(MessageEncryptionState.encryptedV2Failed), false);
    });

    test('canEditMessage(encryptedV2Unavailable) = false', () {
      expect(canEditMessage(MessageEncryptionState.encryptedV2Unavailable), false);
    });

    test('canEditMessage(unsupportedVersion) = false', () {
      expect(canEditMessage(MessageEncryptionState.unsupportedVersion), false);
    });

    test('canEditMessage(plaintext) = true', () {
      expect(canEditMessage(MessageEncryptionState.plaintext), true);
    });

    test('canEditMessage(encryptedV1) = true', () {
      expect(canEditMessage(MessageEncryptionState.encryptedV1), true);
    });

    test('canForwardMessage(encryptedV2) = false', () {
      expect(canForwardMessage(MessageEncryptionState.encryptedV2), false);
    });

    test('canForwardMessage(encryptedV2Failed) = false', () {
      expect(canForwardMessage(MessageEncryptionState.encryptedV2Failed), false);
    });

    test('canForwardMessage(encryptedV2Unavailable) = false', () {
      expect(canForwardMessage(MessageEncryptionState.encryptedV2Unavailable), false);
    });

    test('canForwardMessage(unsupportedVersion) = false', () {
      expect(canForwardMessage(MessageEncryptionState.unsupportedVersion), false);
    });

    test('canForwardMessage(plaintext) = true', () {
      expect(canForwardMessage(MessageEncryptionState.plaintext), true);
    });

    test('canForwardMessage(encryptedV1) = true', () {
      expect(canForwardMessage(MessageEncryptionState.encryptedV1), true);
    });
  });

  // ===========================================================================
  // 8. SOURCE CODE AUDIT — NO FALLBACK PATTERNS
  // ===========================================================================

  group('Source code audit — no forbidden fallback patterns', () {
    test('v2FailureToState never returns V1', () {
      final allFailures = V2FailureCategory.values;
      for (final f in allFailures) {
        expect(
          v2FailureToState(f),
          isNot(MessageEncryptionState.encryptedV1),
          reason: 'v2FailureToState($f) must not return V1',
        );
      }
    });

    test('v2FailureToState never returns plaintext', () {
      final allFailures = V2FailureCategory.values;
      for (final f in allFailures) {
        expect(
          v2FailureToState(f),
          isNot(MessageEncryptionState.plaintext),
          reason: 'v2FailureToState($f) must not return plaintext',
        );
      }
    });

    test('v2FailureAdvancesState — only persistenceFailure returns true', () {
      final advanced = V2FailureCategory.values
          .where((f) => v2FailureAdvancesState(f))
          .toList();
      expect(advanced, [V2FailureCategory.persistenceFailure]);
    });

    test('v2FailureAllowsRetry — only persistenceFailure returns true', () {
      final retryable = V2FailureCategory.values
          .where((f) => v2FailureAllowsRetry(f))
          .toList();
      expect(retryable, [V2FailureCategory.persistenceFailure]);
    });
  });

  // ===========================================================================
  // 9. V1 COMPATIBILITY — V1 ROWS NEVER USE V2 PATH
  // ===========================================================================

  group('V1 compatibility — V1 rows never use V2 path', () {
    test('V1 row with null version → encryptedV1, not V2', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': null,
        'encrypted_content': '{}',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.encryptedV1);
      expect(state, isNot(MessageEncryptionState.encryptedV2));
      expect(state, isNot(MessageEncryptionState.encryptedV2Unavailable));
      expect(state, isNot(MessageEncryptionState.encryptedV2Failed));
    });

    test('V1 row with version=1 → encryptedV1, not V2', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 1,
        'encrypted_content': '{}',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.encryptedV1);
      expect(state, isNot(MessageEncryptionState.encryptedV2));
    });

    test('V1 row missing ciphertext stays V1 (not V2)', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 1,
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.encryptedV1);
    });
  });

  // ===========================================================================
  // 10. COMPLETENESS — ALL ENUM VALUES COVERED
  // ===========================================================================

  group('Completeness — all enum values have state mapping', () {
    test('all MessageEncryptionState values have display text', () {
      for (final state in MessageEncryptionState.values) {
        final text = encryptionStateToDisplayText(state);
        expect(text, isA<String>());
      }
    });

    test('all MessageEncryptionState values have edit/forward policy', () {
      for (final state in MessageEncryptionState.values) {
        canEditMessage(state);
        canForwardMessage(state);
      }
    });

    test('all V2FailureCategory values map to valid state', () {
      final validStates = {
        MessageEncryptionState.encryptedV2,
        MessageEncryptionState.encryptedV2Failed,
        MessageEncryptionState.encryptedV2Unavailable,
        MessageEncryptionState.unsupportedVersion,
      };
      for (final f in V2FailureCategory.values) {
        final state = v2FailureToState(f);
        expect(
          validStates.contains(state),
          isTrue,
          reason: '$f → $state (invalid)',
        );
      }
    });
  });
}
