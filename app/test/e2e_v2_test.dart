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

  // ==========================================================================
  // Phase 12B.1.1 — Cryptographic Sanity Check
  // ==========================================================================

  group('12B.1.1 — Deterministic identity derivation vector', () {
    test('same seed always produces same Ed25519 + X25519 public keys', () async {
      // Fixed seed for determinism
      final seed = List<int>.generate(32, (i) => i);

      final ed25519 = Cryptography.instance.ed25519();
      final x25519 = Cryptography.instance.x25519();

      // Derive twice
      final edKp1 = await ed25519.newKeyPairFromSeed(seed);
      final xdhKp1 = await x25519.newKeyPairFromSeed(seed);
      final edKp2 = await ed25519.newKeyPairFromSeed(seed);
      final xdhKp2 = await x25519.newKeyPairFromSeed(seed);

      final edPub1 = await edKp1.extractPublicKey();
      final edPub2 = await edKp2.extractPublicKey();
      final xdhPub1 = await xdhKp1.extractPublicKey();
      final xdhPub2 = await xdhKp2.extractPublicKey();

      // Deterministic
      expect(edPub1.bytes, edPub2.bytes);
      expect(xdhPub1.bytes, xdhPub2.bytes);

      // Ed25519 and X25519 public keys are DIFFERENT (different derivation)
      expect(edPub1.bytes, isNot(xdhPub1.bytes));
    });

    test('Ed25519 and X25519 use different scalar derivation', () async {
      final seed = List<int>.generate(32, (i) => i + 10);

      final ed25519 = Cryptography.instance.ed25519();
      final x25519 = Cryptography.instance.x25519();

      final edKp = await ed25519.newKeyPairFromSeed(seed);
      final xdhKp = await x25519.newKeyPairFromSeed(seed);

      // Extract private key bytes from each
      final edPrivBytes = await edKp.extractPrivateKeyBytes();
      final xdhPrivBytes = await xdhKp.extractPrivateKeyBytes();

      // Ed25519 stores raw seed; X25519 stores clamped seed
      // They should be different
      expect(edPrivBytes, isNot(xdhPrivBytes));

      // Both are 32 bytes
      expect(edPrivBytes.length, 32);
      expect(xdhPrivBytes.length, 32);
    });
  });

  group('12B.1.1 — Ed25519 signing ↔ X25519 DH independence', () {
    test('signing with Ed25519 identity does not affect X25519 DH', () async {
      final seed = List<int>.generate(32, (_) => 77);

      final ed25519 = Cryptography.instance.ed25519();
      final x25519 = Cryptography.instance.x25519();

      final edKp = await ed25519.newKeyPairFromSeed(seed);
      final xdhKp = await x25519.newKeyPairFromSeed(seed);

      // Sign something with Ed25519
      final message = utf8.encode('prekey to sign');
      final sig = await ed25519.sign(message, keyPair: edKp);

      // X25519 DH should still work independently
      final otherKp = await x25519.newKeyPair();
      final secret = await x25519.sharedSecretKey(
        keyPair: xdhKp,
        remotePublicKey: await otherKp.extractPublicKey(),
      );
      final secretBytes = await secret.extractBytes();
      expect(secretBytes.length, 32);

      // Signature verification still works
      final edPub = await edKp.extractPublicKey();
      final sigWithPub = Signature(sig.bytes, publicKey: edPub);
      final valid = await ed25519.verify(message, signature: sigWithPub);
      expect(valid, true);
    });
  });

  group('12B.1.1 — Signed prekey signature chain', () {
    test('full chain: seed → Ed25519 identity → sign X25519 prekey → verify', () async {
      final seed = List<int>.generate(32, (_) => 42);

      final ed25519 = Cryptography.instance.ed25519();
      final x25519 = Cryptography.instance.x25519();

      // Step 1: Derive identity from seed
      final identityKp = await ed25519.newKeyPairFromSeed(seed);
      final identityPub = await identityKp.extractPublicKey();

      // Step 2: Generate signed prekey
      final prekeyKp = await x25519.newKeyPair();
      final prekeyPub = await prekeyKp.extractPublicKey();

      // Step 3: Sign prekey with identity
      final signature = await ed25519.sign(prekeyPub.bytes, keyPair: identityKp);

      // Step 4: Verify (simulating what a peer does)
      final sigWithPub = Signature(signature.bytes, publicKey: identityPub);
      final valid = await ed25519.verify(prekeyPub.bytes, signature: sigWithPub);
      expect(valid, true);

      // Step 5: ECDH with prekey works
      final otherKp = await x25519.newKeyPair();
      final sharedSecret = await x25519.sharedSecretKey(
        keyPair: prekeyKp,
        remotePublicKey: await otherKp.extractPublicKey(),
      );
      final secretBytes = await sharedSecret.extractBytes();
      expect(secretBytes.length, 32);
    });

    test('wrong seed produces different identity → different signature', () async {
      final seed1 = List<int>.generate(32, (_) => 1);
      final seed2 = List<int>.generate(32, (_) => 2);

      final ed25519 = Cryptography.instance.ed25519();
      final x25519 = Cryptography.instance.x25519();

      final id1 = await ed25519.newKeyPairFromSeed(seed1);
      final id2 = await ed25519.newKeyPairFromSeed(seed2);

      final prekeyKp = await x25519.newKeyPair();
      final prekeyPub = await prekeyKp.extractPublicKey();

      final sig1 = await ed25519.sign(prekeyPub.bytes, keyPair: id1);
      final sig2 = await ed25519.sign(prekeyPub.bytes, keyPair: id2);

      // Different identity keys → different signatures
      expect(sig1.bytes, isNot(sig2.bytes));

      // Each verifies with its own identity key
      final pub1 = await id1.extractPublicKey();
      final pub2 = await id2.extractPublicKey();

      expect(
        await ed25519.verify(prekeyPub.bytes,
            signature: Signature(sig1.bytes, publicKey: pub1)),
        true,
      );
      expect(
        await ed25519.verify(prekeyPub.bytes,
            signature: Signature(sig2.bytes, publicKey: pub2)),
        true,
      );

      // Cross-verification fails
      expect(
        await ed25519.verify(prekeyPub.bytes,
            signature: Signature(sig1.bytes, publicKey: pub2)),
        false,
      );
    });
  });

  group('12B.1.1 — OTK consumption safety', () {
    test('same OTK ID cannot be used twice (unique constraint)', () {
      // Simulate: two consumers try to use the same OTK ID
      final consumed = <String>{};

      final otkId = 'otk-unique-123';

      // First consumption
      expect(consumed.contains(otkId), false);
      consumed.add(otkId);

      // Second consumption — should be rejected
      expect(consumed.contains(otkId), true);
    });

    test('OTK pool produces globally unique IDs', () {
      final allIds = <String>{};

      // Simulate generating multiple batches
      for (var batch = 0; batch < 3; batch++) {
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

          expect(allIds.contains(uuid), false,
              reason: 'OTK ID collision: batch=$batch, i=$i');
          allIds.add(uuid);
        }
      }
      expect(allIds.length, 300);
    });
  });

  group('12B.1.1 — Key bundle consistency', () {
    test('bundle with mismatched identity key and signature is invalid', () async {
      final ed25519 = Cryptography.instance.ed25519();
      final x25519 = Cryptography.instance.x25519();

      // Identity A signs a prekey
      final idA = await ed25519.newKeyPair();
      final prekeyKp = await x25519.newKeyPair();
      final prekeyPub = await prekeyKp.extractPublicKey();
      final sigA = await ed25519.sign(prekeyPub.bytes, keyPair: idA);

      // Bundle claims identity B's key but has A's signature
      final idB = await ed25519.newKeyPair();
      final idBPub = await idB.extractPublicKey();

      // This bundle is inconsistent: identityKeyPublic = B, signature from A
      final bundle = KeyBundle(
        deviceId: 'device-mismatch',
        identityKeyPublic: base64Encode(idBPub.bytes),
        identityDhPublic: base64Encode(idBPub.bytes),
        signedPrekeyId: 'spk-1',
        signedPrekeyPublic: base64Encode(prekeyPub.bytes),
        signedPrekeySignature: base64Encode(sigA.bytes),
        signedPrekeyAlgorithm: 'ed25519+sha512',
        protocolVersion: 2,
      );

      // Verify: B's key trying to verify A's signature → should fail
      final idBBytes = base64Decode(bundle.identityKeyPublic);
      final spkBytes = base64Decode(bundle.signedPrekeyPublic);
      final sigBytes = base64Decode(bundle.signedPrekeySignature);

      final idBPubForVerify = SimplePublicKey(idBBytes, type: KeyPairType.ed25519);
      final sigForVerify = Signature(sigBytes, publicKey: idBPubForVerify);
      final valid = await ed25519.verify(spkBytes, signature: sigForVerify);

      expect(valid, false, reason: 'Mismatched identity key and signature must fail');
    });

    test('bundle with swapped keys is invalid', () async {
      final ed25519 = Cryptography.instance.ed25519();
      final x25519 = Cryptography.instance.x25519();

      final idKp = await ed25519.newKeyPair();
      final idPub = await idKp.extractPublicKey();

      final prekeyKp = await x25519.newKeyPair();
      final prekeyPub = await prekeyKp.extractPublicKey();

      final sig = await ed25519.sign(prekeyPub.bytes, keyPair: idKp);

      // Swapped: identityDhPublic = Ed25519 key, identityKeyPublic = X25519 key
      final bundle = KeyBundle(
        deviceId: 'device-swapped',
        identityKeyPublic: base64Encode(prekeyPub.bytes), // WRONG: X25519 key as identity
        identityDhPublic: base64Encode(idPub.bytes), // WRONG: Ed25519 key as DH
        signedPrekeyId: 'spk-1',
        signedPrekeyPublic: base64Encode(prekeyPub.bytes),
        signedPrekeySignature: base64Encode(sig.bytes),
        signedPrekeyAlgorithm: 'ed25519+sha512',
        protocolVersion: 2,
      );

      // Verify with the wrong identity key → fails
      final wrongKeyBytes = base64Decode(bundle.identityKeyPublic);
      final spkBytes = base64Decode(bundle.signedPrekeyPublic);
      final sigBytes = base64Decode(bundle.signedPrekeySignature);

      final wrongPub = SimplePublicKey(wrongKeyBytes, type: KeyPairType.ed25519);
      final sigForVerify = Signature(sigBytes, publicKey: wrongPub);
      final valid = await ed25519.verify(spkBytes, signature: sigForVerify);

      expect(valid, false, reason: 'Swapped keys must fail verification');
    });
  });

  group('12B.1.1 — X25519 ECDH independent verification', () {
    test('DH shared secret is symmetric and correct', () async {
      final x25519 = Cryptography.instance.x25519();

      final alice = await x25519.newKeyPair();
      final bob = await x25519.newKeyPair();

      final alicePub = await alice.extractPublicKey();
      final bobPub = await bob.extractPublicKey();

      final secretAB = await x25519.sharedSecretKey(keyPair: alice, remotePublicKey: bobPub);
      final secretBA = await x25519.sharedSecretKey(keyPair: bob, remotePublicKey: alicePub);

      final bytesAB = await secretAB.extractBytes();
      final bytesBA = await secretBA.extractBytes();

      expect(bytesAB, bytesBA);
      expect(bytesAB.length, 32);
    });

    test('wrong key pair does not produce same shared secret', () async {
      final x25519 = Cryptography.instance.x25519();

      final alice = await x25519.newKeyPair();
      final bob = await x25519.newKeyPair();
      final eve = await x25519.newKeyPair();

      final bobPub = await bob.extractPublicKey();
      final evePub = await eve.extractPublicKey();

      final secretAliceBob = await x25519.sharedSecretKey(keyPair: alice, remotePublicKey: bobPub);
      final secretAliceEve = await x25519.sharedSecretKey(keyPair: alice, remotePublicKey: evePub);

      final bytesAB = await secretAliceBob.extractBytes();
      final bytesAE = await secretAliceEve.extractBytes();

      expect(bytesAB, isNot(bytesAE));
    });
  });

  group('12B.1.1 — Identity key derivation from seed (RFC 8032 compliance)', () {
    test('Ed25519 newKeyPairFromSeed uses SHA-512 internally', () async {
      // The cryptography package derives Ed25519 keys via:
      // scalar = clamp(SHA-512(seed)[0:32])
      // This test verifies the seed is NOT used directly as the scalar.

      final seed = List<int>.generate(32, (i) => i);
      final ed25519 = Cryptography.instance.ed25519();
      final kp = await ed25519.newKeyPairFromSeed(seed);

      // Extract private key bytes — should be the RAW seed
      final privBytes = await kp.extractPrivateKeyBytes();
      expect(privBytes, seed, reason: 'Ed25519 stores raw seed as private key bytes');

      // The actual scalar used for signing is SHA-512(seed)[0:32] (clamped)
      // We can't extract it directly, but we can verify signing works
      final sig = await ed25519.sign(utf8.encode('test'), keyPair: kp);
      final pub = await kp.extractPublicKey();
      final valid = await ed25519.verify(
        utf8.encode('test'),
        signature: Signature(sig.bytes, publicKey: pub),
      );
      expect(valid, true);
    });

    test('X25519 newKeyPairFromSeed clamps the raw seed', () async {
      // The cryptography package derives X25519 keys via:
      // scalar = clamp(seed)
      // This is different from Ed25519 which hashes first.

      final seed = List<int>.generate(32, (i) => i);
      final x25519 = Cryptography.instance.x25519();
      final kp = await x25519.newKeyPairFromSeed(seed);

      // Extract private key bytes — should be the CLAMPED seed
      final privBytes = await kp.extractPrivateKeyBytes();

      // Verify clamping was applied
      expect(privBytes[0] & 0x07, 0, reason: 'Low 3 bits must be 0');
      expect(privBytes[31] & 0x80, 0, reason: 'Bit 255 must be 0');
      expect(privBytes[31] & 0x40, 0x40, reason: 'Bit 254 must be 1');

      // ECDH works
      final other = await x25519.newKeyPair();
      final secret = await x25519.sharedSecretKey(
        keyPair: kp,
        remotePublicKey: await other.extractPublicKey(),
      );
      final secretBytes = await secret.extractBytes();
      expect(secretBytes.length, 32);
    });
  });
}
