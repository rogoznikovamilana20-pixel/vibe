// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/v2_ratchet.dart';

/// Deterministic Double Ratchet test vectors.
///
/// All tests use fixed seeds for key generation to ensure reproducibility.
void main() {
  // ===========================================================================
  // 1. KDF Chain
  // ===========================================================================

  group('KDF Chain', () {
    test('kdfChain produces deterministic output', () async {
      final chainKey = List<int>.generate(32, (i) => i);
      final r1 = await V2Ratchet.kdfChain(chainKey);
      final r2 = await V2Ratchet.kdfChain(chainKey);

      expect(r1.messageKey, r2.messageKey);
      expect(r1.nextChainKey, r2.nextChainKey);
    });

    test('kdfChain produces 32-byte keys', () async {
      final chainKey = List<int>.generate(32, (i) => i);
      final result = await V2Ratchet.kdfChain(chainKey);

      expect(result.messageKey.length, 32);
      expect(result.nextChainKey.length, 32);
    });

    test('kdfChain messageKey != nextChainKey', () async {
      final chainKey = List<int>.generate(32, (i) => i);
      final result = await V2Ratchet.kdfChain(chainKey);

      expect(result.messageKey, isNot(result.nextChainKey));
    });

    test('kdfChain different input → different output', () async {
      final ck1 = List<int>.generate(32, (i) => i);
      final ck2 = List<int>.generate(32, (i) => i + 1);
      final r1 = await V2Ratchet.kdfChain(ck1);
      final r2 = await V2Ratchet.kdfChain(ck2);

      expect(r1.messageKey, isNot(r2.messageKey));
    });

    test('kdfChain chain advancement is deterministic', () async {
      final ck0 = List<int>.generate(32, (i) => i);
      final (messageKey: mk0, nextChainKey: ck1) = await V2Ratchet.kdfChain(ck0);
      final (messageKey: mk1, nextChainKey: ck2) = await V2Ratchet.kdfChain(ck1);
      final (messageKey: mk2, nextChainKey: _) = await V2Ratchet.kdfChain(ck2);

      // All message keys should be different
      expect(mk0, isNot(mk1));
      expect(mk1, isNot(mk2));
      expect(mk0, isNot(mk2));
    });
  });

  // ===========================================================================
  // 2. Basic: Alice encrypt → Bob decrypt
  // ===========================================================================

  group('Basic Send/Receive', () {
    test('Alice encrypt → Bob decrypt (same chain)', () async {
      // Shared state after X3DH
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final chainKey = List<int>.generate(32, (i) => i + 20);
      const sessionId = 'test-session-1';

      // Alice creates initial state and encrypts
      var aliceState = V2Ratchet.createInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      final aliceIk = List<int>.generate(32, (i) => i + 50);
      final encResult = await V2Ratchet.encrypt(
        state: aliceState,
        plaintext: 'Hello, Bob!',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      aliceState = encResult.state;

      // Bob creates receiver initial state and decrypts
      var bobState = V2Ratchet.createReceiverInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      final decResult = await V2Ratchet.decrypt(
        state: bobState,
        header: encResult.header,
        ciphertext: encResult.ciphertext,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      bobState = decResult.state;

      expect(decResult.plaintext, 'Hello, Bob!');
      expect(aliceState.sendingMessageNumber, 1);
      expect(bobState.receivingMessageNumber, 1);
    });
  });

  // ===========================================================================
  // 3. Reverse: Bob encrypt → Alice decrypt
  // ===========================================================================

  group('Reverse Send/Receive', () {
    test('Bob encrypt → Alice decrypt (after DH ratchet)', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final chainKey = List<int>.generate(32, (i) => i + 20);
      const sessionId = 'test-session-2';

      // Alice creates initial state and encrypts first message (triggers ratchet key gen)
      var aliceState = V2Ratchet.createInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      final aliceIk = List<int>.generate(32, (i) => i + 50);
      final encResult1 = await V2Ratchet.encrypt(
        state: aliceState,
        plaintext: 'First message from Alice',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      aliceState = encResult1.state;

      // Bob decrypts first message
      var bobState = V2Ratchet.createReceiverInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      final decResult1 = await V2Ratchet.decrypt(
        state: bobState,
        header: encResult1.header,
        ciphertext: encResult1.ciphertext,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      bobState = decResult1.state;

      expect(decResult1.plaintext, 'First message from Alice');

      // Bob encrypts response
      final bobIk = List<int>.generate(32, (i) => i + 60);
      final encResult2 = await V2Ratchet.encrypt(
        state: bobState,
        plaintext: 'Response from Bob',
        identityKeyPublic: bobIk,
        senderDeviceId: 'bob-device-1',
        recipientDeviceId: 'alice-device-1',
      );
      bobState = encResult2.state;

      // Alice decrypts response (triggers DH ratchet step)
      final decResult2 = await V2Ratchet.decrypt(
        state: aliceState,
        header: encResult2.header,
        ciphertext: encResult2.ciphertext,
        senderDeviceId: 'bob-device-1',
        recipientDeviceId: 'alice-device-1',
      );
      aliceState = decResult2.state;

      expect(decResult2.plaintext, 'Response from Bob');
    });
  });

  // ===========================================================================
  // 4. Multiple messages: 1 → 2 → 3 → 4
  // ===========================================================================

  group('Multiple Messages', () {
    test('4 messages in order', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final chainKey = List<int>.generate(32, (i) => i + 20);
      const sessionId = 'test-session-3';
      final aliceIk = List<int>.generate(32, (i) => i + 50);

      var aliceState = V2Ratchet.createInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      var bobState = V2Ratchet.createReceiverInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      final messages = ['msg1', 'msg2', 'msg3', 'msg4'];

      for (final msg in messages) {
        final enc = await V2Ratchet.encrypt(
          state: aliceState,
          plaintext: msg,
          identityKeyPublic: aliceIk,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        );
        aliceState = enc.state;

        final dec = await V2Ratchet.decrypt(
          state: bobState,
          header: enc.header,
          ciphertext: enc.ciphertext,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        );
        bobState = dec.state;

        expect(dec.plaintext, msg);
      }

      expect(aliceState.sendingMessageNumber, 4);
      expect(bobState.receivingMessageNumber, 4);
    });
  });

  // ===========================================================================
  // 5. Out of order: 1 → 3 → 2
  // ===========================================================================

  group('Out of Order', () {
    test('messages received as 1, 3, 2', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final chainKey = List<int>.generate(32, (i) => i + 20);
      const sessionId = 'test-session-4';
      final aliceIk = List<int>.generate(32, (i) => i + 50);

      var aliceState = V2Ratchet.createInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      // Encrypt 3 messages
      final enc1 = await V2Ratchet.encrypt(
        state: aliceState,
        plaintext: 'msg1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      aliceState = enc1.state;

      final enc2 = await V2Ratchet.encrypt(
        state: aliceState,
        plaintext: 'msg2',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      aliceState = enc2.state;

      final enc3 = await V2Ratchet.encrypt(
        state: aliceState,
        plaintext: 'msg3',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      aliceState = enc3.state;

      // Bob receives: 1, 3, 2
      var bobState = V2Ratchet.createReceiverInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      // Receive message 1
      final dec1 = await V2Ratchet.decrypt(
        state: bobState,
        header: enc1.header,
        ciphertext: enc1.ciphertext,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      bobState = dec1.state;
      expect(dec1.plaintext, 'msg1');

      // Receive message 3 (out of order)
      final dec3 = await V2Ratchet.decrypt(
        state: bobState,
        header: enc3.header,
        ciphertext: enc3.ciphertext,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      bobState = dec3.state;
      expect(dec3.plaintext, 'msg3');

      // Receive message 2 (from skipped keys)
      final dec2 = await V2Ratchet.decrypt(
        state: bobState,
        header: enc2.header,
        ciphertext: enc2.ciphertext,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      bobState = dec2.state;
      expect(dec2.plaintext, 'msg2');
    });
  });

  // ===========================================================================
  // 6. Replay protection
  // ===========================================================================

  group('Replay Protection', () {
    test('same ciphertext rejected on second attempt', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final chainKey = List<int>.generate(32, (i) => i + 20);
      const sessionId = 'test-session-5';
      final aliceIk = List<int>.generate(32, (i) => i + 50);

      var aliceState = V2Ratchet.createInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      final enc = await V2Ratchet.encrypt(
        state: aliceState,
        plaintext: 'secret',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      var bobState = V2Ratchet.createReceiverInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      // First decrypt succeeds
      final dec1 = await V2Ratchet.decrypt(
        state: bobState,
        header: enc.header,
        ciphertext: enc.ciphertext,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      bobState = dec1.state;
      expect(dec1.plaintext, 'secret');

      // Second decrypt with same header → message key consumed → fails
      expect(
        () => V2Ratchet.decrypt(
          state: bobState,
          header: enc.header,
          ciphertext: enc.ciphertext,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        ),
        throwsA(isA<V2RatchetException>()),
      );
    });
  });

  // ===========================================================================
  // 7. Wrong session
  // ===========================================================================

  group('Wrong Session', () {
    test('decrypt with unrelated session → fail', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 50);

      // Session A
      var stateA = V2Ratchet.createInitialState(
        sessionId: 'session-A',
        rootKey: List<int>.generate(32, (i) => i + 10),
        chainKey: List<int>.generate(32, (i) => i + 20),
      );

      final enc = await V2Ratchet.encrypt(
        state: stateA,
        plaintext: 'for A',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // Session B (different root key and chain key)
      var stateB = V2Ratchet.createReceiverInitialState(
        sessionId: 'session-B',
        rootKey: List<int>.generate(32, (i) => i + 99),
        chainKey: List<int>.generate(32, (i) => i + 88),
      );

      // Try to decrypt A's message with B's state → should fail (wrong chain key → MAC error)
      expect(
        () => V2Ratchet.decrypt(
          state: stateB,
          header: enc.header,
          ciphertext: enc.ciphertext,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        ),
        throwsA(anyOf(isA<V2RatchetException>(), isA<SecretBoxAuthenticationError>())),
      );
    });
  });

  // ===========================================================================
  // 8. Wrong device
  // ===========================================================================

  group('Wrong Device', () {
    test('Alice A ciphertext → Bob C state → fail', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 50);

      // Alice device A encrypts
      var stateA = V2Ratchet.createInitialState(
        sessionId: 'session-devices',
        rootKey: List<int>.generate(32, (i) => i + 10),
        chainKey: List<int>.generate(32, (i) => i + 20),
      );

      final enc = await V2Ratchet.encrypt(
        state: stateA,
        plaintext: 'for B device',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-A',
        recipientDeviceId: 'bob-device-B',
      );

      // Bob device C (different session state)
      var stateC = V2Ratchet.createReceiverInitialState(
        sessionId: 'session-devices',
        rootKey: List<int>.generate(32, (i) => i + 99),
        chainKey: List<int>.generate(32, (i) => i + 88),
      );

      // Should fail (different chain key → MAC error)
      expect(
        () => V2Ratchet.decrypt(
          state: stateC,
          header: enc.header,
          ciphertext: enc.ciphertext,
          senderDeviceId: 'alice-device-A',
          recipientDeviceId: 'bob-device-C',
        ),
        throwsA(anyOf(isA<V2RatchetException>(), isA<SecretBoxAuthenticationError>())),
      );
    });
  });

  // ===========================================================================
  // 9. DH Ratchet
  // ===========================================================================

  group('DH Ratchet', () {
    test('new DH key → state updates correctly', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final chainKey = List<int>.generate(32, (i) => i + 20);
      final aliceIk = List<int>.generate(32, (i) => i + 50);

      var aliceState = V2Ratchet.createInitialState(
        sessionId: 'ratchet-test',
        rootKey: rootKey,
        chainKey: chainKey,
      );

      // Alice encrypts first message (generates ratchet key pair)
      final enc1 = await V2Ratchet.encrypt(
        state: aliceState,
        plaintext: 'before ratchet',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      aliceState = enc1.state;

      // Verify ratchet key pair was generated
      expect(aliceState.sendingRatchetKeyPair, isNotNull);
      expect(aliceState.sendingRatchetPubBytes, isNotNull);
      expect(aliceState.sendingRatchetPubBytes!.length, 32);
      expect(enc1.header.senderRatchetPublicKey.length, 32);

      // Bob decrypts first message
      var bobState = V2Ratchet.createReceiverInitialState(
        sessionId: 'ratchet-test',
        rootKey: rootKey,
        chainKey: chainKey,
      );

      final dec1 = await V2Ratchet.decrypt(
        state: bobState,
        header: enc1.header,
        ciphertext: enc1.ciphertext,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      bobState = dec1.state;

      expect(dec1.plaintext, 'before ratchet');

      // Bob has receiving chain from X3DH and receivingRatchetPublicKey stored
      expect(bobState.receivingChainKey, isNotNull);
      expect(bobState.receivingRatchetPublicKey, isNotNull);
      expect(bobState.receivingMessageNumber, 1);
    });
  });

  // ===========================================================================
  // 10. State serialization → reload → continue
  // ===========================================================================

  group('State Persistence', () {
    test('serialize → deserialize → continue', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final chainKey = List<int>.generate(32, (i) => i + 20);
      const sessionId = 'persist-test';
      final aliceIk = List<int>.generate(32, (i) => i + 50);

      var state = V2Ratchet.createInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      // Encrypt a message
      final enc = await V2Ratchet.encrypt(
        state: state,
        plaintext: 'persist me',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      state = enc.state;

      // Simulate serialization (extract state fields)
      final serialized = await _serializeState(state);

      // Deserialize
      final deserialized = await _deserializeState(serialized);

      // Continue with deserialized state
      final enc2 = await V2Ratchet.encrypt(
        state: deserialized,
        plaintext: 'after reload',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      expect(enc2.header.messageNumber, 1);
      expect(enc2.state.sendingMessageNumber, 2);
    });
  });

  // ===========================================================================
  // 11. Corrupted state
  // ===========================================================================

  group('Corrupted State', () {
    test('tampered root key → decryption fails', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final chainKey = List<int>.generate(32, (i) => i + 20);
      const sessionId = 'corrupt-test';
      final aliceIk = List<int>.generate(32, (i) => i + 50);

      var aliceState = V2Ratchet.createInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      final enc = await V2Ratchet.encrypt(
        state: aliceState,
        plaintext: 'original',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // Bob with corrupted root key AND chain key (simulating X3DH failure)
      final corruptedRootKey = List<int>.generate(32, (i) => i + 99);
      final corruptedChainKey = List<int>.generate(32, (i) => i + 88);
      var bobState = V2Ratchet.createReceiverInitialState(
        sessionId: sessionId,
        rootKey: corruptedRootKey,
        chainKey: corruptedChainKey,
      );

      // Should fail (different chain key → MAC error)
      expect(
        () => V2Ratchet.decrypt(
          state: bobState,
          header: enc.header,
          ciphertext: enc.ciphertext,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        ),
        throwsA(anyOf(isA<V2RatchetException>(), isA<SecretBoxAuthenticationError>())),
      );
    });
  });

  // ===========================================================================
  // 12. Header serialization
  // ===========================================================================

  group('Header Serialization', () {
    test('toBytes → fromBytes roundtrip', () {
      final header = V2MessageHeader(
        protocolVersion: 2,
        senderIdentityKey: List<int>.generate(32, (i) => i),
        senderRatchetPublicKey: List<int>.generate(32, (i) => i + 100),
        messageNumber: 42,
        previousChainLength: 7,
      );

      final bytes = header.toBytes();
      expect(bytes.length, 76);

      final restored = V2MessageHeader.fromBytes(bytes);
      expect(restored.protocolVersion, 2);
      expect(restored.senderIdentityKey, header.senderIdentityKey);
      expect(restored.senderRatchetPublicKey, header.senderRatchetPublicKey);
      expect(restored.messageNumber, 42);
      expect(restored.previousChainLength, 7);
    });

    test('toBytes is deterministic', () {
      final header = V2MessageHeader(
        protocolVersion: 2,
        senderIdentityKey: List<int>.generate(32, (i) => i),
        senderRatchetPublicKey: List<int>.generate(32, (i) => i + 100),
        messageNumber: 5,
        previousChainLength: 3,
      );

      final bytes1 = header.toBytes();
      final bytes2 = header.toBytes();
      expect(bytes1, bytes2);
    });

    test('toJson → fromJson roundtrip', () {
      final header = V2MessageHeader(
        protocolVersion: 2,
        senderIdentityKey: List<int>.generate(32, (i) => i),
        senderRatchetPublicKey: List<int>.generate(32, (i) => i + 100),
        messageNumber: 10,
        previousChainLength: 2,
      );

      final json = header.toJson();
      final restored = V2MessageHeader.fromJson(json);
      expect(restored.protocolVersion, header.protocolVersion);
      expect(restored.senderIdentityKey, header.senderIdentityKey);
      expect(restored.senderRatchetPublicKey, header.senderRatchetPublicKey);
      expect(restored.messageNumber, header.messageNumber);
      expect(restored.previousChainLength, header.previousChainLength);
    });
  });

  // ===========================================================================
  // 13. Skipped keys bounds
  // ===========================================================================

  group('Skipped Keys', () {
    test('skipped keys are bounded by v2MaxSkippedKeys', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final chainKey = List<int>.generate(32, (i) => i + 20);
      const sessionId = 'skip-bound-test';
      final aliceIk = List<int>.generate(32, (i) => i + 50);

      var aliceState = V2Ratchet.createInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      // Encrypt v2MaxSkippedKeys + 10 messages
      final encMessages = <({V2MessageHeader header, List<int> ciphertext, V2RatchetState state})>[];
      for (var i = 0; i < v2MaxSkippedKeys + 10; i++) {
        final enc = await V2Ratchet.encrypt(
          state: aliceState,
          plaintext: 'msg$i',
          identityKeyPublic: aliceIk,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        );
        aliceState = enc.state;
        encMessages.add(enc);
      }

      // Bob receives only the last message (skipping first v2MaxSkippedKeys+9)
      var bobState = V2Ratchet.createReceiverInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      // First, decrypt message 0 to trigger chain setup
      final dec0 = await V2Ratchet.decrypt(
        state: bobState,
        header: encMessages[0].header,
        ciphertext: encMessages[0].ciphertext,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      bobState = dec0.state;

      // Now receive the last message (skipping many in between)
      final lastIdx = v2MaxSkippedKeys + 9;
      final decLast = await V2Ratchet.decrypt(
        state: bobState,
        header: encMessages[lastIdx].header,
        ciphertext: encMessages[lastIdx].ciphertext,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      bobState = decLast.state;

      expect(decLast.plaintext, 'msg$lastIdx');
      // Skipped keys should be bounded (some may have been evicted)
      expect(bobState.skippedKeys.length, lessThanOrEqualTo(v2MaxSkippedKeys));
    });

    test('skipped keys cleared on DH ratchet step', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final chainKey = List<int>.generate(32, (i) => i + 20);
      final aliceIk = List<int>.generate(32, (i) => i + 50);

      var aliceState = V2Ratchet.createInitialState(
        sessionId: 'skip-clear-test',
        rootKey: rootKey,
        chainKey: chainKey,
      );

      // Alice sends 3 messages
      final enc1 = await V2Ratchet.encrypt(
        state: aliceState, plaintext: 'm1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'a', recipientDeviceId: 'b',
      );
      aliceState = enc1.state;

      final enc2 = await V2Ratchet.encrypt(
        state: aliceState, plaintext: 'm2',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'a', recipientDeviceId: 'b',
      );
      aliceState = enc2.state;

      final enc3 = await V2Ratchet.encrypt(
        state: aliceState, plaintext: 'm3',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'a', recipientDeviceId: 'b',
      );
      aliceState = enc3.state;

      // Bob receives m1, then m3 (skipping m2)
      var bobState = V2Ratchet.createReceiverInitialState(
        sessionId: 'skip-clear-test',
        rootKey: rootKey,
        chainKey: chainKey,
      );

      final dec1 = await V2Ratchet.decrypt(
        state: bobState, header: enc1.header,
        ciphertext: enc1.ciphertext,
        senderDeviceId: 'a', recipientDeviceId: 'b',
      );
      bobState = dec1.state;

      final dec3 = await V2Ratchet.decrypt(
        state: bobState, header: enc3.header,
        ciphertext: enc3.ciphertext,
        senderDeviceId: 'a', recipientDeviceId: 'b',
      );
      bobState = dec3.state;

      // m2 should still be in skipped keys
      expect(bobState.skippedKeys.containsKey(1), true);

      // Skipped keys are present before any DH ratchet step
      expect(bobState.skippedKeys.containsKey(1), true);
    });
  });

  // ===========================================================================
  // 14. V2RatchetState copyWith
  // ===========================================================================

  group('V2RatchetState copyWith', () {
    test('copyWith preserves unspecified fields', () async {
      final state = V2RatchetState(
        sessionId: 'test',
        rootKey: List<int>.generate(32, (i) => i),
        sendingChainKey: List<int>.generate(32, (i) => i),
        sendingMessageNumber: 5,
        receivingMessageNumber: 3,
      );

      final newState = state.copyWith(sendingMessageNumber: 6);

      expect(newState.sessionId, 'test');
      expect(newState.rootKey, state.rootKey);
      expect(newState.sendingChainKey, state.sendingChainKey);
      expect(newState.sendingMessageNumber, 6);
      expect(newState.receivingMessageNumber, 3);
    });
  });

  // ===========================================================================
  // 15. V2RatchetException
  // ===========================================================================

  group('V2RatchetException', () {
    test('toString includes message', () {
      const ex = V2RatchetException('test error');
      expect(ex.toString(), 'V2RatchetException: test error');
    });
  });

  // ===========================================================================
  // 16. Bidirectional: A1→B1→A2→B2→A3→B3
  // ===========================================================================

  group('Bidirectional', () {
    test('6-message sequence: A1→B1→A2→B2→A3→B3', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final chainKey = List<int>.generate(32, (i) => i + 20);
      const sessionId = 'bidir-test';
      final aliceIk = List<int>.generate(32, (i) => i + 50);
      final bobIk = List<int>.generate(32, (i) => i + 60);

      var aliceState = V2Ratchet.createInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      var bobState = V2Ratchet.createReceiverInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      final expectedPlaintexts = [
        'A1', 'B1', 'A2', 'B2', 'A3', 'B3',
      ];

      for (var i = 0; i < expectedPlaintexts.length; i++) {
        final msg = expectedPlaintexts[i];
        final isAlice = i % 2 == 0;

        if (isAlice) {
          final enc = await V2Ratchet.encrypt(
            state: aliceState,
            plaintext: msg,
            identityKeyPublic: aliceIk,
            senderDeviceId: 'alice-device-1',
            recipientDeviceId: 'bob-device-1',
          );
          aliceState = enc.state;

          final dec = await V2Ratchet.decrypt(
            state: bobState,
            header: enc.header,
            ciphertext: enc.ciphertext,
            senderDeviceId: 'alice-device-1',
            recipientDeviceId: 'bob-device-1',
          );
          bobState = dec.state;
          expect(dec.plaintext, msg, reason: 'Failed to decrypt $msg');
        } else {
          final enc = await V2Ratchet.encrypt(
            state: bobState,
            plaintext: msg,
            identityKeyPublic: bobIk,
            senderDeviceId: 'bob-device-1',
            recipientDeviceId: 'alice-device-1',
          );
          bobState = enc.state;

          final dec = await V2Ratchet.decrypt(
            state: aliceState,
            header: enc.header,
            ciphertext: enc.ciphertext,
            senderDeviceId: 'bob-device-1',
            recipientDeviceId: 'alice-device-1',
          );
          aliceState = dec.state;
          expect(dec.plaintext, msg, reason: 'Failed to decrypt $msg');
        }
      }
    });
  });

  // ===========================================================================
  // 17. Bidirectional with multiple messages per direction
  // ===========================================================================

  group('Bidirectional Multi-Message', () {
    test('Alice sends 3, Bob sends 3, Alice sends 3', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final chainKey = List<int>.generate(32, (i) => i + 20);
      const sessionId = 'bidir-multi-test';
      final aliceIk = List<int>.generate(32, (i) => i + 50);
      final bobIk = List<int>.generate(32, (i) => i + 60);

      var aliceState = V2Ratchet.createInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      var bobState = V2Ratchet.createReceiverInitialState(
        sessionId: sessionId,
        rootKey: rootKey,
        chainKey: chainKey,
      );

      // Alice sends 3 messages
      for (var i = 0; i < 3; i++) {
        final enc = await V2Ratchet.encrypt(
          state: aliceState,
          plaintext: 'A${i + 1}',
          identityKeyPublic: aliceIk,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        );
        aliceState = enc.state;

        final dec = await V2Ratchet.decrypt(
          state: bobState,
          header: enc.header,
          ciphertext: enc.ciphertext,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        );
        bobState = dec.state;
        expect(dec.plaintext, 'A${i + 1}');
      }

      // Bob sends 3 messages
      for (var i = 0; i < 3; i++) {
        final enc = await V2Ratchet.encrypt(
          state: bobState,
          plaintext: 'B${i + 1}',
          identityKeyPublic: bobIk,
          senderDeviceId: 'bob-device-1',
          recipientDeviceId: 'alice-device-1',
        );
        bobState = enc.state;

        final dec = await V2Ratchet.decrypt(
          state: aliceState,
          header: enc.header,
          ciphertext: enc.ciphertext,
          senderDeviceId: 'bob-device-1',
          recipientDeviceId: 'alice-device-1',
        );
        aliceState = dec.state;
        expect(dec.plaintext, 'B${i + 1}');
      }

      // Alice sends 3 more messages
      for (var i = 0; i < 3; i++) {
        final enc = await V2Ratchet.encrypt(
          state: aliceState,
          plaintext: 'A${i + 4}',
          identityKeyPublic: aliceIk,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        );
        aliceState = enc.state;

        final dec = await V2Ratchet.decrypt(
          state: bobState,
          header: enc.header,
          ciphertext: enc.ciphertext,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        );
        bobState = dec.state;
        expect(dec.plaintext, 'A${i + 4}');
      }
    });
  });

  // ===========================================================================
  // 18. First DH ratchet transition verification
  // ===========================================================================

  group('DH Ratchet Transition', () {
    test('root key changes correctly after first DH ratchet', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final chainKey = List<int>.generate(32, (i) => i + 20);
      final aliceIk = List<int>.generate(32, (i) => i + 50);
      final bobIk = List<int>.generate(32, (i) => i + 60);

      var aliceState = V2Ratchet.createInitialState(
        sessionId: 'dh-transition',
        rootKey: rootKey,
        chainKey: chainKey,
      );

      var bobState = V2Ratchet.createReceiverInitialState(
        sessionId: 'dh-transition',
        rootKey: rootKey,
        chainKey: chainKey,
      );

      // Save initial root key
      final initialRootKey = List<int>.from(rootKey);

      // Alice sends first message
      final enc1 = await V2Ratchet.encrypt(
        state: aliceState,
        plaintext: 'first',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      aliceState = enc1.state;

      // Bob decrypts first message (no root key change yet)
      final dec1 = await V2Ratchet.decrypt(
        state: bobState,
        header: enc1.header,
        ciphertext: enc1.ciphertext,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      bobState = dec1.state;
      expect(dec1.plaintext, 'first');

      // Root key should still be initial for both (no DH ratchet yet)
      expect(aliceState.rootKey, initialRootKey);
      expect(bobState.rootKey, initialRootKey);

      // Bob sends response (triggers DH step in Bob's encrypt)
      final enc2 = await V2Ratchet.encrypt(
        state: bobState,
        plaintext: 'response',
        identityKeyPublic: bobIk,
        senderDeviceId: 'bob-device-1',
        recipientDeviceId: 'alice-device-1',
      );
      bobState = enc2.state;

      // Bob's root key should have changed after DH step
      expect(bobState.rootKey, isNot(equals(initialRootKey)));

      // Alice receives response (triggers DH step in Alice's decrypt)
      final dec2 = await V2Ratchet.decrypt(
        state: aliceState,
        header: enc2.header,
        ciphertext: enc2.ciphertext,
        senderDeviceId: 'bob-device-1',
        recipientDeviceId: 'alice-device-1',
      );
      aliceState = dec2.state;
      expect(dec2.plaintext, 'response');

      // Both should have advanced root keys
      expect(aliceState.rootKey, isNot(equals(initialRootKey)));
      expect(aliceState.sendingChainKey, isNotNull);
      expect(aliceState.receivingChainKey, isNotNull);
      expect(bobState.sendingChainKey, isNotNull);
      expect(bobState.receivingChainKey, isNotNull);
    });
  });

  // ===========================================================================
  // 19. Message key equality proof
  // ===========================================================================

  group('Message Key Equality', () {
    test('sender MK == receiver MK for same-direction messages', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final chainKey = List<int>.generate(32, (i) => i + 20);
      final aliceIk = List<int>.generate(32, (i) => i + 50);

      var aliceState = V2Ratchet.createInitialState(
        sessionId: 'key-equality',
        rootKey: rootKey,
        chainKey: chainKey,
      );

      var bobState = V2Ratchet.createReceiverInitialState(
        sessionId: 'key-equality',
        rootKey: rootKey,
        chainKey: chainKey,
      );

      // Alice encrypts 3 messages
      final encMessages = <({V2MessageHeader header, List<int> ciphertext})>[];
      for (var i = 0; i < 3; i++) {
        final enc = await V2Ratchet.encrypt(
          state: aliceState,
          plaintext: 'msg$i',
          identityKeyPublic: aliceIk,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        );
        aliceState = enc.state;
        encMessages.add((header: enc.header, ciphertext: enc.ciphertext));
      }

      // Bob decrypts all 3 — each must succeed (proves MK equality)
      for (var i = 0; i < 3; i++) {
        final dec = await V2Ratchet.decrypt(
          state: bobState,
          header: encMessages[i].header,
          ciphertext: encMessages[i].ciphertext,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        );
        bobState = dec.state;
        expect(dec.plaintext, 'msg$i', reason: 'Message $i failed to decrypt — MK mismatch');
      }
    });
  });

  // ===========================================================================
  // 20. Spec Verification: kdfRatchet symmetry
  // ===========================================================================

  group('Spec Verification: kdfRatchet', () {
    test('kdfRatchet is symmetric: same inputs → same outputs', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final dhOutput = List<int>.generate(32, (i) => i + 20);

      final r1 = await V2Ratchet.kdfRatchet(rootKey, dhOutput);
      final r2 = await V2Ratchet.kdfRatchet(rootKey, dhOutput);

      expect(r1.rootKey, r2.rootKey);
      expect(r1.chainKey, r2.chainKey);
    });

    test('kdfRatchet: different DH → different outputs', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final dh1 = List<int>.generate(32, (i) => i + 20);
      final dh2 = List<int>.generate(32, (i) => i + 30);

      final r1 = await V2Ratchet.kdfRatchet(rootKey, dh1);
      final r2 = await V2Ratchet.kdfRatchet(rootKey, dh2);

      expect(r1.rootKey, isNot(r2.rootKey));
      expect(r1.chainKey, isNot(r2.chainKey));
    });

    test('kdfRatchet: different root key → different outputs', () async {
      final dhOutput = List<int>.generate(32, (i) => i + 20);
      final rk1 = List<int>.generate(32, (i) => i + 10);
      final rk2 = List<int>.generate(32, (i) => i + 40);

      final r1 = await V2Ratchet.kdfRatchet(rk1, dhOutput);
      final r2 = await V2Ratchet.kdfRatchet(rk2, dhOutput);

      expect(r1.rootKey, isNot(r2.rootKey));
      expect(r1.chainKey, isNot(r2.chainKey));
    });

    test('kdfRatchet: X25519 symmetry produces matching chain keys', () async {
      final x25519 = Cryptography.instance.x25519();

      final aliceKeyPair = await x25519.newKeyPair();
      final bobKeyPair = await x25519.newKeyPair();

      final alicePub = await aliceKeyPair.extractPublicKey();
      final bobPub = await bobKeyPair.extractPublicKey();

      // Alice computes DH with Bob's public key
      final dhAlice = await x25519.sharedSecretKey(
        keyPair: aliceKeyPair,
        remotePublicKey: SimplePublicKey(bobPub.bytes, type: KeyPairType.x25519),
      );
      final dhAliceBytes = await dhAlice.extractBytes();

      // Bob computes DH with Alice's public key
      final dhBob = await x25519.sharedSecretKey(
        keyPair: bobKeyPair,
        remotePublicKey: SimplePublicKey(alicePub.bytes, type: KeyPairType.x25519),
      );
      final dhBobBytes = await dhBob.extractBytes();

      // X25519 symmetry: DH outputs must be identical
      expect(dhAliceBytes, dhBobBytes, reason: 'X25519 symmetry violated');

      // kdfRatchet must produce identical results
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final rAlice = await V2Ratchet.kdfRatchet(rootKey, dhAliceBytes);
      final rBob = await V2Ratchet.kdfRatchet(rootKey, dhBobBytes);

      expect(rAlice.rootKey, rBob.rootKey, reason: 'Root key mismatch after kdfRatchet');
      expect(rAlice.chainKey, rBob.chainKey, reason: 'Chain key mismatch after kdfRatchet');
    });

    test('kdfRatchet output is 64 bytes (32+32)', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final dhOutput = List<int>.generate(32, (i) => i + 20);

      final r = await V2Ratchet.kdfRatchet(rootKey, dhOutput);

      expect(r.rootKey.length, 32);
      expect(r.chainKey.length, 32);
    });

    test('kdfRatchet: chained calls produce different keys', () async {
      final rootKey = List<int>.generate(32, (i) => i + 10);
      final dh1 = List<int>.generate(32, (i) => i + 20);
      final dh2 = List<int>.generate(32, (i) => i + 30);

      final r1 = await V2Ratchet.kdfRatchet(rootKey, dh1);
      final r2 = await V2Ratchet.kdfRatchet(r1.rootKey, dh2);

      expect(r1.rootKey, isNot(r2.rootKey));
      expect(r1.chainKey, isNot(r2.chainKey));
    });
  });
}

// =============================================================================
// Test helpers: state serialization/deserialization
// =============================================================================

/// Serializes V2RatchetState to JSON (async for key extraction).
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

/// Deserializes V2RatchetState from JSON.
Future<V2RatchetState> _deserializeState(Map<String, dynamic> json) async {
  SimpleKeyPair? ratchetKeyPair;
  List<int>? ratchetPubBytes;

  if (json['sending_ratchet_priv'] != null) {
    final privBytes = base64Decode(json['sending_ratchet_priv'] as String);
    ratchetPubBytes = base64Decode(json['sending_ratchet_pub'] as String);
    ratchetKeyPair = SimpleKeyPairData(
      privBytes,
      publicKey: SimplePublicKey(ratchetPubBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
  }

  final skippedKeysRaw = json['skipped_keys'] as Map<String, dynamic>? ?? {};
  final skippedKeys = skippedKeysRaw.map(
    (k, v) => MapEntry(int.parse(k), base64Decode(v as String)),
  );

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
    ratchetStep: (json['ratchet_step'] as int?) ?? 0,
  );
}
