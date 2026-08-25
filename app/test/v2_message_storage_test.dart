// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/v2_message_storage.dart';
import 'package:vibe_app/data/v2_ratchet.dart';

void main() {
  // Helper: create a minimal valid V2 envelope for testing
  V2MessageEnvelope createTestEnvelope({
    int messageNumber = 0,
    int previousChainLength = 0,
    List<int>? ciphertextWithMac,
  }) {
    return V2MessageEnvelope(
      version: 2,
      senderIdentityKey: List<int>.filled(32, 0x01),
      senderRatchetPublicKey: List<int>.filled(32, 0x02),
      messageNumber: messageNumber,
      previousChainLength: previousChainLength,
      nonce: List<int>.filled(12, 0x03),
      ciphertextWithMac: ciphertextWithMac ?? List<int>.filled(32, 0x04),
    );
  }

  // Helper: create a minimal V1-style row (is_encrypted=true, no e2ee_version)
  Map<String, dynamic> createV1Row() {
    return {
      'id': 'test-id-1',
      'chat_id': 'chat-1',
      'sender_id': 'user-1',
      'text': null,
      'is_encrypted': true,
      'e2ee_version': null,
      'encrypted_content': jsonEncode({
        'ciphertext': base64Encode(List<int>.filled(16, 0xAA)),
        'iv': base64Encode(List<int>.filled(12, 0xBB)),
        'mac': base64Encode(List<int>.filled(16, 0xCC)),
      }),
      'created_at': '2026-08-15T12:00:00Z',
    };
  }

  // Helper: create a V2 row
  Map<String, dynamic> createV2Row({
    V2MessageEnvelope? envelope,
  }) {
    final env = envelope ?? createTestEnvelope();
    return {
      'id': 'test-id-2',
      'chat_id': 'chat-1',
      'sender_id': 'user-1',
      'text': null,
      'is_encrypted': true,
      'e2ee_version': 2,
      'encrypted_content': V2StoredMessage.encodeToBase64(env),
      'created_at': '2026-08-15T12:00:00Z',
    };
  }

  // Helper: create a plaintext row
  Map<String, dynamic> createPlaintextRow() {
    return {
      'id': 'test-id-3',
      'chat_id': 'chat-1',
      'sender_id': 'user-1',
      'text': 'Hello, world!',
      'is_encrypted': false,
      'e2ee_version': null,
      'encrypted_content': null,
      'created_at': '2026-08-15T12:00:00Z',
    };
  }

  group('V2StoredMessage — base64 roundtrip', () {
    test('encode then decode returns identical envelope', () {
      final original = createTestEnvelope(messageNumber: 42, previousChainLength: 7);
      final base64 = V2StoredMessage.encodeToBase64(original);
      final decoded = V2StoredMessage.decodeFromBase64(base64);

      expect(decoded.version, equals(2));
      expect(decoded.senderIdentityKey, equals(original.senderIdentityKey));
      expect(decoded.senderRatchetPublicKey, equals(original.senderRatchetPublicKey));
      expect(decoded.messageNumber, equals(42));
      expect(decoded.previousChainLength, equals(7));
      expect(decoded.nonce, equals(original.nonce));
      expect(decoded.ciphertextWithMac, equals(original.ciphertextWithMac));
    });

    test('roundtrip with large ciphertext (1KB)', () {
      final largeCt = List<int>.filled(1024, 0xAB);
      final original = createTestEnvelope(ciphertextWithMac: largeCt);
      final base64 = V2StoredMessage.encodeToBase64(original);
      final decoded = V2StoredMessage.decodeFromBase64(base64);

      expect(decoded.ciphertextWithMac.length, equals(1024));
      expect(decoded.ciphertextWithMac, equals(largeCt));
    });

    test('roundtrip with zero-length ciphertext (header-only)', () {
      // Minimum valid: header(73) + nonce(12) + tag(16) = 101 bytes
      // ciphertextWithMac must include at least the GCM tag (16 bytes)
      final original = createTestEnvelope(ciphertextWithMac: List<int>.filled(16, 0x00));
      final base64 = V2StoredMessage.encodeToBase64(original);
      final decoded = V2StoredMessage.decodeFromBase64(base64);

      expect(decoded.ciphertextWithMac.length, equals(16));
    });
  });

  group('V2StoredMessage — version discrimination', () {
    test('isV2Message returns true for V2 rows', () {
      final row = createV2Row();
      expect(V2StoredMessage.isV2Message(row), isTrue);
    });

    test('isV2Message returns false for V1 rows', () {
      final row = createV1Row();
      expect(V2StoredMessage.isV2Message(row), isFalse);
    });

    test('isV1Message returns true for V1 rows', () {
      final row = createV1Row();
      expect(V2StoredMessage.isV1Message(row), isTrue);
    });

    test('isV1Message returns false for V2 rows', () {
      final row = createV2Row();
      expect(V2StoredMessage.isV1Message(row), isFalse);
    });

    test('isPlaintextMessage returns true for unencrypted rows', () {
      final row = createPlaintextRow();
      expect(V2StoredMessage.isPlaintextMessage(row), isTrue);
    });

    test('isPlaintextMessage returns false for encrypted rows', () {
      final row = createV2Row();
      expect(V2StoredMessage.isPlaintextMessage(row), isFalse);
    });
  });

  group('V2StoredMessage — insert payload', () {
    test('buildInsertPayload contains correct fields', () {
      final envelope = createTestEnvelope();
      final payload = V2StoredMessage.buildInsertPayload(
        envelope: envelope,
        senderId: 'user-1',
        chatId: 'chat-1',
      );

      expect(payload['chat_id'], equals('chat-1'));
      expect(payload['sender_id'], equals('user-1'));
      expect(payload['text'], isNull);
      expect(payload['is_encrypted'], isTrue);
      expect(payload['e2ee_version'], equals(2));
      expect(payload['encrypted_content'], isA<String>());
      expect((payload['encrypted_content'] as String).isNotEmpty, isTrue);
    });

    test('buildInsertPayload encrypted_content decodes to original envelope', () {
      final original = createTestEnvelope(messageNumber: 99);
      final payload = V2StoredMessage.buildInsertPayload(
        envelope: original,
        senderId: 'user-1',
        chatId: 'chat-1',
      );

      final decoded = V2StoredMessage.decodeFromBase64(
        payload['encrypted_content'] as String,
      );
      expect(decoded.messageNumber, equals(99));
      expect(decoded.version, equals(2));
    });
  });

  group('V2StoredMessage — extract from row', () {
    test('extractFromRow returns envelope for V2 rows', () {
      final original = createTestEnvelope(messageNumber: 5);
      final row = createV2Row(envelope: original);
      final envelope = V2StoredMessage.extractFromRow(row);

      expect(envelope, isNotNull);
      expect(envelope!.messageNumber, equals(5));
    });

    test('extractFromRow returns null for V1 rows', () {
      final row = createV1Row();
      final envelope = V2StoredMessage.extractFromRow(row);
      expect(envelope, isNull);
    });

    test('extractFromRow returns null for plaintext rows', () {
      final row = createPlaintextRow();
      final envelope = V2StoredMessage.extractFromRow(row);
      expect(envelope, isNull);
    });

    test('extractFromRow throws for V2 row with missing encrypted_content', () {
      final row = {
        'e2ee_version': 2,
        'is_encrypted': true,
        'encrypted_content': null,
      };
      expect(
        () => V2StoredMessage.extractFromRow(row),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('extractFromRow throws for V2 row with empty encrypted_content', () {
      final row = {
        'e2ee_version': 2,
        'is_encrypted': true,
        'encrypted_content': '',
      };
      expect(
        () => V2StoredMessage.extractFromRow(row),
        throwsA(isA<V2RatchetException>()),
      );
    });
  });

  group('V2StoredMessage — malformed envelope validation', () {
    test('decodeFromBase64 throws on empty string', () {
      expect(
        () => V2StoredMessage.decodeFromBase64(''),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('decodeFromBase64 throws on invalid base64', () {
      expect(
        () => V2StoredMessage.decodeFromBase64('!!!not-base64!!!'),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('decodeFromBase64 throws on truncated envelope', () {
      // Valid base64 of 50 bytes (too short for min 101)
      final shortBytes = List<int>.filled(50, 0x00);
      final b64 = base64Encode(shortBytes);
      expect(
        () => V2StoredMessage.decodeFromBase64(b64),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('decodeFromBase64 throws on wrong version byte', () {
      // Create 101-byte envelope with version=99
      final bytes = List<int>.filled(101, 0x00);
      bytes[0] = 99; // wrong version
      final b64 = base64Encode(bytes);
      expect(
        () => V2StoredMessage.decodeFromBase64(b64),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('decodeFromBase64 throws on oversized envelope', () {
      final oversizedBytes = List<int>.filled(V2StoredMessage.maxEnvelopeBytes + 1, 0x00);
      oversizedBytes[0] = 2; // version
      final b64 = base64Encode(oversizedBytes);
      expect(
        () => V2StoredMessage.decodeFromBase64(b64),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('validateBytes rejects empty list', () {
      expect(
        () => V2StoredMessage.validateBytes([]),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('validateBytes rejects wrong version', () {
      final bytes = List<int>.filled(101, 0x00);
      bytes[0] = 1; // V1 version
      expect(
        () => V2StoredMessage.validateBytes(bytes),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('validateBytes rejects too short', () {
      final bytes = List<int>.filled(50, 0x00);
      bytes[0] = 2;
      expect(
        () => V2StoredMessage.validateBytes(bytes),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('validateBytes accepts valid envelope', () {
      final envelope = createTestEnvelope();
      final bytes = envelope.toBytes();
      expect(V2StoredMessage.validateBytes(bytes), isTrue);
    });

    test('validateBase64 rejects empty string', () {
      expect(
        () => V2StoredMessage.validateBase64(''),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('validateBase64 rejects invalid characters', () {
      expect(
        () => V2StoredMessage.validateBase64('hello world!'),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('validateBase64 accepts valid base64', () {
      final envelope = createTestEnvelope();
      final b64 = V2StoredMessage.encodeToBase64(envelope);
      expect(V2StoredMessage.validateBase64(b64), isTrue);
    });
  });

  group('V2StoredMessage — payload limits', () {
    test('minEnvelopeBytes is 101 (header 73 + nonce 12 + tag 16)', () {
      expect(V2StoredMessage.minEnvelopeBytes, equals(101));
    });

    test('maxEnvelopeBytes is 66000', () {
      expect(V2StoredMessage.maxEnvelopeBytes, equals(66000));
    });

    test('maxBase64Length is 88000', () {
      expect(V2StoredMessage.maxBase64Length, equals(88000));
    });

    test('envelope at max size is accepted', () {
      final maxCt = List<int>.filled(
        V2StoredMessage.maxEnvelopeBytes - V2MessageEnvelope.headerSize - 12,
        0xAB,
      );
      final envelope = createTestEnvelope(ciphertextWithMac: maxCt);
      final b64 = V2StoredMessage.encodeToBase64(envelope);
      // Should decode without error
      final decoded = V2StoredMessage.decodeFromBase64(b64);
      expect(decoded.ciphertextWithMac.length, equals(maxCt.length));
    });
  });

  group('V2StoredMessage — Realtime event contract', () {
    test('V2 realtime event contains envelope but no plaintext', () {
      final envelope = createTestEnvelope();
      final row = createV2Row(envelope: envelope);

      // Simulate what broadcast would send
      final broadcastPayload = {
        'id': row['id'],
        'chat_id': row['chat_id'],
        'sender_id': row['sender_id'],
        'is_encrypted': row['is_encrypted'],
        'e2ee_version': row['e2ee_version'],
        'encrypted_content': row['encrypted_content'],
        'created_at': row['created_at'],
      };

      // No plaintext in payload
      expect(broadcastPayload['text'], isNull);

      // Envelope is present and decodable
      expect(broadcastPayload['encrypted_content'], isA<String>());
      final decoded = V2StoredMessage.decodeFromBase64(
        broadcastPayload['encrypted_content'] as String,
      );
      expect(decoded.version, equals(2));
    });

    test('V2 event includes e2ee_version for client routing', () {
      final row = createV2Row();
      expect(row['e2ee_version'], equals(2));
      expect(V2StoredMessage.isV2Message(row), isTrue);
    });
  });

  group('V2StoredMessage — dedup / idempotency', () {
    test('same envelope produces same base64 (deterministic)', () {
      final envelope = createTestEnvelope(messageNumber: 10);
      final b64_1 = V2StoredMessage.encodeToBase64(envelope);
      final b64_2 = V2StoredMessage.encodeToBase64(envelope);
      expect(b64_1, equals(b64_2));
    });

    test('different envelopes produce different base64', () {
      final env1 = createTestEnvelope(messageNumber: 1);
      final env2 = createTestEnvelope(messageNumber: 2);
      final b64_1 = V2StoredMessage.encodeToBase64(env1);
      final b64_2 = V2StoredMessage.encodeToBase64(env2);
      expect(b64_1, isNot(equals(b64_2)));
    });

    test('duplicate insert has same row structure', () {
      final envelope = createTestEnvelope();
      final payload1 = V2StoredMessage.buildInsertPayload(
        envelope: envelope,
        senderId: 'user-1',
        chatId: 'chat-1',
      );
      final payload2 = V2StoredMessage.buildInsertPayload(
        envelope: envelope,
        senderId: 'user-1',
        chatId: 'chat-1',
      );
      // Same encrypted_content (deterministic)
      expect(payload1['encrypted_content'], equals(payload2['encrypted_content']));
    });
  });
}
