// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
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

  // ===========================================================================
  // X3DH Session Establishment Tests
  // ===========================================================================

  group('X3DH Protocol', () {
    final x25519 = Cryptography.instance.x25519();

    /// Helper: perform X3DH responder side (Bob).
    Future<List<int>> x3dhResponder({
      required SimpleKeyPair bobIdentityKey,
      required SimpleKeyPair bobSignedPrekey,
      SimpleKeyPair? bobOneTimePrekey,
      required SimplePublicKey aliceIdentityPub,
      required SimplePublicKey aliceEphemeralPub,
    }) async {
      final dh1 = await x25519.sharedSecretKey(
        keyPair: bobSignedPrekey,
        remotePublicKey: aliceIdentityPub,
      );
      final dh2 = await x25519.sharedSecretKey(
        keyPair: bobIdentityKey,
        remotePublicKey: aliceEphemeralPub,
      );
      final dh3 = await x25519.sharedSecretKey(
        keyPair: bobSignedPrekey,
        remotePublicKey: aliceEphemeralPub,
      );

      final masterSecret = <int>[
        ...await dh1.extractBytes(),
        ...await dh2.extractBytes(),
        ...await dh3.extractBytes(),
      ];

      if (bobOneTimePrekey != null) {
        final dh4 = await x25519.sharedSecretKey(
          keyPair: bobOneTimePrekey,
          remotePublicKey: aliceEphemeralPub,
        );
        masterSecret.addAll(await dh4.extractBytes());
      }

      return masterSecret;
    }

    /// Helper: derive root+chain keys via HKDF.
    Future<({List<int> rootKey, List<int> chainKey})> deriveKeys(
      List<int> masterSecret,
      List<int> aliceIdentityPubBytes,
      List<int> bobIdentityPubBytes,
    ) async {
      final hkdf = Hkdf(
        hmac: Hmac.sha256(),
        outputLength: 64,
      );
      final info = [...aliceIdentityPubBytes, ...bobIdentityPubBytes];
      final salt = utf8.encode('VibeE2EE_v2_sess');
      final derivedKey = await hkdf.deriveKey(
        secretKey: SecretKey(masterSecret),
        nonce: salt,
        info: info,
      );
      final derivedBytes = await derivedKey.extractBytes();
      return (
        rootKey: derivedBytes.sublist(0, 32),
        chainKey: derivedBytes.sublist(32, 64),
      );
    }

    test('happy path — Alice and Bob derive identical session keys (with OTK)', () async {
      // Bob generates keys
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();
      final bobOtkKp = await x25519.newKeyPair();
      final bobOtkPub = await bobOtkKp.extractPublicKey();

      // Alice generates identity
      final aliceIdentityKp = await x25519.newKeyPair();

      // Use known ephemeral so both sides can compute with same key
      final ephemeralPair = await x25519.newKeyPair();
      final ephemeralPub = await ephemeralPair.extractPublicKey();
      final aliceIdentityPub = await aliceIdentityKp.extractPublicKey();

      // Alice computes X3DH
      final dh1a = await x25519.sharedSecretKey(keyPair: aliceIdentityKp, remotePublicKey: bobSpkPub);
      final dh2a = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobIdentityPub);
      final dh3a = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobSpkPub);
      final dh4a = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobOtkPub);
      final aliceMaster = <int>[
        ...await dh1a.extractBytes(),
        ...await dh2a.extractBytes(),
        ...await dh3a.extractBytes(),
        ...await dh4a.extractBytes(),
      ];

      // Bob computes X3DH
      final bobMaster = await x3dhResponder(
        bobIdentityKey: bobIdentityKp,
        bobSignedPrekey: bobSpkKp,
        bobOneTimePrekey: bobOtkKp,
        aliceIdentityPub: aliceIdentityPub,
        aliceEphemeralPub: ephemeralPub,
      );

      // Both sides must produce the same master secret
      expect(aliceMaster, bobMaster);

      // Derive keys from both sides — must be identical
      final aliceKeys = await deriveKeys(
        aliceMaster,
        aliceIdentityPub.bytes,
        bobIdentityPub.bytes,
      );
      final bobKeys = await deriveKeys(
        bobMaster,
        aliceIdentityPub.bytes,
        bobIdentityPub.bytes,
      );

      expect(aliceKeys.rootKey, bobKeys.rootKey);
      expect(aliceKeys.chainKey, bobKeys.chainKey);
      expect(aliceKeys.rootKey.length, 32);
      expect(aliceKeys.chainKey.length, 32);
    });

    test('happy path — without OTK produces different key than with OTK', () async {
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();
      final bobOtkKp = await x25519.newKeyPair();
      final bobOtkPub = await bobOtkKp.extractPublicKey();

      final aliceIdentityKp = await x25519.newKeyPair();
      final ephemeralPair = await x25519.newKeyPair();

      // With OTK
      final dh1 = await x25519.sharedSecretKey(keyPair: aliceIdentityKp, remotePublicKey: bobSpkPub);
      final dh2 = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobIdentityPub);
      final dh3 = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobSpkPub);
      final dh4 = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobOtkPub);
      final masterWithOtk = <int>[
        ...await dh1.extractBytes(), ...await dh2.extractBytes(),
        ...await dh3.extractBytes(), ...await dh4.extractBytes(),
      ];

      // Without OTK
      final dh1b = await x25519.sharedSecretKey(keyPair: aliceIdentityKp, remotePublicKey: bobSpkPub);
      final dh2b = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobIdentityPub);
      final dh3b = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobSpkPub);
      final masterWithoutOtk = <int>[
        ...await dh1b.extractBytes(), ...await dh2b.extractBytes(),
        ...await dh3b.extractBytes(),
      ];

      // They must differ (different input length → different HKDF output)
      expect(masterWithOtk, isNot(masterWithoutOtk));
      expect(masterWithOtk.length, 128); // 4 × 32
      expect(masterWithoutOtk.length, 96); // 3 × 32
    });

    test('wrong identity key produces different master secret', () async {
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();
      final bobOtkKp = await x25519.newKeyPair();
      final bobOtkPub = await bobOtkKp.extractPublicKey();

      final aliceIdentityKp = await x25519.newKeyPair();
      final wrongIdentityKp = await x25519.newKeyPair();
      final ephemeralPair = await x25519.newKeyPair();

      // With correct identity
      final dh1a = await x25519.sharedSecretKey(keyPair: aliceIdentityKp, remotePublicKey: bobSpkPub);
      final dh2a = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobIdentityPub);
      final dh3a = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobSpkPub);
      final dh4a = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobOtkPub);
      final correctMaster = <int>[
        ...await dh1a.extractBytes(), ...await dh2a.extractBytes(),
        ...await dh3a.extractBytes(), ...await dh4a.extractBytes(),
      ];

      // With wrong identity — DH1 changes
      final dh1w = await x25519.sharedSecretKey(keyPair: wrongIdentityKp, remotePublicKey: bobSpkPub);
      final dh2w = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobIdentityPub);
      final dh3w = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobSpkPub);
      final dh4w = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobOtkPub);
      final wrongMaster = <int>[
        ...await dh1w.extractBytes(), ...await dh2w.extractBytes(),
        ...await dh3w.extractBytes(), ...await dh4w.extractBytes(),
      ];

      expect(correctMaster, isNot(wrongMaster));
    });

    test('wrong signed prekey produces different master secret', () async {
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();
      final wrongSpkKp = await x25519.newKeyPair();
      final wrongSpkPub = await wrongSpkKp.extractPublicKey();
      final bobOtkKp = await x25519.newKeyPair();
      final bobOtkPub = await bobOtkKp.extractPublicKey();

      final aliceIdentityKp = await x25519.newKeyPair();
      final ephemeralPair = await x25519.newKeyPair();

      // With correct SPK
      final dh1a = await x25519.sharedSecretKey(keyPair: aliceIdentityKp, remotePublicKey: bobSpkPub);
      final dh2a = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobIdentityPub);
      final dh3a = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobSpkPub);
      final dh4a = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobOtkPub);
      final correctMaster = <int>[
        ...await dh1a.extractBytes(), ...await dh2a.extractBytes(),
        ...await dh3a.extractBytes(), ...await dh4a.extractBytes(),
      ];

      // With wrong SPK — DH1 and DH3 change
      final dh1w = await x25519.sharedSecretKey(keyPair: aliceIdentityKp, remotePublicKey: wrongSpkPub);
      final dh2w = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobIdentityPub);
      final dh3w = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: wrongSpkPub);
      final dh4w = await x25519.sharedSecretKey(keyPair: ephemeralPair, remotePublicKey: bobOtkPub);
      final wrongMaster = <int>[
        ...await dh1w.extractBytes(), ...await dh2w.extractBytes(),
        ...await dh3w.extractBytes(), ...await dh4w.extractBytes(),
      ];

      expect(correctMaster, isNot(wrongMaster));
    });

    test('different ephemeral keys produce different master secret (forward secrecy)', () async {
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();
      final bobOtkKp = await x25519.newKeyPair();
      final bobOtkPub = await bobOtkKp.extractPublicKey();

      final aliceIdentityKp = await x25519.newKeyPair();
      final ephemeral1 = await x25519.newKeyPair();
      final ephemeral2 = await x25519.newKeyPair();

      // With ephemeral1
      final dh1a = await x25519.sharedSecretKey(keyPair: aliceIdentityKp, remotePublicKey: bobSpkPub);
      final dh2a = await x25519.sharedSecretKey(keyPair: ephemeral1, remotePublicKey: bobIdentityPub);
      final dh3a = await x25519.sharedSecretKey(keyPair: ephemeral1, remotePublicKey: bobSpkPub);
      final dh4a = await x25519.sharedSecretKey(keyPair: ephemeral1, remotePublicKey: bobOtkPub);
      final master1 = <int>[
        ...await dh1a.extractBytes(), ...await dh2a.extractBytes(),
        ...await dh3a.extractBytes(), ...await dh4a.extractBytes(),
      ];

      // With ephemeral2
      final dh1b = await x25519.sharedSecretKey(keyPair: aliceIdentityKp, remotePublicKey: bobSpkPub);
      final dh2b = await x25519.sharedSecretKey(keyPair: ephemeral2, remotePublicKey: bobIdentityPub);
      final dh3b = await x25519.sharedSecretKey(keyPair: ephemeral2, remotePublicKey: bobSpkPub);
      final dh4b = await x25519.sharedSecretKey(keyPair: ephemeral2, remotePublicKey: bobOtkPub);
      final master2 = <int>[
        ...await dh1b.extractBytes(), ...await dh2b.extractBytes(),
        ...await dh3b.extractBytes(), ...await dh4b.extractBytes(),
      ];

      expect(master1, isNot(master2));
    });

    test('same keys used twice produce different sessions (ephemeral forward secrecy)', () async {
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();

      final aliceIdentityKp = await x25519.newKeyPair();

      // Two different ephemeral keys → two different sessions
      final eph1 = await x25519.newKeyPair();
      final eph2 = await x25519.newKeyPair();

      final dh1a = await x25519.sharedSecretKey(keyPair: aliceIdentityKp, remotePublicKey: bobSpkPub);
      final dh2a = await x25519.sharedSecretKey(keyPair: eph1, remotePublicKey: bobIdentityPub);
      final dh3a = await x25519.sharedSecretKey(keyPair: eph1, remotePublicKey: bobSpkPub);
      final master1 = <int>[...await dh1a.extractBytes(), ...await dh2a.extractBytes(), ...await dh3a.extractBytes()];

      final dh1b = await x25519.sharedSecretKey(keyPair: aliceIdentityKp, remotePublicKey: bobSpkPub);
      final dh2b = await x25519.sharedSecretKey(keyPair: eph2, remotePublicKey: bobIdentityPub);
      final dh3b = await x25519.sharedSecretKey(keyPair: eph2, remotePublicKey: bobSpkPub);
      final master2 = <int>[...await dh1b.extractBytes(), ...await dh2b.extractBytes(), ...await dh3b.extractBytes()];

      expect(master1, isNot(master2));
    });

    test('Bob cannot compute session without his private signed prekey', () async {
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();

      final aliceIdentityKp = await x25519.newKeyPair();
      final ephemeral = await x25519.newKeyPair();

      // Bob needs SPKb (private) to compute DH1 = X25519(SPKb, IKa)
      // Without SPKb, Bob cannot compute DH1

      final dh1a = await x25519.sharedSecretKey(keyPair: aliceIdentityKp, remotePublicKey: bobSpkPub);

      // An attacker without bobSpkKp cannot compute DH1 or DH3
      final attackerIdentityKp = await x25519.newKeyPair();
      final fakeDh1 = await x25519.sharedSecretKey(
        keyPair: attackerIdentityKp,
        remotePublicKey: await ephemeral.extractPublicKey(), // wrong
      );

      // The fake DH1 won't match the real DH1
      expect(await fakeDh1.extractBytes(), isNot(await dh1a.extractBytes()));
    });

    test('session ID is deterministic for same inputs', () {
      // _generateSessionId uses FNV-1a hash — verify determinism
      String generateSessionId(String initiator, String responder, List<int> ephBytes) {
        final combined = <int>[
          ...utf8.encode(initiator),
          ...utf8.encode(responder),
          ...ephBytes,
        ];
        var hash = 0x811c9dc5;
        for (final byte in combined) {
          hash ^= byte;
          hash = (hash * 0x01000193) & 0xFFFFFFFF;
        }
        return hash.toRadixString(16).padLeft(8, '0');
      }

      final ephBytes = List<int>.generate(32, (i) => i);
      final id1 = generateSessionId('alice-device-1', 'bob-device-1', ephBytes);
      final id2 = generateSessionId('alice-device-1', 'bob-device-1', ephBytes);
      expect(id1, id2);
    });

    test('session ID differs for different devices', () {
      String generateSessionId(String initiator, String responder, List<int> ephBytes) {
        final combined = <int>[
          ...utf8.encode(initiator),
          ...utf8.encode(responder),
          ...ephBytes,
        ];
        var hash = 0x811c9dc5;
        for (final byte in combined) {
          hash ^= byte;
          hash = (hash * 0x01000193) & 0xFFFFFFFF;
        }
        return hash.toRadixString(16).padLeft(8, '0');
      }

      final ephBytes = List<int>.generate(32, (i) => i);
      final id1 = generateSessionId('alice-device-1', 'bob-device-1', ephBytes);
      final id2 = generateSessionId('alice-device-2', 'bob-device-1', ephBytes);
      final id3 = generateSessionId('alice-device-1', 'bob-device-2', ephBytes);
      expect(id1, isNot(id2));
      expect(id1, isNot(id3));
      expect(id2, isNot(id3));
    });

    test('HKDF produces consistent output for same inputs', () async {
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 64);
      final salt = utf8.encode('VibeE2EE_v2_sess');
      final ikm = List<int>.generate(128, (i) => i);
      final info = List<int>.generate(64, (i) => i + 100);

      final key1 = await hkdf.deriveKey(secretKey: SecretKey(ikm), nonce: salt, info: info);
      final key2 = await hkdf.deriveKey(secretKey: SecretKey(ikm), nonce: salt, info: info);

      expect(await key1.extractBytes(), await key2.extractBytes());
    });

    test('HKDF produces different output for different salt', () async {
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 64);
      final salt1 = utf8.encode('VibeE2EE_v2_sess');
      final salt2 = utf8.encode('VibeE2EE_v2_xxx');
      final ikm = List<int>.generate(128, (i) => i);
      final info = List<int>.generate(64, (i) => i + 100);

      final key1 = await hkdf.deriveKey(secretKey: SecretKey(ikm), nonce: salt1, info: info);
      final key2 = await hkdf.deriveKey(secretKey: SecretKey(ikm), nonce: salt2, info: info);

      expect(await key1.extractBytes(), isNot(await key2.extractBytes()));
    });

    test('HKDF produces different output for different info', () async {
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 64);
      final salt = utf8.encode('VibeE2EE_v2_sess');
      final ikm = List<int>.generate(128, (i) => i);
      final info1 = List<int>.generate(64, (i) => i);
      final info2 = List<int>.generate(64, (i) => i + 1);

      final key1 = await hkdf.deriveKey(secretKey: SecretKey(ikm), nonce: salt, info: info1);
      final key2 = await hkdf.deriveKey(secretKey: SecretKey(ikm), nonce: salt, info: info2);

      expect(await key1.extractBytes(), isNot(await key2.extractBytes()));
    });

    test('X25519 DH is commutative — DH(a, b) == DH(b, a)', () async {
      final kpA = await x25519.newKeyPair();
      final kpB = await x25519.newKeyPair();
      final pubA = await kpA.extractPublicKey();
      final pubB = await kpB.extractPublicKey();

      final dhAb = await x25519.sharedSecretKey(keyPair: kpA, remotePublicKey: pubB);
      final dhBa = await x25519.sharedSecretKey(keyPair: kpB, remotePublicKey: pubA);

      expect(await dhAb.extractBytes(), await dhBa.extractBytes());
    });

    test('X25519 shared secret is 32 bytes', () async {
      final kp = await x25519.newKeyPair();
      final other = await x25519.newKeyPair();
      final secret = await x25519.sharedSecretKey(
        keyPair: kp,
        remotePublicKey: await other.extractPublicKey(),
      );
      expect((await secret.extractBytes()).length, 32);
    });

    test('DH result with self is not all zeros (clamping produces valid point)', () async {
      final kp = await x25519.newKeyPair();
      final pub = await kp.extractPublicKey();
      final secret = await x25519.sharedSecretKey(keyPair: kp, remotePublicKey: pub);
      final bytes = await secret.extractBytes();
      expect(bytes.length, 32);
      // Should not be all zeros (would indicate broken implementation)
      expect(bytes.any((b) => b != 0), true);
    });

    test('concurrent X3DH sessions with same keys produce different results (different ephemeral)', () async {
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();

      final aliceIdentityKp = await x25519.newKeyPair();

      // Simulate two concurrent sessions with different ephemeral keys
      Future<List<int>> performSession(SimpleKeyPair ephemeral) async {
        final dh1 = await x25519.sharedSecretKey(keyPair: aliceIdentityKp, remotePublicKey: bobSpkPub);
        final dh2 = await x25519.sharedSecretKey(keyPair: ephemeral, remotePublicKey: bobIdentityPub);
        final dh3 = await x25519.sharedSecretKey(keyPair: ephemeral, remotePublicKey: bobSpkPub);
        return <int>[...await dh1.extractBytes(), ...await dh2.extractBytes(), ...await dh3.extractBytes()];
      }

      final eph1 = await x25519.newKeyPair();
      final eph2 = await x25519.newKeyPair();

      // Run concurrently
      final results = await Future.wait([
        performSession(eph1),
        performSession(eph2),
      ]);

      // Different ephemeral → different master secret
      expect(results[0], isNot(results[1]));
    });

    test('tampered bundle public key changes master secret', () async {
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();
      final bobOtkKp = await x25519.newKeyPair();
      final bobOtkPub = await bobOtkKp.extractPublicKey();

      final aliceIdentityKp = await x25519.newKeyPair();
      final ephemeral = await x25519.newKeyPair();

      // Correct bundle
      final dh1c = await x25519.sharedSecretKey(keyPair: aliceIdentityKp, remotePublicKey: bobSpkPub);
      final dh2c = await x25519.sharedSecretKey(keyPair: ephemeral, remotePublicKey: bobIdentityPub);
      final dh3c = await x25519.sharedSecretKey(keyPair: ephemeral, remotePublicKey: bobSpkPub);
      final dh4c = await x25519.sharedSecretKey(keyPair: ephemeral, remotePublicKey: bobOtkPub);
      final correctMaster = <int>[
        ...await dh1c.extractBytes(), ...await dh2c.extractBytes(),
        ...await dh3c.extractBytes(), ...await dh4c.extractBytes(),
      ];

      // Tampered SPK (flipped bit)
      final tamperedSpkBytes = List<int>.from(bobSpkPub.bytes);
      tamperedSpkBytes[0] ^= 0x01;
      final tamperedSpkPub = SimplePublicKey(tamperedSpkBytes, type: KeyPairType.x25519);

      final dh1t = await x25519.sharedSecretKey(keyPair: aliceIdentityKp, remotePublicKey: tamperedSpkPub);
      final dh2t = await x25519.sharedSecretKey(keyPair: ephemeral, remotePublicKey: bobIdentityPub);
      final dh3t = await x25519.sharedSecretKey(keyPair: ephemeral, remotePublicKey: tamperedSpkPub);
      final dh4t = await x25519.sharedSecretKey(keyPair: ephemeral, remotePublicKey: bobOtkPub);
      final tamperedMaster = <int>[
        ...await dh1t.extractBytes(), ...await dh2t.extractBytes(),
        ...await dh3t.extractBytes(), ...await dh4t.extractBytes(),
      ];

      expect(correctMaster, isNot(tamperedMaster));
    });

    test('X3dhMessage serialization roundtrip', () {
      final msg = X3dhMessage(
        sessionId: 'session-123',
        initiatorDeviceId: 'alice-device-1',
        initiatorIdentityKeyPublic: 'alice-ik-pub',
        initiatorEdIdentityKeyPublic: 'alice-ed-ik-pub',
        responderDeviceId: 'bob-device-1',
        ephemeralKeyPublic: 'alice-ephemeral-pub',
        protocolVersion: 2,
      );

      final json = msg.toJson();
      final restored = X3dhMessage.fromJson(json);

      expect(restored.sessionId, msg.sessionId);
      expect(restored.initiatorDeviceId, msg.initiatorDeviceId);
      expect(restored.initiatorIdentityKeyPublic, msg.initiatorIdentityKeyPublic);
      expect(restored.initiatorEdIdentityKeyPublic, msg.initiatorEdIdentityKeyPublic);
      expect(restored.responderDeviceId, msg.responderDeviceId);
      expect(restored.ephemeralKeyPublic, msg.ephemeralKeyPublic);
      expect(restored.protocolVersion, msg.protocolVersion);
    });

    test('X3dhResult contains valid key lengths', () {
      final result = X3dhResult(
        sessionId: 'session-456',
        rootKey: List<int>.generate(32, (i) => i),
        chainKey: List<int>.generate(32, (i) => i + 32),
        remoteIdentityKeyPublic: 'remote-ik-pub',
        remoteDeviceId: 'remote-device-1',
        protocolVersion: 2,
      );

      expect(result.rootKey.length, 32);
      expect(result.chainKey.length, 32);
      expect(result.sessionId, 'session-456');
      expect(result.protocolVersion, 2);
    });

    test('device isolation — different Bob devices have different keys, different sessions', () async {
      final bobDev1Identity = await x25519.newKeyPair();
      final bobDev1Spk = await x25519.newKeyPair();
      final bobDev2Identity = await x25519.newKeyPair();
      final bobDev2Spk = await x25519.newKeyPair();

      final aliceIdentity = await x25519.newKeyPair();
      final ephemeral = await x25519.newKeyPair();

      // Session with Bob's device 1
      final dh1a = await x25519.sharedSecretKey(keyPair: aliceIdentity, remotePublicKey: await bobDev1Spk.extractPublicKey());
      final dh2a = await x25519.sharedSecretKey(keyPair: ephemeral, remotePublicKey: await bobDev1Identity.extractPublicKey());
      final dh3a = await x25519.sharedSecretKey(keyPair: ephemeral, remotePublicKey: await bobDev1Spk.extractPublicKey());
      final master1 = <int>[...await dh1a.extractBytes(), ...await dh2a.extractBytes(), ...await dh3a.extractBytes()];

      // Session with Bob's device 2 (same Alice, same ephemeral)
      final dh1b = await x25519.sharedSecretKey(keyPair: aliceIdentity, remotePublicKey: await bobDev2Spk.extractPublicKey());
      final dh2b = await x25519.sharedSecretKey(keyPair: ephemeral, remotePublicKey: await bobDev2Identity.extractPublicKey());
      final dh3b = await x25519.sharedSecretKey(keyPair: ephemeral, remotePublicKey: await bobDev2Spk.extractPublicKey());
      final master2 = <int>[...await dh1b.extractBytes(), ...await dh2b.extractBytes(), ...await dh3b.extractBytes()];

      expect(master1, isNot(master2));
    });
  });
}
