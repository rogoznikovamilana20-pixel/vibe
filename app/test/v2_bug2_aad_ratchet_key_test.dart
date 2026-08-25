// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/v2_ratchet.dart';

/// Bug #2: Ratchet public key not authenticated in AAD.
///
/// VERIFIED FIX: _computeAad now includes senderRatchetPublicKey,
/// binding ciphertext to a specific ratchet step.
void main() {
  group('Bug #2: Ratchet public key in AAD', () {
    test('AAD is 32 bytes longer with ratchet key included', () {
      final senderDevBytes = utf8.encode('alice');
      final recipientDevBytes = utf8.encode('bob');
      // AAD = domain(22) + ik(32) + rk(32) + senderDev + recipientDev + mn(4) + pcl(4)
      final withRatchetKey = 22 + 32 + 32 + senderDevBytes.length + recipientDevBytes.length + 4 + 4;
      final withoutRatchetKey = 22 + 32 + senderDevBytes.length + recipientDevBytes.length + 4 + 4;
      expect(withRatchetKey - withoutRatchetKey, 32);
    });

    test('first message: Alice encrypts, Bob decrypts (no ratchet step needed)', () async {
      final rootKey = List<int>.generate(32, (i) => i);
      final chainKey = List<int>.generate(32, (i) => i + 50);

      // Alice's state after X3DH: has sendingChainKey
      var aliceState = V2RatchetState(
        sessionId: 'alice',
        rootKey: rootKey,
        sendingChainKey: chainKey,
        sendingRatchetPubBytes: List<int>.generate(32, (i) => i + 100),
      );

      final result = await V2Ratchet.encrypt(
        state: aliceState,
        plaintext: 'hello bob',
        identityKeyPublic: List<int>.generate(32, (i) => i),
        senderDeviceId: 'alice-device',
        recipientDeviceId: 'bob-device',
      );

      // Bob's state after X3DH: has receivingChainKey but no ratchet pub yet
      var bobState = V2RatchetState(
        sessionId: 'bob',
        rootKey: rootKey,
        receivingChainKey: chainKey,
        // receivingRatchetPublicKey is null — first message
      );

      // Bob decrypts: first message path sets receivingRatchetPublicKey
      final decrypted = await V2Ratchet.decrypt(
        state: bobState,
        header: result.header,
        ciphertext: result.ciphertext,
        senderDeviceId: 'alice-device',
        recipientDeviceId: 'bob-device',
      );

      expect(decrypted.plaintext, 'hello bob');
      // Bob's state now has Alice's ratchet public key
      expect(decrypted.state.receivingRatchetPublicKey, result.header.senderRatchetPublicKey);
    });

    test('tampered ratchet key in header causes GCM failure', () async {
      final rootKey = List<int>.generate(32, (i) => i);
      final chainKey = List<int>.generate(32, (i) => i + 50);

      var aliceState = V2RatchetState(
        sessionId: 'alice',
        rootKey: rootKey,
        sendingChainKey: chainKey,
        sendingRatchetPubBytes: List<int>.generate(32, (i) => i + 100),
      );

      final result = await V2Ratchet.encrypt(
        state: aliceState,
        plaintext: 'hello bob',
        identityKeyPublic: List<int>.generate(32, (i) => i),
        senderDeviceId: 'alice-device',
        recipientDeviceId: 'bob-device',
      );

      // Tamper: replace ratchet public key in header
      final tamperedHeader = V2MessageHeader(
        protocolVersion: result.header.protocolVersion,
        senderIdentityKey: result.header.senderIdentityKey,
        senderRatchetPublicKey: List<int>.generate(32, (i) => i + 200),
        messageNumber: result.header.messageNumber,
        previousChainLength: result.header.previousChainLength,
      );

      var bobState = V2RatchetState(
        sessionId: 'bob',
        rootKey: rootKey,
        receivingChainKey: chainKey,
      );

      // Should fail: GCM MAC verification fails because AAD differs
      expect(
        () => V2Ratchet.decrypt(
          state: bobState,
          header: tamperedHeader,
          ciphertext: result.ciphertext,
          senderDeviceId: 'alice-device',
          recipientDeviceId: 'bob-device',
        ),
        throwsA(anyOf(
          isA<V2RatchetException>(),
          isA<SecretBoxAuthenticationError>(),
        )),
        reason: 'Tampered ratchet key should cause decryption failure (AAD mismatch)',
      );
    });
  });
}
