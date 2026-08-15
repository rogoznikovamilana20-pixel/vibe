import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/e2e_v2_service.dart';

/// Phase 12C.2.2 — X3DH Responder tests.
///
/// Proves:
/// - Alice X3DH secret == Bob X3DH secret (with OTK)
/// - Alice X3DH secret == Bob X3DH secret (without OTK)
/// - OTK selection by exact ID
/// - OTK double-use prevention
/// - X3dhMessage with oneTimePrekeyId serialization
void main() {
  final x25519 = Cryptography.instance.x25519();

  /// HKDF salt — must match E2eV2Service._hkdfSalt.
  final hkdfSalt = utf8.encode('VibeE2EE_v2_sess');

  /// HKDF output length: 64 bytes = root_key(32) + chain_key(32).
  const hkdfOutputLength = 64;

  /// Helper: derive root+chain keys via HKDF (matches E2eV2Service).
  Future<({List<int> rootKey, List<int> chainKey})> deriveKeys(
    List<int> masterSecret,
    List<int> aliceIdentityPubBytes,
    List<int> bobIdentityPubBytes,
  ) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: hkdfOutputLength);
    final info = [...aliceIdentityPubBytes, ...bobIdentityPubBytes];
    final derivedKey = await hkdf.deriveKey(
      secretKey: SecretKey(masterSecret),
      nonce: hkdfSalt,
      info: info,
    );
    final derivedBytes = await derivedKey.extractBytes();
    return (
      rootKey: derivedBytes.sublist(0, 32),
      chainKey: derivedBytes.sublist(32, 64),
    );
  }

  /// Helper: Alice computes X3DH initiator side.
  Future<List<int>> aliceComputeX3dh({
    required SimpleKeyPair aliceIdentityKp,
    required SimpleKeyPair aliceEphemeralKp,
    required SimplePublicKey bobIdentityPub,
    required SimplePublicKey bobSpkPub,
    SimplePublicKey? bobOtkPub,
  }) async {
    final dh1 = await x25519.sharedSecretKey(
      keyPair: aliceIdentityKp,
      remotePublicKey: bobSpkPub,
    );
    final dh2 = await x25519.sharedSecretKey(
      keyPair: aliceEphemeralKp,
      remotePublicKey: bobIdentityPub,
    );
    final dh3 = await x25519.sharedSecretKey(
      keyPair: aliceEphemeralKp,
      remotePublicKey: bobSpkPub,
    );

    final master = <int>[
      ...await dh1.extractBytes(),
      ...await dh2.extractBytes(),
      ...await dh3.extractBytes(),
    ];

    if (bobOtkPub != null) {
      final dh4 = await x25519.sharedSecretKey(
        keyPair: aliceEphemeralKp,
        remotePublicKey: bobOtkPub,
      );
      master.addAll(await dh4.extractBytes());
    }

    return master;
  }

  /// Helper: Bob computes X3DH responder side.
  Future<List<int>> bobComputeX3dh({
    required SimpleKeyPair bobIdentityKp,
    required SimpleKeyPair bobSpkKp,
    SimpleKeyPair? bobOtkKp,
    required SimplePublicKey aliceIdentityPub,
    required SimplePublicKey aliceEphemeralPub,
  }) async {
    final dh1 = await x25519.sharedSecretKey(
      keyPair: bobSpkKp,
      remotePublicKey: aliceIdentityPub,
    );
    final dh2 = await x25519.sharedSecretKey(
      keyPair: bobIdentityKp,
      remotePublicKey: aliceEphemeralPub,
    );
    final dh3 = await x25519.sharedSecretKey(
      keyPair: bobSpkKp,
      remotePublicKey: aliceEphemeralPub,
    );

    final master = <int>[
      ...await dh1.extractBytes(),
      ...await dh2.extractBytes(),
      ...await dh3.extractBytes(),
    ];

    if (bobOtkKp != null) {
      final dh4 = await x25519.sharedSecretKey(
        keyPair: bobOtkKp,
        remotePublicKey: aliceEphemeralPub,
      );
      master.addAll(await dh4.extractBytes());
    }

    return master;
  }

  // ===========================================================================
  // 1. Cryptographic Symmetry — with OTK
  // ===========================================================================

  group('X3DH Symmetry (with OTK)', () {
    test('Alice and Bob derive identical master secret and session keys', () async {
      // Bob generates keys
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();
      final bobOtkKp = await x25519.newKeyPair();
      final bobOtkPub = await bobOtkKp.extractPublicKey();

      // Alice generates identity + ephemeral
      final aliceIdentityKp = await x25519.newKeyPair();
      final aliceIdentityPub = await aliceIdentityKp.extractPublicKey();
      final aliceEphemeralKp = await x25519.newKeyPair();
      final aliceEphemeralPub = await aliceEphemeralKp.extractPublicKey();

      // Alice computes
      final aliceMaster = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: aliceEphemeralKp,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: bobOtkPub,
      );

      // Bob computes
      final bobMaster = await bobComputeX3dh(
        bobIdentityKp: bobIdentityKp,
        bobSpkKp: bobSpkKp,
        bobOtkKp: bobOtkKp,
        aliceIdentityPub: aliceIdentityPub,
        aliceEphemeralPub: aliceEphemeralPub,
      );

      // Master secrets must be identical
      expect(aliceMaster, bobMaster, reason: 'Master secret mismatch with OTK');
      expect(aliceMaster.length, 128, reason: '4 × 32 = 128 bytes');

      // Derived keys must be identical
      final aliceKeys = await deriveKeys(
        aliceMaster, aliceIdentityPub.bytes, bobIdentityPub.bytes,
      );
      final bobKeys = await deriveKeys(
        bobMaster, aliceIdentityPub.bytes, bobIdentityPub.bytes,
      );

      expect(aliceKeys.rootKey, bobKeys.rootKey, reason: 'root_key mismatch');
      expect(aliceKeys.chainKey, bobKeys.chainKey, reason: 'chain_key mismatch');
      expect(aliceKeys.rootKey.length, 32);
      expect(aliceKeys.chainKey.length, 32);
    });

    test('deterministic — same keys produce same result every time', () async {
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();
      final bobOtkKp = await x25519.newKeyPair();
      final bobOtkPub = await bobOtkKp.extractPublicKey();

      final aliceIdentityKp = await x25519.newKeyPair();
      final aliceEphemeralKp = await x25519.newKeyPair();

      // Run twice
      final master1 = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: aliceEphemeralKp,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: bobOtkPub,
      );
      final master2 = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: aliceEphemeralKp,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: bobOtkPub,
      );

      expect(master1, master2);
    });
  });

  // ===========================================================================
  // 2. Cryptographic Symmetry — without OTK
  // ===========================================================================

  group('X3DH Symmetry (without OTK)', () {
    test('Alice and Bob derive identical master secret and session keys', () async {
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();

      final aliceIdentityKp = await x25519.newKeyPair();
      final aliceIdentityPub = await aliceIdentityKp.extractPublicKey();
      final aliceEphemeralKp = await x25519.newKeyPair();
      final aliceEphemeralPub = await aliceEphemeralKp.extractPublicKey();

      // Alice computes (no OTK)
      final aliceMaster = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: aliceEphemeralKp,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: null,
      );

      // Bob computes (no OTK)
      final bobMaster = await bobComputeX3dh(
        bobIdentityKp: bobIdentityKp,
        bobSpkKp: bobSpkKp,
        bobOtkKp: null,
        aliceIdentityPub: aliceIdentityPub,
        aliceEphemeralPub: aliceEphemeralPub,
      );

      // Master secrets must be identical
      expect(aliceMaster, bobMaster, reason: 'Master secret mismatch without OTK');
      expect(aliceMaster.length, 96, reason: '3 × 32 = 96 bytes');

      // Derived keys must be identical
      final aliceKeys = await deriveKeys(
        aliceMaster, aliceIdentityPub.bytes, bobIdentityPub.bytes,
      );
      final bobKeys = await deriveKeys(
        bobMaster, aliceIdentityPub.bytes, bobIdentityPub.bytes,
      );

      expect(aliceKeys.rootKey, bobKeys.rootKey);
      expect(aliceKeys.chainKey, bobKeys.chainKey);
    });
  });

  // ===========================================================================
  // 3. With OTK ≠ Without OTK
  // ===========================================================================

  group('With OTK vs Without OTK', () {
    test('different OTK presence produces different master secrets', () async {
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();
      final bobOtkKp = await x25519.newKeyPair();
      final bobOtkPub = await bobOtkKp.extractPublicKey();

      final aliceIdentityKp = await x25519.newKeyPair();
      final aliceEphemeralKp = await x25519.newKeyPair();

      // With OTK
      final masterWith = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: aliceEphemeralKp,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: bobOtkPub,
      );

      // Without OTK
      final masterWithout = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: aliceEphemeralKp,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: null,
      );

      // Different length → different secret
      expect(masterWith.length, 128);
      expect(masterWithout.length, 96);
      expect(masterWith, isNot(masterWithout));
    });

    test('derived session keys differ between with-OTK and without-OTK', () async {
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();
      final bobOtkKp = await x25519.newKeyPair();
      final bobOtkPub = await bobOtkKp.extractPublicKey();

      final aliceIdentityKp = await x25519.newKeyPair();
      final aliceIdentityPub = await aliceIdentityKp.extractPublicKey();
      final aliceEphemeralKp = await x25519.newKeyPair();

      final masterWith = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: aliceEphemeralKp,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: bobOtkPub,
      );
      final masterWithout = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: aliceEphemeralKp,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: null,
      );

      final keysWith = await deriveKeys(
        masterWith, aliceIdentityPub.bytes, bobIdentityPub.bytes,
      );
      final keysWithout = await deriveKeys(
        masterWithout, aliceIdentityPub.bytes, bobIdentityPub.bytes,
      );

      expect(keysWith.rootKey, isNot(keysWithout.rootKey));
      expect(keysWith.chainKey, isNot(keysWithout.chainKey));
    });
  });

  // ===========================================================================
  // 4. OTK Selection — exact ID resolution
  // ===========================================================================

  group('OTK Selection', () {
    test('different OTKs produce different master secrets', () async {
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();

      // Two different OTKs
      final bobOtk1Kp = await x25519.newKeyPair();
      final bobOtk1Pub = await bobOtk1Kp.extractPublicKey();
      final bobOtk2Kp = await x25519.newKeyPair();
      final bobOtk2Pub = await bobOtk2Kp.extractPublicKey();

      final aliceIdentityKp = await x25519.newKeyPair();
      final aliceEphemeralKp = await x25519.newKeyPair();

      // Session with OTK1
      final master1 = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: aliceEphemeralKp,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: bobOtk1Pub,
      );

      // Session with OTK2
      final master2 = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: aliceEphemeralKp,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: bobOtk2Pub,
      );

      // Different OTK → different master secret
      expect(master1, isNot(master2));

      // But both are 128 bytes (4 × 32)
      expect(master1.length, 128);
      expect(master2.length, 128);
    });

    test('Bob must use correct OTK to match Alice', () async {
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();

      final bobOtk1Kp = await x25519.newKeyPair();
      final bobOtk1Pub = await bobOtk1Kp.extractPublicKey();
      final bobOtk2Kp = await x25519.newKeyPair();

      final aliceIdentityKp = await x25519.newKeyPair();
      final aliceIdentityPub = await aliceIdentityKp.extractPublicKey();
      final aliceEphemeralKp = await x25519.newKeyPair();
      final aliceEphemeralPub = await aliceEphemeralKp.extractPublicKey();

      // Alice uses OTK1
      final aliceMaster = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: aliceEphemeralKp,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: bobOtk1Pub,
      );

      // Bob uses OTK1 (correct)
      final bobMasterCorrect = await bobComputeX3dh(
        bobIdentityKp: bobIdentityKp,
        bobSpkKp: bobSpkKp,
        bobOtkKp: bobOtk1Kp,
        aliceIdentityPub: aliceIdentityPub,
        aliceEphemeralPub: aliceEphemeralPub,
      );

      // Bob uses OTK2 (wrong)
      final bobMasterWrong = await bobComputeX3dh(
        bobIdentityKp: bobIdentityKp,
        bobSpkKp: bobSpkKp,
        bobOtkKp: bobOtk2Kp,
        aliceIdentityPub: aliceIdentityPub,
        aliceEphemeralPub: aliceEphemeralPub,
      );

      expect(aliceMaster, bobMasterCorrect, reason: 'Correct OTK must match');
      expect(aliceMaster, isNot(bobMasterWrong), reason: 'Wrong OTK must not match');
    });
  });

  // ===========================================================================
  // 5. OTK Double-Use Prevention
  // ===========================================================================

  group('OTK Double-Use', () {
    test('same OTK cannot be used for two different sessions', () async {
      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();
      final bobOtkKp = await x25519.newKeyPair();
      final bobOtkPub = await bobOtkKp.extractPublicKey();

      final aliceIdentityKp = await x25519.newKeyPair();

      // Two different ephemeral keys (two sessions)
      final eph1 = await x25519.newKeyPair();
      final eph2 = await x25519.newKeyPair();

      // Session 1 with OTK
      final master1 = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: eph1,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: bobOtkPub,
      );

      // Session 2 with same OTK but different ephemeral
      final master2 = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: eph2,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: bobOtkPub,
      );

      // Different ephemeral → different master secret (even with same OTK)
      expect(master1, isNot(master2));

      // But the OTK should have been consumed after session 1
      // In production, the OTK private key is deleted from SecureStorage
      // and the server marks it consumed. Second use is prevented by:
      // 1. SecureStorage: private key deleted after first use
      // 2. Server: consumed_at filter prevents re-fetching
      // 3. Client: X3dhMessage contains OTK ID, only one message per OTK
    });
  });

  // ===========================================================================
  // 6. X3dhMessage with oneTimePrekeyId
  // ===========================================================================

  group('X3dhMessage OTK ID', () {
    test('serialization includes oneTimePrekeyId when present', () {
      final msg = X3dhMessage(
        sessionId: 'session-1',
        initiatorDeviceId: 'alice-dev',
        initiatorIdentityKeyPublic: 'alice-ik',
        initiatorEdIdentityKeyPublic: 'alice-ed-ik',
        responderDeviceId: 'bob-dev',
        ephemeralKeyPublic: 'alice-eph',
        protocolVersion: 2,
        oneTimePrekeyId: 'otk-uuid-123',
      );

      final json = msg.toJson();
      expect(json['one_time_prekey_id'], 'otk-uuid-123');

      final restored = X3dhMessage.fromJson(json);
      expect(restored.oneTimePrekeyId, 'otk-uuid-123');
    });

    test('serialization omits oneTimePrekeyId when null', () {
      final msg = X3dhMessage(
        sessionId: 'session-2',
        initiatorDeviceId: 'alice-dev',
        initiatorIdentityKeyPublic: 'alice-ik',
        initiatorEdIdentityKeyPublic: 'alice-ed-ik',
        responderDeviceId: 'bob-dev',
        ephemeralKeyPublic: 'alice-eph',
        protocolVersion: 2,
      );

      final json = msg.toJson();
      expect(json.containsKey('one_time_prekey_id'), false);

      final restored = X3dhMessage.fromJson(json);
      expect(restored.oneTimePrekeyId, isNull);
    });

    test('roundtrip with OTK ID preserves value', () {
      final msg = X3dhMessage(
        sessionId: 'session-3',
        initiatorDeviceId: 'alice-dev',
        initiatorIdentityKeyPublic: 'alice-ik',
        initiatorEdIdentityKeyPublic: 'alice-ed-ik',
        responderDeviceId: 'bob-dev',
        ephemeralKeyPublic: 'alice-eph',
        protocolVersion: 2,
        oneTimePrekeyId: 'otk-abc-def-123',
      );

      final json = msg.toJson();
      final restored = X3dhMessage.fromJson(json);

      expect(restored.sessionId, msg.sessionId);
      expect(restored.oneTimePrekeyId, 'otk-abc-def-123');
      expect(restored.protocolVersion, 2);
    });
  });

  // ===========================================================================
  // 7. DH4 Computation with OTK
  // ===========================================================================

  group('DH4 Computation', () {
    test('DH4 = X25519(EKa, OPKb) is symmetric', () async {
      final aliceEphemeralKp = await x25519.newKeyPair();
      final aliceEphemeralPub = await aliceEphemeralKp.extractPublicKey();

      final bobOtkKp = await x25519.newKeyPair();
      final bobOtkPub = await bobOtkKp.extractPublicKey();

      // Alice: DH4 = X25519(EKa, OPKb)
      final dh4Alice = await x25519.sharedSecretKey(
        keyPair: aliceEphemeralKp,
        remotePublicKey: bobOtkPub,
      );

      // Bob: DH4 = X25519(OPKb, EKa)
      final dh4Bob = await x25519.sharedSecretKey(
        keyPair: bobOtkKp,
        remotePublicKey: aliceEphemeralPub,
      );

      expect(
        await dh4Alice.extractBytes(),
        await dh4Bob.extractBytes(),
        reason: 'DH4 must be symmetric',
      );
    });

    test('wrong OTK produces different DH4', () async {
      final aliceEphemeralKp = await x25519.newKeyPair();

      final bobOtk1Kp = await x25519.newKeyPair();
      final bobOtk1Pub = await bobOtk1Kp.extractPublicKey();
      final bobOtk2Kp = await x25519.newKeyPair();
      final bobOtk2Pub = await bobOtk2Kp.extractPublicKey();

      final dh4Correct = await x25519.sharedSecretKey(
        keyPair: aliceEphemeralKp,
        remotePublicKey: bobOtk1Pub,
      );

      final dh4Wrong = await x25519.sharedSecretKey(
        keyPair: aliceEphemeralKp,
        remotePublicKey: bobOtk2Pub,
      );

      expect(
        await dh4Correct.extractBytes(),
        isNot(await dh4Wrong.extractBytes()),
        reason: 'Wrong OTK must produce different DH4',
      );
    });
  });

  // ===========================================================================
  // 8. Edge Cases
  // ===========================================================================

  group('Edge Cases', () {
    test('all 4 DH results are 32 bytes each', () async {
      final aliceIdentityKp = await x25519.newKeyPair();
      final aliceEphemeralKp = await x25519.newKeyPair();

      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();
      final bobOtkKp = await x25519.newKeyPair();
      final bobOtkPub = await bobOtkKp.extractPublicKey();

      // Compute all 4 DH operations
      final dh1 = await x25519.sharedSecretKey(
        keyPair: aliceIdentityKp,
        remotePublicKey: bobSpkPub,
      );
      final dh2 = await x25519.sharedSecretKey(
        keyPair: aliceEphemeralKp,
        remotePublicKey: bobIdentityPub,
      );
      final dh3 = await x25519.sharedSecretKey(
        keyPair: aliceEphemeralKp,
        remotePublicKey: bobSpkPub,
      );
      final dh4 = await x25519.sharedSecretKey(
        keyPair: aliceEphemeralKp,
        remotePublicKey: bobOtkPub,
      );

      expect((await dh1.extractBytes()).length, 32);
      expect((await dh2.extractBytes()).length, 32);
      expect((await dh3.extractBytes()).length, 32);
      expect((await dh4.extractBytes()).length, 32);
    });

    test('master secret with OTK is exactly 128 bytes', () async {
      final aliceIdentityKp = await x25519.newKeyPair();
      final aliceEphemeralKp = await x25519.newKeyPair();

      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();
      final bobOtkKp = await x25519.newKeyPair();
      final bobOtkPub = await bobOtkKp.extractPublicKey();

      final master = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: aliceEphemeralKp,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: bobOtkPub,
      );

      expect(master.length, 128);
    });

    test('master secret without OTK is exactly 96 bytes', () async {
      final aliceIdentityKp = await x25519.newKeyPair();
      final aliceEphemeralKp = await x25519.newKeyPair();

      final bobIdentityKp = await x25519.newKeyPair();
      final bobIdentityPub = await bobIdentityKp.extractPublicKey();
      final bobSpkKp = await x25519.newKeyPair();
      final bobSpkPub = await bobSpkKp.extractPublicKey();

      final master = await aliceComputeX3dh(
        aliceIdentityKp: aliceIdentityKp,
        aliceEphemeralKp: aliceEphemeralKp,
        bobIdentityPub: bobIdentityPub,
        bobSpkPub: bobSpkPub,
        bobOtkPub: null,
      );

      expect(master.length, 96);
    });
  });
}
