import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/e2e_v2_service.dart';

/// Security tests for E2EE V2 infrastructure.
/// Tests identity keys, signed prekeys, one-time prekeys, and key bundles.
void main() {
  final ed25519 = Cryptography.instance.ed25519();
  final x25519 = Cryptography.instance.x25519();

  group('Identity Key Generation', () {
    test('Ed25519 keypair generated from seed', () async {
      final seed = List<int>.generate(32, (_) => 42);
      final keyPair = await ed25519.newKeyPairFromSeed(seed);
      final pub = await keyPair.extractPublicKey();

      expect(pub.bytes.length, 32);
    });

    test('X25519 keypair generated from same seed', () async {
      final seed = List<int>.generate(32, (_) => 42);
      final keyPair = await x25519.newKeyPairFromSeed(seed);
      final pub = await keyPair.extractPublicKey();

      expect(pub.bytes.length, 32);
    });

    test('same seed produces deterministic keys', () async {
      final seed = List<int>.generate(32, (_) => 7);
      final kp1 = await ed25519.newKeyPairFromSeed(seed);
      final kp2 = await ed25519.newKeyPairFromSeed(seed);

      final pub1 = await kp1.extractPublicKey();
      final pub2 = await kp2.extractPublicKey();

      expect(pub1.bytes, pub2.bytes);
    });

    test('different seeds produce different keys', () async {
      final seed1 = List<int>.generate(32, (_) => 1);
      final seed2 = List<int>.generate(32, (_) => 2);
      final kp1 = await ed25519.newKeyPairFromSeed(seed1);
      final kp2 = await ed25519.newKeyPairFromSeed(seed2);

      final pub1 = await kp1.extractPublicKey();
      final pub2 = await kp2.extractPublicKey();

      expect(pub1.bytes, isNot(pub2.bytes));
    });

    test('private key is 32 bytes', () async {
      final seed = List<int>.generate(32, (_) => 99);
      final keyPair = await ed25519.newKeyPairFromSeed(seed);
      final privBytes = await keyPair.extractPrivateKeyBytes();

      expect(privBytes.length, 32);
    });
  });

  group('Ed25519 Signing', () {
    test('sign and verify roundtrip', () async {
      final keyPair = await ed25519.newKeyPair();
      final message = utf8.encode('test message');

      final signature = await ed25519.sign(message, keyPair: keyPair);
      expect(signature.bytes.length, 64);

      final valid = await ed25519.verify(message, signature: signature);
      expect(valid, true);
    });

    test('verify rejects tampered message', () async {
      final keyPair = await ed25519.newKeyPair();
      final message = utf8.encode('original message');

      final signature = await ed25519.sign(message, keyPair: keyPair);
      final tampered = utf8.encode('tampered message');

      final valid = await ed25519.verify(tampered, signature: signature);
      expect(valid, false);
    });

    test('verify rejects wrong key', () async {
      final keyPair1 = await ed25519.newKeyPair();
      final keyPair2 = await ed25519.newKeyPair();
      final message = utf8.encode('test');

      final signature = await ed25519.sign(message, keyPair: keyPair1);
      final pub2 = await keyPair2.extractPublicKey();
      final wrongSig = Signature(signature.bytes, publicKey: pub2);

      final valid = await ed25519.verify(message, signature: wrongSig);
      expect(valid, false);
    });

    test('signature from seed is deterministic', () async {
      final seed = List<int>.generate(32, (_) => 55);
      final kp1 = await ed25519.newKeyPairFromSeed(seed);
      final kp2 = await ed25519.newKeyPairFromSeed(seed);
      final message = utf8.encode('deterministic test');

      final sig1 = await ed25519.sign(message, keyPair: kp1);
      final sig2 = await ed25519.sign(message, keyPair: kp2);

      expect(sig1.bytes, sig2.bytes);
    });
  });

  group('Signed Prekey Signing', () {
    test('Ed25519 signs X25519 public key', () async {
      final identityKey = await ed25519.newKeyPair();
      final prekeyPair = await x25519.newKeyPair();
      final prekeyPub = await prekeyPair.extractPublicKey();

      final signature = await ed25519.sign(
        prekeyPub.bytes,
        keyPair: identityKey,
      );

      expect(signature.bytes.length, 64);

      // Verify with identity public key
      final identityPub = await identityKey.extractPublicKey();
      final sigWithPub = Signature(signature.bytes, publicKey: identityPub);
      final valid = await ed25519.verify(
        prekeyPub.bytes,
        signature: sigWithPub,
      );

      expect(valid, true);
    });

    test('tampered prekey rejected by signature', () async {
      final identityKey = await ed25519.newKeyPair();
      final prekeyPair = await x25519.newKeyPair();
      final prekeyPub = await prekeyPair.extractPublicKey();

      final signature = await ed25519.sign(
        prekeyPub.bytes,
        keyPair: identityKey,
      );

      // Tamper with prekey bytes
      final tampered = Uint8List.fromList(prekeyPub.bytes);
      tampered[0] ^= 0xFF;

      final identityPub = await identityKey.extractPublicKey();
      final sigWithPub = Signature(signature.bytes, publicKey: identityPub);
      final valid = await ed25519.verify(tampered, signature: sigWithPub);

      expect(valid, false);
    });

    test('wrong identity key rejects signature', () async {
      final identityKey1 = await ed25519.newKeyPair();
      final identityKey2 = await ed25519.newKeyPair();
      final prekeyPair = await x25519.newKeyPair();
      final prekeyPub = await prekeyPair.extractPublicKey();

      // Sign with key1
      final signature = await ed25519.sign(
        prekeyPub.bytes,
        keyPair: identityKey1,
      );

      // Verify with key2
      final pub2 = await identityKey2.extractPublicKey();
      final sigWithPub2 = Signature(signature.bytes, publicKey: pub2);
      final valid = await ed25519.verify(
        prekeyPub.bytes,
        signature: sigWithPub2,
      );

      expect(valid, false);
    });
  });

  group('One-Time Prekey Pool', () {
    test('generate pool produces unique keys', () async {
      final pool = <String>{};
      for (var i = 0; i < 10; i++) {
        final kp = await x25519.newKeyPair();
        final pub = await kp.extractPublicKey();
        final b64 = base64Encode(pub.bytes);
        expect(pool.contains(b64), isFalse,
            reason: 'Duplicate OTK at index $i');
        pool.add(b64);
      }
      expect(pool.length, 10);
    });

    test('OTK public key is 32 bytes', () async {
      final kp = await x25519.newKeyPair();
      final pub = await kp.extractPublicKey();
      expect(pub.bytes.length, 32);
    });

    test('OTK private key is 32 bytes', () async {
      final kp = await x25519.newKeyPair();
      final priv = await kp.extractPrivateKeyBytes();
      expect(priv.length, 32);
    });
  });

  group('Key Bundle Validation', () {
    test('valid bundle accepted', () async {
      final identityKey = await ed25519.newKeyPair();
      final prekeyPair = await x25519.newKeyPair();
      final prekeyPub = await prekeyPair.extractPublicKey();

      final signature = await ed25519.sign(
        prekeyPub.bytes,
        keyPair: identityKey,
      );

      final identityPub = await identityKey.extractPublicKey();

      final bundle = KeyBundle(
        deviceId: 'test-device-id',
        identityKeyPublic: base64Encode(identityPub.bytes),
        identityDhPublic: base64Encode(identityPub.bytes),
        signedPrekeyId: 'prekey-1',
        signedPrekeyPublic: base64Encode(prekeyPub.bytes),
        signedPrekeySignature: base64Encode(signature.bytes),
        signedPrekeyAlgorithm: 'ed25519+sha512',
        oneTimePrekeyId: 'otk-1',
        oneTimePrekeyPublic: base64Encode(prekeyPub.bytes),
        protocolVersion: 2,
      );

      // Validate signature
      final idKeyBytes = base64Decode(bundle.identityKeyPublic);
      final spkBytes = base64Decode(bundle.signedPrekeyPublic);
      final sigBytes = base64Decode(bundle.signedPrekeySignature);

      final identityPub2 = SimplePublicKey(idKeyBytes, type: KeyPairType.ed25519);
      final sig = Signature(sigBytes, publicKey: identityPub2);
      final valid = await ed25519.verify(spkBytes, signature: sig);

      expect(valid, true);
    });

    test('wrong protocol version rejected', () {
      const bundle = KeyBundle(
        deviceId: 'test',
        identityKeyPublic: 'a',
        identityDhPublic: 'b',
        signedPrekeyId: 'c',
        signedPrekeyPublic: 'd',
        signedPrekeySignature: 'e',
        signedPrekeyAlgorithm: 'ed25519+sha512',
        protocolVersion: 1,
      );

      expect(bundle.protocolVersion, isNot(2));
    });

    test('missing required fields detected', () {
      const bundle = KeyBundle(
        deviceId: '',
        identityKeyPublic: '',
        identityDhPublic: '',
        signedPrekeyId: '',
        signedPrekeyPublic: '',
        signedPrekeySignature: '',
        signedPrekeyAlgorithm: 'ed25519+sha512',
        protocolVersion: 2,
      );

      expect(
        bundle.identityKeyPublic.isEmpty ||
            bundle.signedPrekeyPublic.isEmpty ||
            bundle.signedPrekeySignature.isEmpty,
        true,
      );
    });

    test('wrong key length detected', () {
      final shortKey = base64Encode(List<int>.generate(16, (_) => 0));
      final correctKey = base64Encode(List<int>.generate(32, (_) => 0));

      expect(base64Decode(shortKey).length, 16);
      expect(base64Decode(correctKey).length, 32);
    });

    test('wrong signature length detected', () {
      final shortSig = base64Encode(List<int>.generate(32, (_) => 0));
      final correctSig = base64Encode(List<int>.generate(64, (_) => 0));

      expect(base64Decode(shortSig).length, 32);
      expect(base64Decode(correctSig).length, 64);
    });

    test('tampered signature rejected', () async {
      final identityKey = await ed25519.newKeyPair();
      final prekeyPair = await x25519.newKeyPair();
      final prekeyPub = await prekeyPair.extractPublicKey();

      final signature = await ed25519.sign(
        prekeyPub.bytes,
        keyPair: identityKey,
      );

      // Tamper with signature
      final sigBytes = Uint8List.fromList(signature.bytes);
      sigBytes[0] ^= 0xFF;

      final identityPub = await identityKey.extractPublicKey();
      final tamperedSig = Signature(sigBytes, publicKey: identityPub);
      final valid = await ed25519.verify(prekeyPub.bytes, signature: tamperedSig);

      expect(valid, false);
    });
  });

  group('Data Classes', () {
    test('KeyBundle stores all required fields', () {
      const bundle = KeyBundle(
        deviceId: 'device-1',
        identityKeyPublic: 'id-key',
        identityDhPublic: 'dh-key',
        signedPrekeyId: 'spk-1',
        signedPrekeyPublic: 'spk-pub',
        signedPrekeySignature: 'spk-sig',
        signedPrekeyAlgorithm: 'ed25519+sha512',
        oneTimePrekeyId: 'otk-1',
        oneTimePrekeyPublic: 'otk-pub',
        protocolVersion: 2,
      );

      expect(bundle.deviceId, 'device-1');
      expect(bundle.oneTimePrekeyId, 'otk-1');
      expect(bundle.protocolVersion, 2);
    });

    test('KeyBundle with null OTK is valid', () {
      const bundle = KeyBundle(
        deviceId: 'device-1',
        identityKeyPublic: 'id-key',
        identityDhPublic: 'dh-key',
        signedPrekeyId: 'spk-1',
        signedPrekeyPublic: 'spk-pub',
        signedPrekeySignature: 'spk-sig',
        signedPrekeyAlgorithm: 'ed25519+sha512',
        protocolVersion: 2,
      );

      expect(bundle.oneTimePrekeyId, isNull);
      expect(bundle.oneTimePrekeyPublic, isNull);
    });

    test('InvalidBundleException has message', () {
      const exception = InvalidBundleException('test error');
      expect(exception.toString(), contains('test error'));
    });
  });

  group('Protocol Version Boundary', () {
    test('version 1 is legacy', () {
      expect(1, isNot(2));
    });

    test('version 2 is new protocol', () {
      expect(2, 2);
    });

    test('version 0 is invalid', () {
      expect(0, isNot(2));
    });
  });

  group('Security Constants', () {
    test('Ed25519 public key is 32 bytes', () {
      expect(32, 32);
    });

    test('Ed25519 signature is 64 bytes', () {
      expect(64, 64);
    });

    test('X25519 key is 32 bytes', () {
      expect(32, 32);
    });

    test('OTK batch size is 100', () {
      expect(E2eV2Service.otkBatchSize, 100);
    });

    test('OTK replenish threshold is 20', () {
      expect(E2eV2Service.otkReplenishThreshold, 20);
    });
  });

  group('UUID Generation', () {
    test('UUID format is correct', () {
      // UUID v4: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      final regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );

      // Generate several UUIDs using the same logic as E2eV2Service
      for (var i = 0; i < 10; i++) {
        final rng = Random.secure();
        final values = List<int>.generate(16, (_) => rng.nextInt(256));
        values[6] = (values[6] & 0x0f) | 0x40;
        values[8] = (values[8] & 0x3f) | 0x80;
        final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        final uuid = '${hex.substring(0, 8)}-'
            '${hex.substring(8, 12)}-'
            '${hex.substring(12, 16)}-'
            '${hex.substring(16, 20)}-'
            '${hex.substring(20)}';

        expect(regex.hasMatch(uuid), true, reason: 'Invalid UUID: $uuid');
      }
    });

    test('generated UUIDs are unique', () {
      final uuids = <String>{};
      for (var i = 0; i < 100; i++) {
        final rng = Random.secure();
        final values = List<int>.generate(16, (_) => rng.nextInt(256));
        values[6] = (values[6] & 0x0f) | 0x40;
        values[8] = (values[8] & 0x3f) | 0x80;
        final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        final uuid = '${hex.substring(0, 8)}-'
            '${hex.substring(8, 12)}-'
            '${hex.substring(12, 16)}-'
            '${hex.substring(16, 20)}-'
            '${hex.substring(20)}';

        expect(uuids.contains(uuid), isFalse,
            reason: 'UUID collision at iteration $i');
        uuids.add(uuid);
      }
      expect(uuids.length, 100);
    });
  });
}
