import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/message_encryption_state.dart';
import 'package:vibe_app/data/v2_message_storage.dart';

void main() {
  // ===========================================================================
  // 1. ROUTING MATRIX
  // ===========================================================================

  group('resolveMessageEncryptionState — routing matrix', () {
    test('plaintext: is_encrypted=false', () {
      final row = {
        'is_encrypted': false,
        'e2ee_version': null,
        'text': 'Hello',
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.plaintext);
    });

    test('plaintext: is_encrypted absent', () {
      final row = <String, dynamic>{
        'text': 'Hello',
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.plaintext);
    });

    test('V1: is_encrypted=true, e2ee_version=null', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': null,
        'encrypted_content': '{}',
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV1);
    });

    test('V1: is_encrypted=true, e2ee_version=1', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 1,
        'encrypted_content': '{}',
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV1);
    });

    test('V2: is_encrypted=true, e2ee_version=2, valid content', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==', // valid base64
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV2);
    });

    test('V2 unavailable: e2ee_version=2, encrypted_content=null', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': null,
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV2Unavailable);
    });

    test('V2 unavailable: e2ee_version=2, encrypted_content=empty', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': '',
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV2Unavailable);
    });

    test('V2 unavailable: e2ee_version=2, encrypted_content absent', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV2Unavailable);
    });

    test('unsupported: e2ee_version=3 (future)', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 3,
        'encrypted_content': 'data',
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.unsupportedVersion);
    });

    test('unsupported: e2ee_version=99 (far future)', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 99,
        'encrypted_content': 'data',
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.unsupportedVersion);
    });

    test('unsupported: e2ee_version=0 (invalid)', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 0,
        'encrypted_content': 'data',
      };
      // 0 is not null, not 1, not 2 — falls to unsupported
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.unsupportedVersion);
    });

    test('unsupported: e2ee_version=-1 (invalid)', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': -1,
        'encrypted_content': 'data',
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.unsupportedVersion);
    });

    test('unsupported: e2ee_version="abc" (invalid type)', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 'abc',
        'encrypted_content': 'data',
      };
      // 'abc' != null, != 1, != 2 — falls to unsupported
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.unsupportedVersion);
    });
  });

  // ===========================================================================
  // 2. CONSISTENCY: same row → same state
  // ===========================================================================

  group('Consistency — same row, same state', () {
    test('realtime row and history row produce same state', () {
      // Simulates the same database row arriving via two paths
      final row = {
        'id': 'msg-1',
        'chat_id': 'chat-1',
        'sender_id': 'user-1',
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
        'text': null,
        'created_at': '2025-01-01T00:00:00Z',
      };

      final broadcastState = resolveMessageEncryptionState(row);
      final historyState = resolveMessageEncryptionState(Map<String, dynamic>.from(row));

      expect(broadcastState, equals(historyState));
      expect(broadcastState, MessageEncryptionState.encryptedV2);
    });

    test('V1 row is consistent across calls', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 1,
        'encrypted_content': '{"ct":"x"}',
      };

      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV1);
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV1);
    });
  });

  // ===========================================================================
  // 3. UI MAPPING
  // ===========================================================================

  group('encryptionStateToDisplayText — UI mapping', () {
    test('plaintext returns empty', () {
      expect(encryptionStateToDisplayText(MessageEncryptionState.plaintext), '');
    });

    test('encryptedV1 returns [зашифровано]', () {
      expect(encryptionStateToDisplayText(MessageEncryptionState.encryptedV1), '[зашифровано]');
    });

    test('encryptedV2 returns empty (caller decrypts)', () {
      expect(encryptionStateToDisplayText(MessageEncryptionState.encryptedV2), '');
    });

    test('encryptedV2Unavailable returns safe placeholder', () {
      expect(
        encryptionStateToDisplayText(MessageEncryptionState.encryptedV2Unavailable),
        'Зашифрованное сообщение недоступно',
      );
    });

    test('encryptedV2Failed returns safe placeholder', () {
      expect(
        encryptionStateToDisplayText(MessageEncryptionState.encryptedV2Failed),
        'Не удалось расшифровать сообщение',
      );
    });

    test('unsupportedVersion returns safe placeholder', () {
      expect(
        encryptionStateToDisplayText(MessageEncryptionState.unsupportedVersion),
        'Неподдерживаемая версия шифрования',
      );
    });
  });

  // ===========================================================================
  // 4. V1 COMPATIBILITY
  // ===========================================================================

  group('V1 compatibility', () {
    test('existing V1 rows resolve correctly (null version)', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': null,
        'encrypted_content': '{"ct":"x"}',
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV1);
    });

    test('existing V1 rows resolve correctly (version=1)', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 1,
        'encrypted_content': '{"ct":"x"}',
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV1);
    });

    test('V1 with missing content still resolves as V1 (not unavailable)', () {
      // V1 doesn't check encrypted_content presence — that's V2's concern
      final row = {
        'is_encrypted': true,
        'e2ee_version': 1,
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV1);
    });
  });

  // ===========================================================================
  // 5. NO FALLBACK
  // ===========================================================================

  group('No fallback — V2 failure stays V2', () {
    test('V2 unavailable does not become V1', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': null,
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.encryptedV2Unavailable);
      expect(state, isNot(MessageEncryptionState.encryptedV1));
    });

    test('unsupported version does not become V2', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 3,
        'encrypted_content': 'data',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, MessageEncryptionState.unsupportedVersion);
      expect(state, isNot(MessageEncryptionState.encryptedV2));
    });

    test('unsupported version does not become plaintext', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 3,
        'encrypted_content': 'data',
      };
      final state = resolveMessageEncryptionState(row);
      expect(state, isNot(MessageEncryptionState.plaintext));
    });
  });

  // ===========================================================================
  // 6. PURE RESOLVER — no side effects
  // ===========================================================================

  group('Pure resolver — no ratchet mutation', () {
    test('calling resolver multiple times returns same result', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
      };

      final s1 = resolveMessageEncryptionState(row);
      final s2 = resolveMessageEncryptionState(row);
      final s3 = resolveMessageEncryptionState(row);

      expect(s1, s2);
      expect(s2, s3);
    });

    test('resolver does not modify input row', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
      };
      final original = Map<String, dynamic>.from(row);

      resolveMessageEncryptionState(row);

      expect(row, equals(original));
    });
  });

  // ===========================================================================
  // 7. CAN EDIT / CAN FORWARD
  // ===========================================================================

  group('canEditMessage / canForwardMessage', () {
    test('plaintext: can edit and forward', () {
      expect(canEditMessage(MessageEncryptionState.plaintext), true);
      expect(canForwardMessage(MessageEncryptionState.plaintext), true);
    });

    test('V1: can edit and forward', () {
      expect(canEditMessage(MessageEncryptionState.encryptedV1), true);
      expect(canForwardMessage(MessageEncryptionState.encryptedV1), true);
    });

    test('V2: cannot edit or forward', () {
      expect(canEditMessage(MessageEncryptionState.encryptedV2), false);
      expect(canForwardMessage(MessageEncryptionState.encryptedV2), false);
    });

    test('V2 unavailable: cannot edit or forward', () {
      expect(canEditMessage(MessageEncryptionState.encryptedV2Unavailable), false);
      expect(canForwardMessage(MessageEncryptionState.encryptedV2Unavailable), false);
    });

    test('unsupported: cannot edit or forward', () {
      expect(canEditMessage(MessageEncryptionState.unsupportedVersion), false);
      expect(canForwardMessage(MessageEncryptionState.unsupportedVersion), false);
    });
  });

  // ===========================================================================
  // 8. V2StoredMessage helpers still work
  // ===========================================================================

  group('V2StoredMessage helpers — backward compatibility', () {
    test('isV2Message matches encryptedV2 state', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'data',
      };
      expect(V2StoredMessage.isV2Message(row), true);
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV2);
    });

    test('isV1Message matches encryptedV1 state', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 1,
        'encrypted_content': 'data',
      };
      expect(V2StoredMessage.isV1Message(row), true);
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV1);
    });

    test('isPlaintextMessage matches plaintext state', () {
      final row = {
        'is_encrypted': false,
        'text': 'Hello',
      };
      expect(V2StoredMessage.isPlaintextMessage(row), true);
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.plaintext);
    });
  });
}
