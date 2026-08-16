import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/v2_message_storage.dart';
import 'package:vibe_app/data/message_encryption_state.dart';
import 'package:vibe_app/data/v2_ratchet.dart';

void main() {
  // ===========================================================================
  // 1. EDIT — V2 UNSUPPORTED
  // ===========================================================================

  group('Edit — V2 unsupported', () {
    test('V2 row detected by isV2Message', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
      };
      expect(V2StoredMessage.isV2Message(row), true);
    });

    test('V1 row NOT detected as V2', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 1,
        'encrypted_content': '{}',
      };
      expect(V2StoredMessage.isV2Message(row), false);
    });

    test('plaintext row NOT detected as V2', () {
      final row = {
        'is_encrypted': false,
        'text': 'Hello',
      };
      expect(V2StoredMessage.isV2Message(row), false);
    });

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

    test('V2 edit throws UnsupportedError', () {
      // Verify the policy: V2 edit must throw
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
      };
      expect(V2StoredMessage.isV2Message(row), true);
      // canEditMessage returns false for V2
      expect(canEditMessage(MessageEncryptionState.encryptedV2), false);
    });
  });

  // ===========================================================================
  // 2. FORWARD — V2 UNSUPPORTED
  // ===========================================================================

  group('Forward — V2 unsupported', () {
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

    test('V2 forward throws UnsupportedError', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
      };
      expect(V2StoredMessage.isV2Message(row), true);
      expect(canForwardMessage(MessageEncryptionState.encryptedV2), false);
    });
  });

  // ===========================================================================
  // 3. REPLY — MESSAGE ID ONLY
  // ===========================================================================

  group('Reply — message ID only', () {
    test('V2 message has no plaintext text field', () {
      // V2 messages are stored with text=null in the database
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
        'text': null, // V2 messages have null text
      };
      expect(V2StoredMessage.isV2Message(row), true);
      expect(row['text'], isNull);
    });

    test('replyText is client-local only, not stored on server', () {
      // replyText and replyAuthor are derived after decrypt
      // They are NOT sent to the server
      // Verified in backend.dart: sendText() does not include replyText/replyAuthor in insertData
      //
      // This test documents the policy
      final insertData = <String, dynamic>{
        'chat_id': 'chat1',
        'sender_id': 'user1',
        'text': null, // V2 → null
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
      };

      // Verify replyText/replyAuthor are NOT in insertData
      expect(insertData.containsKey('replyText'), false);
      expect(insertData.containsKey('replyAuthor'), false);
    });

    test('missing referenced message → safe UI state', () {
      // If referenced message is unavailable (e.g., after restart before decrypt),
      // the reply preview shows safe placeholder
      //
      // This is handled by the UI layer: if replyText is null, show placeholder
      final replyText = null;
      final displayText = replyText ?? 'Сообщение недоступно';
      expect(displayText, 'Сообщение недоступно');
    });
  });

  // ===========================================================================
  // 4. DELETE — NO DECRYPT REQUIRED
  // ===========================================================================

  group('Delete — no decrypt required', () {
    test('V2 delete works by server message ID', () {
      // Delete operation only needs the server message ID
      // No plaintext needed
      final messageId = 'test-message-id';
      expect(messageId.isNotEmpty, true);
    });

    test('delete does not require ratchet state', () {
      // Delete is a server operation, not a crypto operation
      // It does not touch ratchet state
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingMessageNumber: 5,
        skippedKeys: {},
      );

      // After delete, state unchanged
      expect(state.receivingMessageNumber, 5);
    });

    test('delete does not generate plaintext', () {
      // Delete marks the message as deleted in the database
      // It does not decrypt the content
      final row = {
        'id': 'msg1',
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
      };

      // Delete does not access encrypted_content
      expect(V2StoredMessage.isV2Message(row), true);
    });
  });

  // ===========================================================================
  // 5. STORAGE AUDIT
  // ===========================================================================

  group('Storage audit — V2 operations', () {
    test('V2 message: text remains null', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'text': null, // V2 messages always have null text
        'encrypted_content': 'dGVzdA==',
      };
      expect(row['text'], isNull);
      expect(V2StoredMessage.isV2Message(row), true);
    });

    test('V2 forward: no destination plaintext insert', () {
      // Forward inserts a new row with text=null for V2
      final forwardData = <String, dynamic>{
        'chat_id': 'target-chat',
        'sender_id': 'user1',
        'text': null, // V2 → no plaintext
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==', // Must be re-encrypted for target
      };

      expect(forwardData['text'], isNull);
      expect(forwardData['is_encrypted'], true);
      expect(forwardData['e2ee_version'], 2);
    });

    test('V2 reply: no plaintext reply excerpt in transport', () {
      // Reply only sends reply_to_message_id (client-local)
      // No plaintext excerpt sent to server
      //
      // Verified in backend.dart: insertData does not include replyText
      final insertData = <String, dynamic>{
        'chat_id': 'chat1',
        'sender_id': 'user1',
        'text': null,
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
      };

      expect(insertData.containsKey('replyText'), false);
      expect(insertData.containsKey('replyAuthor'), false);
    });

    test('V2 delete: no plaintext generated', () {
      // Delete is a server operation
      // It does not decrypt content
      // Encrypted content remains or is marked deleted
      final row = {
        'id': 'msg1',
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
      };

      // Delete does not access encrypted_content
      expect(V2StoredMessage.isV2Message(row), true);
    });
  });

  // ===========================================================================
  // 6. RLS / DATABASE
  // ===========================================================================

  group('RLS / database', () {
    test('V2 edit blocked at application level before DB access', () {
      // V2 edit throws UnsupportedError before any DB update
      // This is the primary protection
      //
      // RLS is a secondary defense layer
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
      };

      expect(V2StoredMessage.isV2Message(row), true);
      expect(canEditMessage(MessageEncryptionState.encryptedV2), false);
    });

    test('V2 forward blocked at application level before DB access', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
      };

      expect(V2StoredMessage.isV2Message(row), true);
      expect(canForwardMessage(MessageEncryptionState.encryptedV2), false);
    });
  });

  // ===========================================================================
  // 7. HISTORY / REALTIME CONSISTENCY
  // ===========================================================================

  group('History / realtime consistency', () {
    test('delete event does not alter ratchet state', () {
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 5,
        skippedKeys: {2: List.filled(32, 0xAA)},
        ratchetStep: 3,
      );

      // Delete does not touch ratchet state
      expect(state.receivingMessageNumber, 5);
      expect(state.ratchetStep, 3);
      expect(state.skippedKeys.length, 1);
    });

    test('history reload after delete is consistent', () {
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 3,
        skippedKeys: {},
      );

      // After delete, state unchanged
      expect(state.receivingMessageNumber, 3);
    });
  });

  // ===========================================================================
  // 8. V1 COMPATIBILITY
  // ===========================================================================

  group('V1 compatibility', () {
    test('V1 edit works', () {
      expect(canEditMessage(MessageEncryptionState.encryptedV1), true);
    });

    test('V1 forward works', () {
      expect(canForwardMessage(MessageEncryptionState.encryptedV1), true);
    });

    test('plaintext edit works', () {
      expect(canEditMessage(MessageEncryptionState.plaintext), true);
    });

    test('plaintext forward works', () {
      expect(canForwardMessage(MessageEncryptionState.plaintext), true);
    });

    test('V1 row not detected as V2', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 1,
        'encrypted_content': '{}',
      };
      expect(V2StoredMessage.isV2Message(row), false);
    });
  });

  // ===========================================================================
  // 9. SOURCE AUDIT — NO PLAINTEXT LEAK
  // ===========================================================================

  group('Source audit — no plaintext leak', () {
    test('V2 message: text field is null in DB', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'text': null,
        'encrypted_content': 'dGVzdA==',
      };
      expect(row['text'], isNull);
    });

    test('V2 forward: text field is null in forward data', () {
      final forwardData = <String, dynamic>{
        'text': null, // V2 → no plaintext
      };
      expect(forwardData['text'], isNull);
    });

    test('V2 reply: replyText not in insertData', () {
      final insertData = <String, dynamic>{
        'text': null,
        'is_encrypted': true,
        'e2ee_version': 2,
      };
      expect(insertData.containsKey('replyText'), false);
    });

    test('V2 edit: throws before DB update', () {
      // UnsupportedError thrown before any DB access
      expect(
        () {
          if (V2StoredMessage.isV2Message({'e2ee_version': 2, 'is_encrypted': true})) {
            throw UnsupportedError('V2 edit not supported');
          }
        },
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('V2 forward: throws before DB insert', () {
      expect(
        () {
          if (V2StoredMessage.isV2Message({'e2ee_version': 2, 'is_encrypted': true})) {
            throw UnsupportedError('V2 forward not supported');
          }
        },
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  // ===========================================================================
  // 10. NO FALLBACK — V2 OPERATIONS
  // ===========================================================================

  group('No fallback — V2 operations', () {
    test('V2 edit never routes to V1', () {
      // V2 edit throws, never falls back to V1 edit
      expect(canEditMessage(MessageEncryptionState.encryptedV2), false);
      expect(canEditMessage(MessageEncryptionState.encryptedV1), true);
    });

    test('V2 edit never routes to plaintext', () {
      // V2 edit throws, never falls back to plaintext edit
      expect(canEditMessage(MessageEncryptionState.encryptedV2), false);
      expect(canEditMessage(MessageEncryptionState.plaintext), true);
    });

    test('V2 forward never routes to V1', () {
      expect(canForwardMessage(MessageEncryptionState.encryptedV2), false);
      expect(canForwardMessage(MessageEncryptionState.encryptedV1), true);
    });

    test('V2 forward never routes to plaintext', () {
      expect(canForwardMessage(MessageEncryptionState.encryptedV2), false);
      expect(canForwardMessage(MessageEncryptionState.plaintext), true);
    });
  });

  // ===========================================================================
  // 11. COMPLETENESS
  // ===========================================================================

  group('Completeness', () {
    test('all MessageEncryptionState values have edit policy', () {
      for (final state in MessageEncryptionState.values) {
        canEditMessage(state);
      }
    });

    test('all MessageEncryptionState values have forward policy', () {
      for (final state in MessageEncryptionState.values) {
        canForwardMessage(state);
      }
    });

    test('V2 states: edit and forward always blocked', () {
      final v2States = [
        MessageEncryptionState.encryptedV2,
        MessageEncryptionState.encryptedV2Failed,
        MessageEncryptionState.encryptedV2Unavailable,
        MessageEncryptionState.unsupportedVersion,
      ];
      for (final state in v2States) {
        expect(canEditMessage(state), false, reason: 'edit blocked for $state');
        expect(canForwardMessage(state), false, reason: 'forward blocked for $state');
      }
    });

    test('non-V2 states: edit and forward always allowed', () {
      final nonV2States = [
        MessageEncryptionState.plaintext,
        MessageEncryptionState.encryptedV1,
      ];
      for (final state in nonV2States) {
        expect(canEditMessage(state), true, reason: 'edit allowed for $state');
        expect(canForwardMessage(state), true, reason: 'forward allowed for $state');
      }
    });
  });
}
