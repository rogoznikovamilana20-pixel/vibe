// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/v2_ratchet.dart';

void main() {
  group('Envelope: Serialization', () {
    test('toBytes → fromBytes roundtrip', () {
      final header = V2MessageHeader(protocolVersion: 2, senderIdentityKey: List<int>.generate(32, (i) => i), senderRatchetPublicKey: List<int>.generate(32, (i) => i + 100), messageNumber: 42, previousChainLength: 7);
      final secretBoxConcat = [...List<int>.generate(12, (i) => i + 200), ...List<int>.generate(48, (i) => i + 50)];
      final envelope = V2MessageEnvelope.fromComponents(header: header, secretBoxConcat: secretBoxConcat);
      final bytes = envelope.toBytes();
      final restored = V2MessageEnvelope.fromBytes(bytes);
      expect(restored.version, 2);
      expect(restored.senderIdentityKey, header.senderIdentityKey);
      expect(restored.senderRatchetPublicKey, header.senderRatchetPublicKey);
      expect(restored.messageNumber, 42);
      expect(restored.previousChainLength, 7);
      expect(restored.nonce, List<int>.generate(12, (i) => i + 200));
      expect(restored.ciphertextWithMac.length, 48);
    });

    test('toBytes is deterministic', () {
      final header = V2MessageHeader(protocolVersion: 2, senderIdentityKey: List<int>.generate(32, (i) => i), senderRatchetPublicKey: List<int>.generate(32, (i) => i), messageNumber: 0, previousChainLength: 0);
      final secretBoxConcat = [...List<int>.generate(12, (i) => 0), ...List<int>.generate(32, (i) => 0), ...List<int>.generate(16, (i) => 0)];
      final e1 = V2MessageEnvelope.fromComponents(header: header, secretBoxConcat: secretBoxConcat);
      final e2 = V2MessageEnvelope.fromComponents(header: header, secretBoxConcat: secretBoxConcat);
      expect(e1.toBytes(), e2.toBytes());
    });

    test('toDecryptComponents returns correct header', () {
      final header = V2MessageHeader(protocolVersion: 2, senderIdentityKey: List<int>.generate(32, (i) => 10), senderRatchetPublicKey: List<int>.generate(32, (i) => 20), messageNumber: 5, previousChainLength: 3);
      final secretBoxConcat = [...List<int>.generate(12, (i) => 30), ...List<int>.generate(48, (i) => 40)];
      final envelope = V2MessageEnvelope.fromComponents(header: header, secretBoxConcat: secretBoxConcat);
      final components = envelope.toDecryptComponents();
      expect(components.header.messageNumber, 5);
      expect(components.secretBoxConcat, secretBoxConcat);
    });

    test('fromBytes rejects too-short input', () {
      expect(() => V2MessageEnvelope.fromBytes(List<int>.generate(10, (i) => i)), throwsA(isA<V2RatchetException>()));
    });
  });

  group('Envelope: Basic Encrypt/Decrypt', () {
    test('encryptToEnvelope → decryptFromEnvelope roundtrip', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);

      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'Hello, Bob!', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');

      var bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey).copyWith(receivingRatchetPublicKey: enc.envelope.senderRatchetPublicKey);
      final dec = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: enc.envelope, senderDeviceId: 'a', recipientDeviceId: 'b');
      expect(dec.plaintext, 'Hello, Bob!');
    });

    test('decrypt with wrong message key fails', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);

      var aliceState = V2Ratchet.createInitialState(sessionId: 's1', rootKey: rootKey, chainKey: chainKey);
      final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'secret', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');

      final wrongState = V2Ratchet.createReceiverInitialState(sessionId: 's1', rootKey: List<int>.generate(32, (i) => 99), chainKey: List<int>.generate(32, (i) => 99));
      expect(() => V2Ratchet.decryptFromEnvelope(state: wrongState, envelope: enc.envelope, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });
  });

  group('Envelope: Direction', () {
    test('Alice → Bob', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);

      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      var bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'msg-a', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      bobState = bobState.copyWith(receivingRatchetPublicKey: enc.envelope.senderRatchetPublicKey);
      final dec = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: enc.envelope, senderDeviceId: 'a', recipientDeviceId: 'b');
      expect(dec.plaintext, 'msg-a');
    });

    test('Bob → Alice (after DH ratchet)', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final bobIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final bobIkPub = await bobIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);

      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      var bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);

      final enc1 = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'a1', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      aliceState = enc1.state;
      bobState = bobState.copyWith(receivingRatchetPublicKey: enc1.envelope.senderRatchetPublicKey);
      final dec1 = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: enc1.envelope, senderDeviceId: 'a', recipientDeviceId: 'b');
      bobState = dec1.state;

      final enc2 = await V2Ratchet.encryptToEnvelope(state: bobState, plaintext: 'b1', identityKeyPublic: bobIkPub.bytes, senderDeviceId: 'b', recipientDeviceId: 'a');
      bobState = enc2.state;
      final dec2 = await V2Ratchet.decryptFromEnvelope(state: aliceState, envelope: enc2.envelope, senderDeviceId: 'b', recipientDeviceId: 'a');
      aliceState = dec2.state;
      expect(dec2.plaintext, 'b1');
    });
  });

  group('Envelope: Multiple Messages', () {
    test('10 messages in sequence', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);

      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      var bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);

      final envelopes = <V2MessageEnvelope>[];
      for (var i = 0; i < 10; i++) {
        final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'msg-$i', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
        aliceState = enc.state;
        envelopes.add(enc.envelope);
      }
      bobState = bobState.copyWith(receivingRatchetPublicKey: envelopes.first.senderRatchetPublicKey);
      for (var i = 0; i < 10; i++) {
        final dec = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: envelopes[i], senderDeviceId: 'a', recipientDeviceId: 'b');
        bobState = dec.state;
        expect(dec.plaintext, 'msg-$i');
      }
    });
  });

  group('Envelope: Replay', () {
    test('same envelope twice → second decrypt fails', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);

      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'once', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');

      var bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey).copyWith(receivingRatchetPublicKey: enc.envelope.senderRatchetPublicKey);
      final dec1 = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: enc.envelope, senderDeviceId: 'a', recipientDeviceId: 'b');
      bobState = dec1.state;

      expect(() => V2Ratchet.decryptFromEnvelope(state: bobState, envelope: enc.envelope, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });
  });

  group('Envelope: Tamper Resistance', () {
    late List<int> validBytes;
    late List<int> rootKey;
    late List<int> chainKey;

    setUpAll(() async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      rootKey = List<int>.generate(32, (i) => i + 1);
      chainKey = List<int>.generate(32, (i) => i + 100);
      final aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'tamper-test', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      validBytes = enc.envelope.toBytes();
    });

    test('tamper version → fail', () async {
      final tampered = List<int>.from(validBytes);
      tampered[0] = 99;
      final env = V2MessageEnvelope.fromBytes(tampered);
      final bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey).copyWith(receivingRatchetPublicKey: env.senderRatchetPublicKey);
      expect(() => V2Ratchet.decryptFromEnvelope(state: bobState, envelope: env, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });

    test('tamper sender identity key → fail', () async {
      final tampered = List<int>.from(validBytes);
      tampered[1] ^= 0xFF;
      final env = V2MessageEnvelope.fromBytes(tampered);
      final bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      expect(() => V2Ratchet.decryptFromEnvelope(state: bobState, envelope: env, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });

    test('tamper sender ratchet public key → fail', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      var bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final setup = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'setup', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      aliceState = setup.state;
      bobState = bobState.copyWith(receivingRatchetPublicKey: setup.envelope.senderRatchetPublicKey);
      final setupDec = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: setup.envelope, senderDeviceId: 'a', recipientDeviceId: 'b');
      bobState = setupDec.state;
      final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'test', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      final tampered = enc.envelope.toBytes();
      tampered[33] ^= 0xFF;
      final env = V2MessageEnvelope.fromBytes(tampered);
      expect(() => V2Ratchet.decryptFromEnvelope(state: bobState, envelope: env, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });

    test('tamper message number → fail', () async {
      final tampered = List<int>.from(validBytes);
      tampered[68] = 99;
      final env = V2MessageEnvelope.fromBytes(tampered);
      final bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey).copyWith(receivingRatchetPublicKey: env.senderRatchetPublicKey);
      expect(() => V2Ratchet.decryptFromEnvelope(state: bobState, envelope: env, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });

    test('tamper nonce → fail', () async {
      final tampered = List<int>.from(validBytes);
      tampered[73] ^= 0xFF;
      final env = V2MessageEnvelope.fromBytes(tampered);
      final bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey).copyWith(receivingRatchetPublicKey: env.senderRatchetPublicKey);
      expect(() => V2Ratchet.decryptFromEnvelope(state: bobState, envelope: env, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });

    test('tamper previous chain length → fail', () async {
      final tampered = List<int>.from(validBytes);
      tampered[72] ^= 0xFF;
      final env = V2MessageEnvelope.fromBytes(tampered);
      final bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey).copyWith(receivingRatchetPublicKey: env.senderRatchetPublicKey);
      expect(() => V2Ratchet.decryptFromEnvelope(state: bobState, envelope: env, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });

    test('tamper ciphertext → fail', () async {
      final tampered = List<int>.from(validBytes);
      tampered[tampered.length - 3] ^= 0xFF;
      final env = V2MessageEnvelope.fromBytes(tampered);
      final bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey).copyWith(receivingRatchetPublicKey: env.senderRatchetPublicKey);
      expect(() => V2Ratchet.decryptFromEnvelope(state: bobState, envelope: env, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });

    test('tamper authentication tag → fail', () async {
      final tampered = List<int>.from(validBytes);
      tampered[tampered.length - 1] ^= 0xFF;
      final env = V2MessageEnvelope.fromBytes(tampered);
      final bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey).copyWith(receivingRatchetPublicKey: env.senderRatchetPublicKey);
      expect(() => V2Ratchet.decryptFromEnvelope(state: bobState, envelope: env, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });
  });

  group('Envelope: Out-of-Order', () {
    test('1, 3, 2 → all decrypt', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);
      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final envs = <V2MessageEnvelope>[];
      for (var i = 0; i < 3; i++) {
        final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'msg-$i', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
        aliceState = enc.state;
        envs.add(enc.envelope);
      }
      var bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey).copyWith(receivingRatchetPublicKey: envs[0].senderRatchetPublicKey);
      final d1 = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: envs[0], senderDeviceId: 'a', recipientDeviceId: 'b');
      bobState = d1.state;
      expect(d1.plaintext, 'msg-0');
      final d3 = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: envs[2], senderDeviceId: 'a', recipientDeviceId: 'b');
      bobState = d3.state;
      expect(d3.plaintext, 'msg-2');
      final d2 = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: envs[1], senderDeviceId: 'a', recipientDeviceId: 'b');
      bobState = d2.state;
      expect(d2.plaintext, 'msg-1');
    });

    test('replayed message after consumption → fail', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);
      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final envs = <V2MessageEnvelope>[];
      for (var i = 0; i < 3; i++) {
        final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'msg-$i', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
        aliceState = enc.state;
        envs.add(enc.envelope);
      }
      var bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey).copyWith(receivingRatchetPublicKey: envs[0].senderRatchetPublicKey);
      final d1 = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: envs[0], senderDeviceId: 'a', recipientDeviceId: 'b');
      bobState = d1.state;
      final d3 = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: envs[2], senderDeviceId: 'a', recipientDeviceId: 'b');
      bobState = d3.state;
      final d2 = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: envs[1], senderDeviceId: 'a', recipientDeviceId: 'b');
      bobState = d2.state;
      expect(() => V2Ratchet.decryptFromEnvelope(state: bobState, envelope: envs[1], senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });
  });

  group('Envelope: Bidirectional', () {
    test('A1→B1→A2→B2→A3→B3', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final bobIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final bobIkPub = await bobIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);
      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      var bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      for (final (sender, msg) in [('alice', 'A1'), ('bob', 'B1'), ('alice', 'A2'), ('bob', 'B2'), ('alice', 'A3'), ('bob', 'B3')]) {
        if (sender == 'alice') {
          final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: msg, identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
          aliceState = enc.state;
          final dec = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: enc.envelope, senderDeviceId: 'a', recipientDeviceId: 'b');
          bobState = dec.state;
          expect(dec.plaintext, msg);
        } else {
          final enc = await V2Ratchet.encryptToEnvelope(state: bobState, plaintext: msg, identityKeyPublic: bobIkPub.bytes, senderDeviceId: 'b', recipientDeviceId: 'a');
          bobState = enc.state;
          final dec = await V2Ratchet.decryptFromEnvelope(state: aliceState, envelope: enc.envelope, senderDeviceId: 'b', recipientDeviceId: 'a');
          aliceState = dec.state;
          expect(dec.plaintext, msg);
        }
      }
    });
  });

  group('Envelope: Wrong Session', () {
    test('decrypt with unrelated session → fail', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey1 = List<int>.generate(32, (i) => i + 1);
      final chainKey1 = List<int>.generate(32, (i) => i + 100);
      var state1 = V2Ratchet.createInitialState(sessionId: 's1', rootKey: rootKey1, chainKey: chainKey1);
      final enc = await V2Ratchet.encryptToEnvelope(state: state1, plaintext: 'secret', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      final rootKey2 = List<int>.generate(32, (i) => i + 50);
      final chainKey2 = List<int>.generate(32, (i) => i + 150);
      final bobState = V2Ratchet.createReceiverInitialState(sessionId: 's2', rootKey: rootKey2, chainKey: chainKey2).copyWith(receivingRatchetPublicKey: enc.envelope.senderRatchetPublicKey);
      expect(() => V2Ratchet.decryptFromEnvelope(state: bobState, envelope: enc.envelope, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });
  });

  group('Envelope: Wrong Device', () {
    test('Bob Device C state → fail', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);
      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'for-bob-b', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      final bobCState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: List<int>.generate(32, (i) => i + 200), chainKey: List<int>.generate(32, (i) => i + 250)).copyWith(receivingRatchetPublicKey: enc.envelope.senderRatchetPublicKey);
      expect(() => V2Ratchet.decryptFromEnvelope(state: bobCState, envelope: enc.envelope, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });
  });

  group('Envelope: State Persistence', () {
    test('encrypt → serialize → reload → continue', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);
      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final enc1 = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'before-restart', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      aliceState = enc1.state;
      final serialized = await _serializeState(aliceState);
      final reloadedState = await _deserializeState(serialized);
      final enc2 = await V2Ratchet.encryptToEnvelope(state: reloadedState, plaintext: 'after-restart', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      var bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey).copyWith(receivingRatchetPublicKey: enc1.envelope.senderRatchetPublicKey);
      final dec1 = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: enc1.envelope, senderDeviceId: 'a', recipientDeviceId: 'b');
      bobState = dec1.state;
      expect(dec1.plaintext, 'before-restart');
      final dec2 = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: enc2.envelope, senderDeviceId: 'a', recipientDeviceId: 'b');
      expect(dec2.plaintext, 'after-restart');
    });
  });

  group('Envelope: Corrupted State', () {
    test('tampered root key → fail closed', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);
      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'test', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      final bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: List<int>.generate(32, (i) => 99), chainKey: List<int>.generate(32, (i) => 200)).copyWith(receivingRatchetPublicKey: enc.envelope.senderRatchetPublicKey);
      expect(() => V2Ratchet.decryptFromEnvelope(state: bobState, envelope: enc.envelope, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });

    test('tampered chain key → fail closed', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);
      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'test', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      final bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: List<int>.generate(32, (i) => 99)).copyWith(receivingRatchetPublicKey: enc.envelope.senderRatchetPublicKey);
      expect(() => V2Ratchet.decryptFromEnvelope(state: bobState, envelope: enc.envelope, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<Exception>()));
    });
  });

  group('Envelope: Nonce Uniqueness', () {
    test('different messages produce different nonces', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);
      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final nonces = <List<int>>[];
      for (var i = 0; i < 10; i++) {
        final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'msg-$i', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
        aliceState = enc.state;
        nonces.add(enc.envelope.nonce);
      }
      expect(nonces.length, nonces.map((n) => n.join(',')).toSet().length);
    });
  });

  group('Envelope: State Advancement', () {
    test('sending chain advances after encrypt', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);
      var state = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final enc = await V2Ratchet.encryptToEnvelope(state: state, plaintext: 'test', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      expect(enc.state.sendingMessageNumber, 1);
      expect(enc.state.sendingChainKey, isNot(chainKey));
    });

    test('receiving chain advances after decrypt', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);
      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      var bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'test', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      bobState = bobState.copyWith(receivingRatchetPublicKey: enc.envelope.senderRatchetPublicKey);
      final dec = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: enc.envelope, senderDeviceId: 'a', recipientDeviceId: 'b');
      expect(dec.state.receivingMessageNumber, 1);
    });

    test('ratchetStep increments after DH ratchet', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final bobIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final bobIkPub = await bobIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);
      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      var bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final enc1 = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'a1', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      aliceState = enc1.state;
      bobState = bobState.copyWith(receivingRatchetPublicKey: enc1.envelope.senderRatchetPublicKey);
      final dec1 = await V2Ratchet.decryptFromEnvelope(state: bobState, envelope: enc1.envelope, senderDeviceId: 'a', recipientDeviceId: 'b');
      bobState = dec1.state;
      expect(aliceState.ratchetStep, 0);
      expect(bobState.ratchetStep, 0);
      final enc2 = await V2Ratchet.encryptToEnvelope(state: bobState, plaintext: 'b1', identityKeyPublic: bobIkPub.bytes, senderDeviceId: 'b', recipientDeviceId: 'a');
      bobState = enc2.state;
      expect(bobState.ratchetStep, 1);
      final dec2 = await V2Ratchet.decryptFromEnvelope(state: aliceState, envelope: enc2.envelope, senderDeviceId: 'b', recipientDeviceId: 'a');
      aliceState = dec2.state;
      expect(aliceState.ratchetStep, 1);
    });
  });

  group('Envelope: Version Validation', () {
    test('unsupported version → fail', () async {
      final x25519 = Cryptography.instance.x25519();
      final aliceIk = await x25519.newKeyPair();
      final aliceIkPub = await aliceIk.extractPublicKey();
      final rootKey = List<int>.generate(32, (i) => i + 1);
      final chainKey = List<int>.generate(32, (i) => i + 100);
      var aliceState = V2Ratchet.createInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey);
      final enc = await V2Ratchet.encryptToEnvelope(state: aliceState, plaintext: 'test', identityKeyPublic: aliceIkPub.bytes, senderDeviceId: 'a', recipientDeviceId: 'b');
      final envBytes = enc.envelope.toBytes();
      envBytes[0] = 99;
      final tamperedEnv = V2MessageEnvelope.fromBytes(envBytes);
      final bobState = V2Ratchet.createReceiverInitialState(sessionId: 's', rootKey: rootKey, chainKey: chainKey).copyWith(receivingRatchetPublicKey: tamperedEnv.senderRatchetPublicKey);
      expect(() => V2Ratchet.decryptFromEnvelope(state: bobState, envelope: tamperedEnv, senderDeviceId: 'a', recipientDeviceId: 'b'), throwsA(isA<V2RatchetException>()));
    });
  });
}

