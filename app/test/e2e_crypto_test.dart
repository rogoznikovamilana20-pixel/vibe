// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// Security test vectors for E2E crypto primitives.
/// Tests the underlying X25519 + AES-GCM operations used by E2eService.
void main() {
  final keyExchange = Cryptography.instance.x25519();
  final aesGcm = Cryptography.instance.aesGcm();

  Future<SecretKey> sharedSecret(
      SimpleKeyPair alice, SimplePublicKey bobPub) async {
    final secret = await keyExchange.sharedSecretKey(
      keyPair: alice,
      remotePublicKey: bobPub,
    );
    final bytes = await secret.extractBytes();
    return SecretKey(bytes.sublist(0, 32));
  }

  group('E2E roundtrip', () {
    test('encrypt → decrypt returns identical plaintext', () async {
      final alice = await keyExchange.newKeyPair();
      final bob = await keyExchange.newKeyPair();
      final bobPub = await bob.extractPublicKey();

      final secret = await sharedSecret(alice, bobPub);
      final nonce = aesGcm.newNonce();
      final plaintext = 'Hello, E2E!';

      final box = await aesGcm.encrypt(
        utf8.encode(plaintext),
        secretKey: secret,
        nonce: nonce,
      );

      // Bob computes same shared secret
      final alicePub = await alice.extractPublicKey();
      final bobSecret = await sharedSecret(bob, alicePub);

      final clear = await aesGcm.decrypt(
        SecretBox(box.cipherText, nonce: box.nonce, mac: box.mac),
        secretKey: bobSecret,
      );

      expect(utf8.decode(clear), plaintext);
    });
  });

  group('Tamper detection', () {
    test('modified ciphertext → decrypt fails', () async {
      final alice = await keyExchange.newKeyPair();
      final bob = await keyExchange.newKeyPair();
      final bobPub = await bob.extractPublicKey();

      final secret = await sharedSecret(alice, bobPub);
      final nonce = aesGcm.newNonce();

      final box = await aesGcm.encrypt(
        utf8.encode('secret'),
        secretKey: secret,
        nonce: nonce,
      );

      // Tamper: flip first byte of ciphertext
      final tampered = Uint8List.fromList(box.cipherText);
      tampered[0] ^= 0xFF;

      final alicePub = await alice.extractPublicKey();
      final bobSecret = await sharedSecret(bob, alicePub);

      expect(
        () => aesGcm.decrypt(
          SecretBox(tampered, nonce: box.nonce, mac: box.mac),
          secretKey: bobSecret,
        ),
        throwsA(anything),
      );
    });

    test('modified nonce → decrypt fails', () async {
      final alice = await keyExchange.newKeyPair();
      final bob = await keyExchange.newKeyPair();
      final bobPub = await bob.extractPublicKey();

      final secret = await sharedSecret(alice, bobPub);
      final nonce = aesGcm.newNonce();

      final box = await aesGcm.encrypt(
        utf8.encode('secret'),
        secretKey: secret,
        nonce: nonce,
      );

      // Tamper: flip first byte of nonce
      final tamperedNonce = Uint8List.fromList(box.nonce);
      tamperedNonce[0] ^= 0xFF;

      final alicePub = await alice.extractPublicKey();
      final bobSecret = await sharedSecret(bob, alicePub);

      expect(
        () => aesGcm.decrypt(
          SecretBox(box.cipherText, nonce: tamperedNonce, mac: box.mac),
          secretKey: bobSecret,
        ),
        throwsA(anything),
      );
    });

    test('modified MAC → decrypt fails', () async {
      final alice = await keyExchange.newKeyPair();
      final bob = await keyExchange.newKeyPair();
      final bobPub = await bob.extractPublicKey();

      final secret = await sharedSecret(alice, bobPub);
      final nonce = aesGcm.newNonce();

      final box = await aesGcm.encrypt(
        utf8.encode('secret'),
        secretKey: secret,
        nonce: nonce,
      );

      // Tamper: flip first byte of MAC
      final tamperedMac = Uint8List.fromList(box.mac.bytes);
      tamperedMac[0] ^= 0xFF;

      final alicePub = await alice.extractPublicKey();
      final bobSecret = await sharedSecret(bob, alicePub);

      expect(
        () => aesGcm.decrypt(
          SecretBox(box.cipherText, nonce: box.nonce, mac: Mac(tamperedMac)),
          secretKey: bobSecret,
        ),
        throwsA(anything),
      );
    });
  });

  group('Wrong key', () {
    test('wrong peer key → decrypt fails', () async {
      final alice = await keyExchange.newKeyPair();
      final bob = await keyExchange.newKeyPair();
      final charlie = await keyExchange.newKeyPair();
      final bobPub = await bob.extractPublicKey();

      // Alice encrypts for Bob
      final secret = await sharedSecret(alice, bobPub);
      final nonce = aesGcm.newNonce();
      final box = await aesGcm.encrypt(
        utf8.encode('secret for bob'),
        secretKey: secret,
        nonce: nonce,
      );

      // Charlie tries to decrypt (wrong key)
      final alicePub = await alice.extractPublicKey();
      final charlieSecret = await sharedSecret(charlie, alicePub);

      expect(
        () => aesGcm.decrypt(
          SecretBox(box.cipherText, nonce: box.nonce, mac: box.mac),
          secretKey: charlieSecret,
        ),
        throwsA(anything),
      );
    });
  });

  group('Nonce uniqueness', () {
    test('1000 generated nonces are all unique', () {
      final nonces = <String>{};
      for (var i = 0; i < 1000; i++) {
        final nonce = aesGcm.newNonce();
        final key = base64Encode(nonce);
        expect(nonces.contains(key), isFalse,
            reason: 'Nonce collision at iteration $i');
        nonces.add(key);
      }
      expect(nonces.length, 1000);
    });
  });

  group('Key agreement symmetry', () {
    test('Alice→Bob and Bob→Alice produce same shared secret', () async {
      final alice = await keyExchange.newKeyPair();
      final bob = await keyExchange.newKeyPair();

      final alicePub = await alice.extractPublicKey();
      final bobPub = await bob.extractPublicKey();

      final secretAB = await sharedSecret(alice, bobPub);
      final secretBA = await sharedSecret(bob, alicePub);

      final bytesAB = await secretAB.extractBytes();
      final bytesBA = await secretBA.extractBytes();

      expect(bytesAB, bytesBA);
    });
  });

  group('Static-static DH (no ephemeral)', () {
    test('same keypair always produces same shared secret', () async {
      final alice = await keyExchange.newKeyPair();
      final bob = await keyExchange.newKeyPair();
      final bobPub = await bob.extractPublicKey();

      final secret1 = await sharedSecret(alice, bobPub);
      final secret2 = await sharedSecret(alice, bobPub);

      final bytes1 = await secret1.extractBytes();
      final bytes2 = await secret2.extractBytes();

      expect(bytes1, bytes2,
          reason:
              'Static-static DH: same keys → same secret (no forward secrecy)');
    });
  });
}
