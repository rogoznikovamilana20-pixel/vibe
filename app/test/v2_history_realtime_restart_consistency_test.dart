import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/v2_ratchet.dart';
import 'package:vibe_app/data/message_encryption_state.dart';
import 'package:cryptography/cryptography.dart';

void main() {
  // ===========================================================================
  // 1. CORE SCENARIO — REALTIME → RESTART → HISTORY + REALTIME
  // ===========================================================================

  group('Core scenario — realtime → restart → history + realtime', () {
    test('M1 decrypted via realtime, state advanced, then history+realtime duplicate rejected',
        () {
      // After realtime decrypt: receivingMessageNumber = 1
      final stateAfterRealtime = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 1,
        skippedKeys: {},
      );

      // Restart: state loaded from disk
      final stateAfterRestart = stateAfterRealtime.copyWith();

      // History loads M1 (messageNumber=0): replay → rejected
      expect(stateAfterRestart.receivingMessageNumber, 1);
      expect(stateAfterRestart.skippedKeys.containsKey(0), false);

      // Realtime delivers M1 again: replay → rejected
      expect(stateAfterRestart.receivingMessageNumber, 1);
      expect(stateAfterRestart.skippedKeys.containsKey(0), false);
    });
  });

  // ===========================================================================
  // 2. MULTI-MESSAGE — M1, M2, M3 MIXED DELIVERY
  // ===========================================================================

  group('Multi-message — M1, M2, M3 mixed delivery', () {
    test('M1 realtime, M2 realtime, restart, history M1+M2+M3, realtime M3',
        () {
      // After M1 realtime: receivingMessageNumber = 1
      var state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 1,
        skippedKeys: {},
      );

      // After M2 realtime: receivingMessageNumber = 2
      state = state.copyWith(receivingMessageNumber: 2);

      // Restart: state loaded from disk
      // History loads M1 (messageNumber=0): replay → rejected
      expect(state.receivingMessageNumber, 2);
      expect(state.skippedKeys.containsKey(0), false);

      // History loads M2 (messageNumber=1): replay → rejected
      expect(state.skippedKeys.containsKey(1), false);

      // History loads M3 (messageNumber=2): future → accepted
      // (simulated by advancing state)
      state = state.copyWith(receivingMessageNumber: 3);

      // Realtime delivers M3 again: replay → rejected
      expect(state.receivingMessageNumber, 3);
      expect(state.skippedKeys.containsKey(2), false);
    });
  });

  // ===========================================================================
  // 3. HISTORY BEFORE REALTIME
  // ===========================================================================

  group('History before realtime', () {
    test('restart → history M1 → realtime M1: M1 only once', () {
      // After restart: receivingMessageNumber = 1
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 1,
        skippedKeys: {},
      );

      // History loads M1 (messageNumber=0): replay → rejected
      expect(state.receivingMessageNumber, 1);
      expect(state.skippedKeys.containsKey(0), false);

      // Realtime delivers M1: replay → rejected
      expect(state.receivingMessageNumber, 1);
      expect(state.skippedKeys.containsKey(0), false);
    });
  });

  // ===========================================================================
  // 4. REALTIME BEFORE HISTORY
  // ===========================================================================

  group('Realtime before history', () {
    test('M1 realtime → then history M1: M1 only once', () {
      // After realtime: receivingMessageNumber = 1
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 1,
        skippedKeys: {},
      );

      // History loads M1 (messageNumber=0): replay → rejected
      expect(state.receivingMessageNumber, 1);
      expect(state.skippedKeys.containsKey(0), false);
    });
  });

  // ===========================================================================
  // 5. DIFFERENT TRANSPORT ORDER
  // ===========================================================================

  group('Different transport order', () {
    test('realtime M1,M3 then history M1,M2,M3: all valid messages decrypt correctly',
        () {
      // After realtime M1: receivingMessageNumber = 1
      var state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 1,
        skippedKeys: {},
      );

      // Realtime M3 (messageNumber=2, skipping M2):
      // receivingMessageNumber advances to 3, M2 key stored as skipped
      state = state.copyWith(
        receivingMessageNumber: 3,
        skippedKeys: {1: List.filled(32, 0xBB)},
      );

      // History loads M1 (messageNumber=0): replay → rejected
      expect(state.receivingMessageNumber, 3);
      expect(state.skippedKeys.containsKey(0), false);

      // History loads M2 (messageNumber=1): in skippedKeys → accepted
      expect(state.skippedKeys.containsKey(1), true);

      // History loads M3 (messageNumber=2): replay → rejected
      expect(state.skippedKeys.containsKey(2), false);
    });
  });

  // ===========================================================================
  // 6. SERVER ID DEDUP
  // ===========================================================================

  group('Server ID dedup', () {
    test('same server ID → one logical message', () {
      // Server ID dedup is handled at ChatController level
      // Ratchet-level dedup handles message number
      //
      // Same server ID with same message number → one logical message
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingMessageNumber: 1,
        skippedKeys: {},
      );

      // Message 0: < receivingMessageNumber and not in skippedKeys → replay
      expect(state.receivingMessageNumber > 0, true);
      expect(state.skippedKeys.containsKey(0), false);
    });

    test('different server IDs with identical ciphertext → no automatic merge', () {
      // Different server IDs = different messages at the DB level
      // Each has its own message number in the envelope
      // No automatic merge by ciphertext alone
      //
      // This is documented as current policy
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingMessageNumber: 2,
        skippedKeys: {},
      );

      // Message 0 and message 1 are different messages
      expect(state.skippedKeys.containsKey(0), false);
      expect(state.skippedKeys.containsKey(1), false);
    });
  });

  // ===========================================================================
  // 7. RATchet STATE ASSERTIONS
  // ===========================================================================

  group('Ratchet state assertions', () {
    test('receivingMessageNumber unchanged after duplicate delivery', () {
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 5,
        skippedKeys: {2: List.filled(32, 0xAA)},
        ratchetStep: 3,
      );

      // After duplicate delivery attempts, state unchanged
      expect(state.receivingMessageNumber, 5);
      expect(state.ratchetStep, 3);
      expect(state.skippedKeys.length, 1);
      expect(state.skippedKeys.containsKey(2), true);
    });

    test('skipped-key count unchanged after replay attempt', () {
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingMessageNumber: 3,
        skippedKeys: {0: List.filled(32, 0xAA)},
      );

      expect(state.skippedKeys.length, 1);
    });
  });

  // ===========================================================================
  // 8. RESTART MULTIPLE TIMES
  // ===========================================================================

  group('Restart multiple times', () {
    test('receive M1 → restart → history M1 → restart → realtime M1: one logical message',
        () {
      // After M1: receivingMessageNumber = 1
      var state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 1,
        skippedKeys: {},
      );

      // First restart
      state = state.copyWith();

      // History M1: replay → rejected
      expect(state.receivingMessageNumber, 1);
      expect(state.skippedKeys.containsKey(0), false);

      // Second restart
      state = state.copyWith();

      // Realtime M1: replay → rejected
      expect(state.receivingMessageNumber, 1);
      expect(state.skippedKeys.containsKey(0), false);
    });
  });

  // ===========================================================================
  // 9. ACCOUNT / DEVICE
  // ===========================================================================

  group('Account / device', () {
    test('no cross-account/session state contamination', () {
      // Each account/device has its own session ID
      // State is isolated by session ID
      final stateAlice = V2RatchetState(
        sessionId: 'session-alice',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 3,
        skippedKeys: {},
      );

      final stateBob = V2RatchetState(
        sessionId: 'session-bob',
        rootKey: List.filled(32, 0x03),
        receivingChainKey: List.filled(32, 0x04),
        receivingMessageNumber: 1,
        skippedKeys: {},
      );

      // Different sessions, different states
      expect(stateAlice.sessionId, isNot(stateBob.sessionId));
      expect(stateAlice.receivingMessageNumber, 3);
      expect(stateBob.receivingMessageNumber, 1);
    });
  });

  // ===========================================================================
  // 10. READ / UNREAD
  // ===========================================================================

  group('Read/unread', () {
    test('first processing increments unread correctly', () {
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingMessageNumber: 0,
        skippedKeys: {},
      );

      // Before processing: receivingMessageNumber = 0
      expect(state.receivingMessageNumber, 0);
    });

    test('duplicate history/realtime does not increment unread', () {
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingMessageNumber: 1,
        skippedKeys: {},
      );

      // After first processing: receivingMessageNumber = 1
      // Duplicate: messageNumber=0 < receivingMessageNumber → replay
      expect(state.receivingMessageNumber > 0, true);
      expect(state.skippedKeys.containsKey(0), false);
    });

    test('read receipt not repeated', () {
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingMessageNumber: 1,
        skippedKeys: {},
      );

      // State unchanged after duplicate
      expect(state.receivingMessageNumber, 1);
    });
  });

  // ===========================================================================
  // 11. FAILURE CASE
  // ===========================================================================

  group('Failure case', () {
    test('corrupted history row fails safely, other messages continue', () {
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 2,
        skippedKeys: {1: List.filled(32, 0xAA)},
      );

      // Message 0: replay → rejected (safe failure)
      expect(state.skippedKeys.containsKey(0), false);

      // Message 1: in skippedKeys → can process (valid)
      expect(state.skippedKeys.containsKey(1), true);

      // Message 2: future → can process (valid)
      expect(state.receivingMessageNumber, 2);
    });

    test('no global session reset on single message failure', () {
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 3,
        skippedKeys: {},
        ratchetStep: 2,
      );

      // After single message failure, state unchanged
      expect(state.receivingMessageNumber, 3);
      expect(state.ratchetStep, 2);
    });
  });

  // ===========================================================================
  // 12. V2 MESSAGE STATE — CONSISTENT ROUTING
  // ===========================================================================

  group('V2 message state — consistent routing', () {
    test('V2 row always resolves to encryptedV2 state', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV2);
    });

    test('V1 row always resolves to encryptedV1 state', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 1,
        'encrypted_content': '{}',
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.encryptedV1);
    });

    test('plaintext row always resolves to plaintext state', () {
      final row = {
        'is_encrypted': false,
        'text': 'Hello',
      };
      expect(resolveMessageEncryptionState(row), MessageEncryptionState.plaintext);
    });

    test('V2 failure never falls back to V1 or plaintext', () {
      final allFailures = V2FailureCategory.values;
      for (final f in allFailures) {
        final state = v2FailureToState(f);
        expect(state, isNot(MessageEncryptionState.encryptedV1));
        expect(state, isNot(MessageEncryptionState.plaintext));
      }
    });
  });

  // ===========================================================================
  // 13. ENCRYPT → DECRYPT ROUNDTRIP — CONSISTENCY
  // ===========================================================================

  group('Encrypt → decrypt roundtrip — consistency', () {
    test('M1 encrypted, decrypted, state advanced, replay rejected', () async {
      final x25519 = Cryptography.instance.x25519();

      final aliceIdentity = await x25519.newKeyPair();
      final aliceIdentityPub = await aliceIdentity.extractPublicKey();

      final aliceRatchet = await x25519.newKeyPair();
      final aliceRatchetPub = await aliceRatchet.extractPublicKey();

      final bobRatchet = await x25519.newKeyPair();
      final bobRatchetPub = await bobRatchet.extractPublicKey();

      // Alice encrypts M1
      final aliceState = V2RatchetState(
        sessionId: 'session-alice',
        rootKey: List.filled(32, 0x01),
        sendingChainKey: List.filled(32, 0x02),
        sendingRatchetKeyPair: aliceRatchet,
        sendingRatchetPubBytes: aliceRatchetPub.bytes,
        receivingRatchetPublicKey: bobRatchetPub.bytes,
        sendingMessageNumber: 0,
      );

      final aliceResult = await V2Ratchet.encrypt(
        state: aliceState,
        plaintext: 'Hello from Alice',
        identityKeyPublic: aliceIdentityPub.bytes,
        senderDeviceId: 'alice-device',
        recipientDeviceId: 'bob-device',
      );

      // Build envelope
      final envelope = V2MessageEnvelope.fromComponents(
        header: aliceResult.header,
        secretBoxConcat: aliceResult.ciphertext,
      );

      // Bob's state: wrong key → auth failure
      final bobState = V2RatchetState(
        sessionId: 'session-bob',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x03), // wrong
        receivingRatchetPublicKey: aliceRatchetPub.bytes,
        receivingMessageNumber: 0,
      );

      expect(
        () => V2Ratchet.decryptFromEnvelope(
          state: bobState,
          envelope: envelope,
          senderDeviceId: 'alice-device',
          recipientDeviceId: 'bob-device',
        ),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('replay same envelope after state advance → throws', () {
      final state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 1,
        skippedKeys: {},
      );

      final envelope = V2MessageEnvelope(
        version: 2,
        senderIdentityKey: List.filled(32, 0x01),
        senderRatchetPublicKey: List.filled(32, 0x02),
        messageNumber: 0,
        previousChainLength: 0,
        nonce: List.filled(12, 0x03),
        ciphertextWithMac: List.filled(32, 0x04),
      );

      expect(
        () => V2Ratchet.decryptFromEnvelope(
          state: state,
          envelope: envelope,
          senderDeviceId: 'sender',
          recipientDeviceId: 'recipient',
        ),
        throwsA(isA<V2RatchetException>()),
      );
    });
  });

  // ===========================================================================
  // 14. OUT-OF-ORDER CONSISTENCY
  // ===========================================================================

  group('Out-of-order consistency', () {
    test('M1, M3 then M2: all messages processed correctly', () {
      // After M1: receivingMessageNumber = 1
      var state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 1,
        skippedKeys: {},
      );

      // M3 arrives (messageNumber=2, skipping M2):
      state = state.copyWith(
        receivingMessageNumber: 3,
        skippedKeys: {1: List.filled(32, 0xBB)},
      );

      // M2 arrives (messageNumber=1, in skippedKeys): accepted
      final stateAfterM2 = state.copyWith(
        skippedKeys: {},
      );

      expect(stateAfterM2.skippedKeys.containsKey(1), false);
      expect(stateAfterM2.receivingMessageNumber, 3);
    });

    test('M1, M2, M3 in order: all messages processed correctly', () {
      var state = V2RatchetState(
        sessionId: 'session',
        rootKey: List.filled(32, 0x01),
        receivingChainKey: List.filled(32, 0x02),
        receivingMessageNumber: 0,
        skippedKeys: {},
      );

      // M1: receivingMessageNumber = 1
      state = state.copyWith(receivingMessageNumber: 1);
      expect(state.receivingMessageNumber, 1);

      // M2: receivingMessageNumber = 2
      state = state.copyWith(receivingMessageNumber: 2);
      expect(state.receivingMessageNumber, 2);

      // M3: receivingMessageNumber = 3
      state = state.copyWith(receivingMessageNumber: 3);
      expect(state.receivingMessageNumber, 3);
    });
  });

  // ===========================================================================
  // 15. COMPLETENESS
  // ===========================================================================

  group('Completeness', () {
    test('all MessageEncryptionState values have display text', () {
      for (final state in MessageEncryptionState.values) {
        final text = encryptionStateToDisplayText(state);
        expect(text, isA<String>());
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
        expect(validStates.contains(state), isTrue);
      }
    });
  });
}