Future<Map<String, dynamic>> _serializeState(V2RatchetState state) async {
  List<int>? ratchetPrivBytes;
  List<int>? ratchetPubBytes;
  if (state.sendingRatchetKeyPair != null) {
    ratchetPrivBytes = await state.sendingRatchetKeyPair!.extractPrivateKeyBytes();
    ratchetPubBytes = state.sendingRatchetPubBytes;
  }
  return {
    'session_id': state.sessionId,
    'root_key': base64Encode(state.rootKey),
    'sending_chain_key': state.sendingChainKey != null ? base64Encode(state.sendingChainKey!) : null,
    'receiving_chain_key': state.receivingChainKey != null ? base64Encode(state.receivingChainKey!) : null,
    'sending_ratchet_priv': ratchetPrivBytes != null ? base64Encode(ratchetPrivBytes) : null,
    'sending_ratchet_pub': ratchetPubBytes != null ? base64Encode(ratchetPubBytes) : null,
    'receiving_ratchet_pub': state.receivingRatchetPublicKey != null ? base64Encode(state.receivingRatchetPublicKey!) : null,
    'sending_message_number': state.sendingMessageNumber,
    'receiving_message_number': state.receivingMessageNumber,
    'previous_sending_chain_length': state.previousSendingChainLength,
    'skipped_keys': state.skippedKeys.map((k, v) => MapEntry(k.toString(), base64Encode(v))),
    'protocol_version': state.protocolVersion,
    'ratchet_step': state.ratchetStep,
  };
}

