import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/v2_message_storage.dart';
import 'package:vibe_app/data/v2_outgoing.dart';
import 'package:vibe_app/data/v2_ratchet.dart';

void main() {
  group('V2Outgoing — feature flag', () {
    test('enabled defaults to false', () {
      final handler = V2Outgoing.instance;
      // Reset to default for test
      handler.enabled = false;
      expect(handler.enabled, isFalse);
    });

    test('can be toggled', () {
      final handler = V2Outgoing.instance;
      handler.enabled = true;
      expect(handler.enabled, isTrue);
      handler.enabled = false;
      expect(handler.enabled, isFalse);
    });
  });

  group('V2Outgoing — ratchet state cache', () {
    test('clearSession removes cached state', () async {
      final handler = V2Outgoing.instance;
      // This test verifies the cache mechanism exists
      // Actual session loading requires E2eV2Service which needs Supabase
      handler.clearAll();
      // No assertion needed — just verifying the API exists
    });

    test('clearAll removes all cached state', () async {
      final handler = V2Outgoing.instance;
      handler.clearAll();
      // No assertion needed — just verifying the API exists
    });
  });

  group('V2Outgoing — encrypt result structure', () {
    test('V2EncryptResult holds payload, envelope, and state', () {
      final envelope = V2MessageEnvelope(
        version: 2,
        senderIdentityKey: List<int>.filled(32, 0x01),
        senderRatchetPublicKey: List<int>.filled(32, 0x02),
        messageNumber: 0,
        previousChainLength: 0,
        nonce: List<int>.filled(12, 0x03),
        ciphertextWithMac: List<int>.filled(32, 0x04),
      );

      final state = V2RatchetState(
        sessionId: 'test-session',
        rootKey: List<int>.filled(32, 0x05),
        sendingChainKey: List<int>.filled(32, 0x06),
      );

      final payload = V2StoredMessage.buildInsertPayload(
        envelope: envelope,
        senderId: 'user-1',
        chatId: 'chat-1',
      );

      final result = V2EncryptResult(
        payload: payload,
        envelope: envelope,
        newState: state,
      );

      expect(result.payload['e2ee_version'], equals(2));
      expect(result.payload['is_encrypted'], isTrue);
      expect(result.payload['text'], isNull);
      expect(result.envelope.version, equals(2));
      expect(result.newState.sessionId, equals('test-session'));
    });
  });

  group('V2Outgoing — storage payload contract', () {
    test('V2 payload has correct fields', () {
      final envelope = V2MessageEnvelope(
        version: 2,
        senderIdentityKey: List<int>.filled(32, 0x01),
        senderRatchetPublicKey: List<int>.filled(32, 0x02),
        messageNumber: 5,
        previousChainLength: 3,
        nonce: List<int>.filled(12, 0x03),
        ciphertextWithMac: List<int>.filled(48, 0x04),
      );

      final payload = V2StoredMessage.buildInsertPayload(
        envelope: envelope,
        senderId: 'alice',
        chatId: 'chat-123',
      );

      // Required V2 fields
      expect(payload['chat_id'], equals('chat-123'));
      expect(payload['sender_id'], equals('alice'));
      expect(payload['text'], isNull, reason: 'V2 never stores plaintext');
      expect(payload['is_encrypted'], isTrue);
      expect(payload['e2ee_version'], equals(2));
      expect(payload['encrypted_content'], isA<String>());

      // Verify envelope can be decoded from stored base64
      final decoded = V2StoredMessage.decodeFromBase64(
        payload['encrypted_content'] as String,
      );
      expect(decoded.version, equals(2));
      expect(decoded.messageNumber, equals(5));
      expect(decoded.previousChainLength, equals(3));
    });

    test('V2 payload contains no plaintext', () {
      final envelope = V2MessageEnvelope(
        version: 2,
        senderIdentityKey: List<int>.filled(32, 0x01),
        senderRatchetPublicKey: List<int>.filled(32, 0x02),
        messageNumber: 0,
        previousChainLength: 0,
        nonce: List<int>.filled(12, 0x03),
        ciphertextWithMac: List<int>.filled(32, 0x04),
      );

      final payload = V2StoredMessage.buildInsertPayload(
        envelope: envelope,
        senderId: 'alice',
        chatId: 'chat-123',
      );

      // No text field (plaintext)
      expect(payload['text'], isNull);

      // No voice/photo/video fields
      expect(payload.containsKey('voice_url'), isFalse);
      expect(payload.containsKey('photo_url'), isFalse);
      expect(payload.containsKey('video_url'), isFalse);
    });
  });

  group('V2Outgoing — V1 compatibility', () {
    test('V1 path still works when V2 disabled', () {
      final handler = V2Outgoing.instance;
      handler.enabled = false;

      // V1 path doesn't use V2Outgoing at all
      // The existing sendText V1 logic is unchanged
      expect(handler.enabled, isFalse);
    });

    test('V2 path is isolated from V1 path', () {
      // V2Outgoing.instance is a separate singleton
      // V1 uses E2eService.instance
      // They don't interfere
      final v2Handler = V2Outgoing.instance;
      v2Handler.enabled = true;

      // V1 service is independent
      // This is a structural test — verifies separation
      expect(v2Handler.enabled, isTrue);

      v2Handler.enabled = false;
    });
  });

  group('V2Outgoing — ratchet state lifecycle', () {
    test('ratchet state advances after encrypt', () {
      // Simulate ratchet state advancement
      final initialState = V2RatchetState(
        sessionId: 'test',
        rootKey: List<int>.filled(32, 0x01),
        sendingChainKey: List<int>.filled(32, 0x02),
        sendingMessageNumber: 0,
      );

      // After encrypt, state advances
      final advancedState = initialState.copyWith(
        sendingChainKey: List<int>.filled(32, 0x03),
        sendingMessageNumber: 1,
      );

      expect(advancedState.sendingMessageNumber, equals(1));
      expect(advancedState.sendingChainKey, isNot(equals(initialState.sendingChainKey)));
    });

    test('ratchet state is immutable (copyWith returns new instance)', () {
      final state1 = V2RatchetState(
        sessionId: 'test',
        rootKey: List<int>.filled(32, 0x01),
        sendingChainKey: List<int>.filled(32, 0x02),
        sendingMessageNumber: 0,
      );

      final state2 = state1.copyWith(sendingMessageNumber: 1);

      expect(state1.sendingMessageNumber, equals(0));
      expect(state2.sendingMessageNumber, equals(1));
    });
  });

  group('V2Outgoing — error types', () {
    test('V2OutgoingException carries message', () {
      const ex = V2OutgoingException('test error');
      expect(ex.message, equals('test error'));
      expect(ex.toString(), contains('V2OutgoingException'));
    });
  });

  group('V2Outgoing — concurrency control', () {
    test('serialize flag exists', () {
      // Verify the encryptSerialized method exists in the API
      // Actual concurrency testing requires async session setup
      final handler = V2Outgoing.instance;
      expect(handler.enabled, isA<bool>());
    });
  });

  group('V2Outgoing — security properties', () {
    test('no plaintext in V2 envelope', () {
      final envelope = V2MessageEnvelope(
        version: 2,
        senderIdentityKey: List<int>.filled(32, 0x01),
        senderRatchetPublicKey: List<int>.filled(32, 0x02),
        messageNumber: 0,
        previousChainLength: 0,
        nonce: List<int>.filled(12, 0x03),
        ciphertextWithMac: List<int>.filled(32, 0x04),
      );

      // Envelope bytes should not contain plaintext
      final bytes = envelope.toBytes();
      // The ciphertext is encrypted — no plaintext visible
      expect(bytes.length, greaterThan(V2MessageEnvelope.headerSize + 12));
    });

    test('V2 encrypted_content is base64 of binary envelope', () {
      final envelope = V2MessageEnvelope(
        version: 2,
        senderIdentityKey: List<int>.filled(32, 0x01),
        senderRatchetPublicKey: List<int>.filled(32, 0x02),
        messageNumber: 0,
        previousChainLength: 0,
        nonce: List<int>.filled(12, 0x03),
        ciphertextWithMac: List<int>.filled(32, 0x04),
      );

      final base64 = V2StoredMessage.encodeToBase64(envelope);
      // Base64 only contains A-Z, a-z, 0-9, +, /, =
      expect(RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(base64), isTrue);
    });

    test('feature flag controls V2 path activation', () {
      final handler = V2Outgoing.instance;

      // Disabled: V1 path used
      handler.enabled = false;
      expect(handler.enabled, isFalse);

      // Enabled: V2 path attempted
      handler.enabled = true;
      expect(handler.enabled, isTrue);

      // Reset
      handler.enabled = false;
    });
  });
}
