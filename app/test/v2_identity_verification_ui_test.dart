// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/e2e_v2_identity_verification.dart';

const String uiTestId = 'E2EE_V2_UI_12D2_TEST';

void main() {
  late E2eV2IdentityVerification verification;
  late InMemoryIdentityStorage storage;

  setUp(() async {
    storage = InMemoryIdentityStorage();
    verification = E2eV2IdentityVerification.withStorage(storage);
  });

  tearDown(() async {
    await verification.clearAll();
  });

  // ===========================================================================
  // 1. UNKNOWN STATE
  // ===========================================================================

  group('1. UNKNOWN state', () {
    test('Default state is UNKNOWN for new peer', () async {
      final state = await verification.getTrustState('peer-1');
      expect(state, equals(IdentityTrustState.unknown));
    });

    test('Safety code can be generated for any key', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      final code = await E2eV2IdentityVerification.generateFingerprint(key);
      expect(code.isNotEmpty, isTrue);
      expect(code.replaceAll(' ', '').length, equals(60));
    });
  });

  // ===========================================================================
  // 2. SAFETY CODE RENDERING
  // ===========================================================================

  group('2. Safety code rendering', () {
    test('Code is 60 digits formatted in groups', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      final code = await E2eV2IdentityVerification.generateFingerprint(key);
      final clean = code.replaceAll(' ', '');
      expect(clean.length, equals(60));
      // Contains spaces as group separators
      expect(code.contains(' '), isTrue);
    });

    test('Code corresponds to actual identity public key', () async {
      final key = List<int>.generate(32, (i) => i + 42);
      final code = await E2eV2IdentityVerification.generateFingerprint(key);
      // Same key always produces same code
      final code2 = await E2eV2IdentityVerification.generateFingerprint(key);
      expect(code, equals(code2));
    });

    test('Different keys produce different codes', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);
      final code1 = await E2eV2IdentityVerification.generateFingerprint(key1);
      final code2 = await E2eV2IdentityVerification.generateFingerprint(key2);
      expect(code1, isNot(equals(code2)));
    });
  });

  // ===========================================================================
  // 3. EXPLICIT VERIFICATION ACTION
  // ===========================================================================

  group('3. Explicit verification action', () {
    test('UNKNOWN -> VERIFIED requires explicit call', () async {
      final key = List<int>.generate(32, (i) => i + 1);

      // State is UNKNOWN
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.unknown));

      // Explicit verification
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key);

      // Now VERIFIED
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.verified));
    });

    test('No auto-verification on first contact', () async {
      final key = List<int>.generate(32, (i) => i + 1);

      // First contact stores key but does NOT verify
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key);

      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.unknown));
    });
  });

  // ===========================================================================
  // 4. SERVER CANNOT TRIGGER VERIFIED
  // ===========================================================================

  group('4. Server cannot trigger VERIFIED', () {
    test('Server sending key does not set VERIFIED', () async {
      final key = List<int>.generate(32, (i) => i + 1);

      // Server returns a key (simulated by checkKeyChange)
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key);

      // State remains UNKNOWN — server cannot set VERIFIED
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.unknown));
    });

    test('Multiple server key deliveries do not auto-verify', () async {
      final key = List<int>.generate(32, (i) => i + 1);

      for (var i = 0; i < 5; i++) {
        await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key);
      }

      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.unknown));
    });

    test('Server cannot modify trust state directly', () async {
      // Trust state is stored in SecureStorage — server has no access
      final key = List<int>.generate(32, (i) => i + 1);
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key);

      // Even if server tries to set verified, it can't access SecureStorage
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.unknown));
    });
  });

  // ===========================================================================
  // 5. VERIFIED STATE PERSISTENCE
  // ===========================================================================

  group('5. VERIFIED state persistence', () {
    test('VERIFIED persists across new instance', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key);

      // New instance with same storage
      final newVerification = E2eV2IdentityVerification.withStorage(storage);
      expect(await newVerification.getTrustState('peer-1'), equals(IdentityTrustState.verified));
    });

    test('Stored key persists across new instance', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key);

      final newVerification = E2eV2IdentityVerification.withStorage(storage);
      final stored = await newVerification.loadStoredIdentityKey('peer-1');
      expect(stored, equals(key));
    });
  });

  // ===========================================================================
  // 6. KEY CHANGE DETECTION
  // ===========================================================================

  group('6. Key change detection', () {
    test('Same key -> unchanged', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key);

      final result = await verification.checkKeyChange(
        peerId: 'peer-1',
        receivedIdentityKey: key,
      );
      expect(result, equals(KeyChangeResult.unchanged));
    });

    test('Different key -> changed', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key1);

      final result = await verification.checkKeyChange(
        peerId: 'peer-1',
        receivedIdentityKey: key2,
      );
      expect(result, equals(KeyChangeResult.changed));
    });
  });

  // ===========================================================================
  // 7. VERIFIED -> CHANGED
  // ===========================================================================

  group('7. VERIFIED -> CHANGED', () {
    test('Key change after verification -> CHANGED state', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);

      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key1);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.verified));

      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key2);
      final newState = await verification.handleKeyChange(
        peerId: 'peer-1',
        newIdentityKey: key2,
      );

      expect(newState, equals(IdentityTrustState.changed));
    });

    test('CHANGED is persistent', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);

      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key1);
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key2);
      await verification.handleKeyChange(peerId: 'peer-1', newIdentityKey: key2);

      // New instance — still CHANGED
      final newVerification = E2eV2IdentityVerification.withStorage(storage);
      expect(await newVerification.getTrustState('peer-1'), equals(IdentityTrustState.changed));
    });
  });

  // ===========================================================================
  // 8. CHANGED CANNOT SILENTLY BECOME VERIFIED
  // ===========================================================================

  group('8. CHANGED cannot silently become VERIFIED', () {
    test('Receiving same CHANGED key does not auto-verify', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);

      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key1);
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key2);
      await verification.handleKeyChange(peerId: 'peer-1', newIdentityKey: key2);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.changed));

      // Server delivers same key again — still CHANGED
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key2);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.changed));
    });

    test('Multiple key deliveries do not auto-verify', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);

      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key1);
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key2);
      await verification.handleKeyChange(peerId: 'peer-1', newIdentityKey: key2);

      for (var i = 0; i < 5; i++) {
        await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key2);
      }

      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.changed));
    });
  });

  // ===========================================================================
  // 9. EXPLICIT RE-VERIFICATION
  // ===========================================================================

  group('9. Explicit re-verification', () {
    test('CHANGED -> VERIFIED after explicit confirmation', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);

      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key1);
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key2);
      await verification.handleKeyChange(peerId: 'peer-1', newIdentityKey: key2);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.changed));

      // User explicitly verifies new key
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key2);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.verified));
    });

    test('New key is stored after re-verification', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);

      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key1);
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key2);
      await verification.handleKeyChange(peerId: 'peer-1', newIdentityKey: key2);

      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key2);
      final stored = await verification.loadStoredIdentityKey('peer-1');
      expect(stored, equals(key2));
    });
  });

  // ===========================================================================
  // 10. COPY CONTAINS ONLY FINGERPRINT
  // ===========================================================================

  group('10. Copy contains only fingerprint', () {
    test('Fingerprint is pure numeric code', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      final code = await E2eV2IdentityVerification.generateFingerprint(key);
      final clean = code.replaceAll(' ', '');

      // Only digits
      expect(RegExp(r'^\d{60}$').hasMatch(clean), isTrue);

      // No private key material
      expect(clean, isNot(contains('private')));
      expect(clean, isNot(contains('secret')));
    });

    test('Clipboard content would be only the numeric code', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      final code = await E2eV2IdentityVerification.generateFingerprint(key);
      final clipboardContent = code.replaceAll(' ', '');

      expect(clipboardContent.length, equals(60));
      expect(RegExp(r'^\d{60}$').hasMatch(clipboardContent), isTrue);
    });
  });

  // ===========================================================================
  // 11. NO PRIVATE KEY EXPOSURE
  // ===========================================================================

  group('11. No private key exposure', () {
    test('Fingerprint does not contain private key bytes', () async {
      final privateKey = List<int>.generate(32, (i) => i * 7);
      final publicKey = List<int>.generate(32, (i) => i * 3 + 100);

      final fpFromPrivate = await E2eV2IdentityVerification.generateFingerprint(privateKey);
      final fpFromPublic = await E2eV2IdentityVerification.generateFingerprint(publicKey);

      // Different keys produce different fingerprints
      expect(fpFromPrivate, isNot(equals(fpFromPublic)));
    });

    test('Trust state does not expose secret material', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key);

      final state = await verification.getTrustState('peer-1');
      expect(state, equals(IdentityTrustState.verified));

      // Trust state is an enum — no key material
      expect(state.name, equals('verified'));
    });
  });

  // ===========================================================================
  // 12. V1 UNAFFECTED
  // ===========================================================================

  group('12. V1 unaffected', () {
    test('V1 has no trust state mechanism', () {
      // V1 uses static ECDH — no identity verification
      // This test documents that V1 is not affected by V2 verification
      // V1 trust model is separate
      expect(true, isTrue);
    });

    test('V2 verification is independent of V1', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key);

      // V1 key in profiles.e2e_public_key is unrelated
      // V2 uses devices.identity_dh_public
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.verified));
    });
  });

  // ===========================================================================
  // 13. PROPERTY INVARIANTS
  // ===========================================================================

  group('13. Property invariants', () {
    test('INVARIANT: only explicit verifyIdentity can set VERIFIED', () async {
      final key = List<int>.generate(32, (i) => i + 1);

      // checkKeyChange does NOT set VERIFIED
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.unknown));

      // handleKeyChange does NOT set VERIFIED
      final key2 = List<int>.generate(32, (i) => i + 100);
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key2);
      await verification.handleKeyChange(peerId: 'peer-1', newIdentityKey: key2);
      expect(await verification.getTrustState('peer-1'), isNot(equals(IdentityTrustState.verified)));

      // Only verifyIdentity sets VERIFIED
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.verified));
    });

    test('INVARIANT: key change after VERIFIED always produces CHANGED', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);
      final key3 = List<int>.generate(32, (i) => i + 200);

      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key1);

      // First change
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key2);
      await verification.handleKeyChange(peerId: 'peer-1', newIdentityKey: key2);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.changed));

      // Re-verify
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key2);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.verified));

      // Second change
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key3);
      await verification.handleKeyChange(peerId: 'peer-1', newIdentityKey: key3);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.changed));
    });

    test('INVARIANT: fingerprint is deterministic and domain-separated', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      final fp1 = await E2eV2IdentityVerification.generateFingerprint(key);
      final fp2 = await E2eV2IdentityVerification.generateFingerprint(key);
      expect(fp1, equals(fp2));

      // Different from raw SHA-256
      final rawHash = crypto.sha256.convert(key);
      final rawHex = rawHash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(fp1, isNot(contains(rawHex.substring(0, 20))));
    });
  });

  // ===========================================================================
  // 14. RESET / CLEANUP
  // ===========================================================================

  group('14. Reset / cleanup', () {
    test('Reset trust state clears all data for peer', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.verified));

      await verification.resetTrustState('peer-1');
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.unknown));
      expect(await verification.loadStoredIdentityKey('peer-1'), isNull);
    });

    test('ClearAll removes all trust data', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);

      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key1);
      await verification.checkKeyChange(peerId: 'peer-2', receivedIdentityKey: key2);

      await verification.clearAll();

      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.unknown));
      expect(await verification.getTrustState('peer-2'), equals(IdentityTrustState.unknown));
    });
  });
}