Future<V2RatchetState> _deserializeState(Map<String, dynamic> json) async {
  SimpleKeyPair? ratchetKeyPair;
  List<int>? ratchetPubBytes;
  if (json['sending_ratchet_priv'] != null) {
    final privBytes = base64Decode(json['sending_ratchet_priv'] as String);
    ratchetPubBytes = base64Decode(json['sending_ratchet_pub'] as String);
    ratchetKeyPair = SimpleKeyPairData(privBytes, publicKey: SimplePublicKey(ratchetPubBytes, type: KeyPairType.x25519), type: KeyPairType.x25519);
  }
  final skippedKeysRaw = json['skipped_keys'] as Map<String, dynamic>? ?? {};
  final skippedKeys = skippedKeysRaw.map((k, v) => MapEntry(int.parse(k), base64Decode(v as String)));
  return V2RatchetState(
    sessionId: json['session_id'] as String,
    rootKey: base64Decode(json['root_key'] as String),
    sendingChainKey: json['sending_chain_key'] != null ? base64Decode(json['sending_chain_key'] as String) : null,
    receivingChainKey: json['receiving_chain_key'] != null ? base64Decode(json['receiving_chain_key'] as String) : null,
    sendingRatchetKeyPair: ratchetKeyPair,
    sendingRatchetPubBytes: ratchetPubBytes,
    receivingRatchetPublicKey: json['receiving_ratchet_pub'] != null ? base64Decode(json['receiving_ratchet_pub'] as String) : null,
    sendingMessageNumber: json['sending_message_number'] as int,
    receivingMessageNumber: json['receiving_message_number'] as int,
    previousSendingChainLength: json['previous_sending_chain_length'] as int,
    skippedKeys: skippedKeys,
    protocolVersion: json['protocol_version'] as int,
    ratchetStep: json['ratchet_step'] as int? ?? 0,
  );
}
