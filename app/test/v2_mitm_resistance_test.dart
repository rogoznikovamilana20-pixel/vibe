import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:vibe_app/data/e2e_v2_identity_verification.dart';

const String mitmTestId = 'E2EE_V2_MITM_12D1_TEST';

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
  // 1. FINGERPRINT GENERATION
  // ===========================================================================

  group('1. Fingerprint generation', () {
    test('Deterministic: same key -> same fingerprint', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      final fp1 = await E2eV2IdentityVerification.generateFingerprint(key);
      final fp2 = await E2eV2IdentityVerification.generateFingerprint(key);
      expect(fp1, equals(fp2));
    });

    test('Different keys -> different fingerprints', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);
      final fp1 = await E2eV2IdentityVerification.generateFingerprint(key1);
      final fp2 = await E2eV2IdentityVerification.generateFingerprint(key2);
      expect(fp1, isNot(equals(fp2)));
    });

    test('Fingerprint is 60-digit numeric safety code', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      final fp = await E2eV2IdentityVerification.generateFingerprint(key);
      final cleanCode = fp.replaceAll(' ', '');
      expect(cleanCode.length, equals(60));
      expect(RegExp(r'^\d{60}$').hasMatch(cleanCode), isTrue);
    });

    test('Fingerprint uses domain separation', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      final fp = await E2eV2IdentityVerification.generateFingerprint(key);

      // Raw SHA-256(key) should differ from domain-separated fingerprint
      final sha256 = Sha256();
      final rawHash = await sha256.hash(key);
      final rawNumeric = _bytesToNumericString(rawHash.bytes, 25);
      final rawFp = _formatSafetyCode(rawNumeric);

      expect(fp, isNot(equals(rawFp)));
    });

    test('Base64 key generates same fingerprint', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      final keyB64 = base64Encode(key);
      final fp1 = await E2eV2IdentityVerification.generateFingerprint(key);
      final fp2 = await E2eV2IdentityVerification.generateFingerprintFromBase64(keyB64);
      expect(fp1, equals(fp2));
    });
  });

  // ===========================================================================
  // 2. TRUST STATE
  // ===========================================================================

  group('2. Trust state', () {
    test('Default state is UNKNOWN', () async {
      final state = await verification.getTrustState('peer-1');
      expect(state, equals(IdentityTrustState.unknown));
    });

    test('Set and get trust state', () async {
      await verification.setTrustState('peer-1', IdentityTrustState.verified);
      final state = await verification.getTrustState('peer-1');
      expect(state, equals(IdentityTrustState.verified));
    });

    test('Trust state transitions: UNKNOWN -> VERIFIED', () async {
      await verification.setTrustState('peer-1', IdentityTrustState.verified);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.verified));
    });

    test('Trust state transitions: VERIFIED -> CHANGED', () async {
      await verification.setTrustState('peer-1', IdentityTrustState.verified);
      await verification.setTrustState('peer-1', IdentityTrustState.changed);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.changed));
    });

    test('Trust state is per-peer', () async {
      await verification.setTrustState('peer-1', IdentityTrustState.verified);
      await verification.setTrustState('peer-2', IdentityTrustState.changed);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.verified));
      expect(await verification.getTrustState('peer-2'), equals(IdentityTrustState.changed));
    });

    test('Reset trust state', () async {
      await verification.setTrustState('peer-1', IdentityTrustState.verified);
      await verification.resetTrustState('peer-1');
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.unknown));
    });
  });

  // ===========================================================================
  // 3. KEY CHANGE DETECTION
  // ===========================================================================

  group('3. Key change detection', () {
    test('First contact stores key', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      final result = await verification.checkKeyChange(
        peerId: 'peer-1',
        receivedIdentityKey: key,
      );
      expect(result, equals(KeyChangeResult.firstContact));
      final stored = await verification.loadStoredIdentityKey('peer-1');
      expect(stored, equals(key));
    });

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

    test('Key change after verification -> CHANGED state', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);

      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key1);
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key1);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.verified));

      final result = await verification.checkKeyChange(
        peerId: 'peer-1',
        receivedIdentityKey: key2,
      );
      expect(result, equals(KeyChangeResult.changed));

      final newState = await verification.handleKeyChange(
        peerId: 'peer-1',
        newIdentityKey: key2,
      );
      expect(newState, equals(IdentityTrustState.changed));
    });

    test('Key change without prior verification -> remains UNKNOWN', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);

      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key1);

      final result = await verification.checkKeyChange(
        peerId: 'peer-1',
        receivedIdentityKey: key2,
      );
      expect(result, equals(KeyChangeResult.changed));

      final newState = await verification.handleKeyChange(
        peerId: 'peer-1',
        newIdentityKey: key2,
      );
      expect(newState, equals(IdentityTrustState.unknown));
    });
  });

  // ===========================================================================
  // 4. VERIFICATION
  // ===========================================================================

  group('4. Verification', () {
    test('Verify identity sets VERIFIED state', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key);
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.verified));
    });

    test('Verify stores identity key', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key);
      final stored = await verification.loadStoredIdentityKey('peer-1');
      expect(stored, equals(key));
    });

    test('Server cannot silently set verified', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key);

      // Trust state stored locally — server has no access
      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.unknown));
    });
  });

  // ===========================================================================
  // 5. MITM ATTACK SCENARIOS
  // ===========================================================================

  group('5. MITM attack scenarios', () {
    test('Server substitutes identity key -> detected', () async {
      final bobKey = List<int>.generate(32, (i) => i + 50);
      final attackerKey = List<int>.generate(32, (i) => i + 100);

      await verification.checkKeyChange(peerId: 'bob', receivedIdentityKey: bobKey);
      await verification.verifyIdentity(peerId: 'bob', identityKey: bobKey);

      final result = await verification.checkKeyChange(
        peerId: 'bob',
        receivedIdentityKey: attackerKey,
      );

      expect(result, equals(KeyChangeResult.changed));

      final newState = await verification.handleKeyChange(
        peerId: 'bob',
        newIdentityKey: attackerKey,
      );
      expect(newState, equals(IdentityTrustState.changed));
    });

    test('MITM on first contact -> user must verify manually', () async {
      final attackerKey = List<int>.generate(32, (i) => i + 100);

      final result = await verification.checkKeyChange(
        peerId: 'bob',
        receivedIdentityKey: attackerKey,
      );

      expect(result, equals(KeyChangeResult.firstContact));
      expect(await verification.getTrustState('bob'), equals(IdentityTrustState.unknown));
    });

    test('Key substitution after verification -> user warned', () async {
      final bobKey = List<int>.generate(32, (i) => i + 50);
      final attackerKey = List<int>.generate(32, (i) => i + 100);

      await verification.checkKeyChange(peerId: 'bob', receivedIdentityKey: bobKey);
      await verification.verifyIdentity(peerId: 'bob', identityKey: bobKey);

      await verification.checkKeyChange(peerId: 'bob', receivedIdentityKey: attackerKey);
      final newState = await verification.handleKeyChange(
        peerId: 'bob',
        newIdentityKey: attackerKey,
      );

      expect(newState, equals(IdentityTrustState.changed));
    });

    test('Multiple key changes -> stays CHANGED', () async {
      final bobKey = List<int>.generate(32, (i) => i + 50);
      final attackerKey1 = List<int>.generate(32, (i) => i + 100);
      final attackerKey2 = List<int>.generate(32, (i) => i + 200);

      await verification.checkKeyChange(peerId: 'bob', receivedIdentityKey: bobKey);
      await verification.verifyIdentity(peerId: 'bob', identityKey: bobKey);

      await verification.checkKeyChange(peerId: 'bob', receivedIdentityKey: attackerKey1);
      await verification.handleKeyChange(peerId: 'bob', newIdentityKey: attackerKey1);
      expect(await verification.getTrustState('bob'), equals(IdentityTrustState.changed));

      await verification.checkKeyChange(peerId: 'bob', receivedIdentityKey: attackerKey2);
      await verification.handleKeyChange(peerId: 'bob', newIdentityKey: attackerKey2);
      expect(await verification.getTrustState('bob'), equals(IdentityTrustState.changed));
    });
  });

  // ===========================================================================
  // 6. PROPERTY TESTS
  // ===========================================================================

  group('6. Property tests', () {
    test('INVARIANT: VERIFIED + key change -> CHANGED (not VERIFIED)', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);

      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key1);
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key1);

      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key2);
      final newState = await verification.handleKeyChange(
        peerId: 'peer-1',
        newIdentityKey: key2,
      );

      expect(newState, isNot(equals(IdentityTrustState.verified)));
      expect(newState, equals(IdentityTrustState.changed));
    });

    test('INVARIANT: fingerprint is deterministic', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      final fp1 = await E2eV2IdentityVerification.generateFingerprint(key);
      final fp2 = await E2eV2IdentityVerification.generateFingerprint(key);
      expect(fp1, equals(fp2));
    });

    test('INVARIANT: different keys have different fingerprints', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 2);
      final fp1 = await E2eV2IdentityVerification.generateFingerprint(key1);
      final fp2 = await E2eV2IdentityVerification.generateFingerprint(key2);
      expect(fp1, isNot(equals(fp2)));
    });

    test('INVARIANT: trust state is per-peer', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);

      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key1);
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key1);

      await verification.checkKeyChange(peerId: 'peer-2', receivedIdentityKey: key2);

      expect(await verification.getTrustState('peer-1'), equals(IdentityTrustState.verified));
      expect(await verification.getTrustState('peer-2'), equals(IdentityTrustState.unknown));
    });
  });

  // ===========================================================================
  // 7. RESTART / PERSISTENCE
  // ===========================================================================

  group('7. Restart / persistence', () {
    test('Trust state persists across new instance with same storage', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key);
      await verification.verifyIdentity(peerId: 'peer-1', identityKey: key);

      // New instance with same storage (simulates restart)
      final newVerification = E2eV2IdentityVerification.withStorage(storage);
      final state = await newVerification.getTrustState('peer-1');
      expect(state, equals(IdentityTrustState.verified));
    });

    test('Stored key persists across new instance with same storage', () async {
      final key = List<int>.generate(32, (i) => i + 1);
      await verification.checkKeyChange(peerId: 'peer-1', receivedIdentityKey: key);

      final newVerification = E2eV2IdentityVerification.withStorage(storage);
      final stored = await newVerification.loadStoredIdentityKey('peer-1');
      expect(stored, equals(key));
    });
  });

  // ===========================================================================
  // 8. KEY CHANGE AFTER RESTART
  // ===========================================================================

  group('8. Key change after restart', () {
    test('Verified key + key change after restart -> CHANGED', () async {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 100);

      await verification.checkKeyChange(peerId: 'bob', receivedIdentityKey: key1);
      await verification.verifyIdentity(peerId: 'bob', identityKey: key1);

      // New instance with same storage (restart)
      final newVerification = E2eV2IdentityVerification.withStorage(storage);

      final result = await newVerification.checkKeyChange(
        peerId: 'bob',
        receivedIdentityKey: key2,
      );
      expect(result, equals(KeyChangeResult.changed));

      final newState = await newVerification.handleKeyChange(
        peerId: 'bob',
        newIdentityKey: key2,
      );
      expect(newState, equals(IdentityTrustState.changed));
    });
  });

  // ===========================================================================
  // 9. FINGERPRINT COLLISION RESISTANCE
  // ===========================================================================

  group('9. Fingerprint collision resistance', () {
    test('Different keys have unique fingerprints', () async {
      final fingerprints = <String>{};
      for (var i = 0; i < 100; i++) {
        final key = List<int>.generate(32, (_) => i * 37 + 11);
        final fp = await E2eV2IdentityVerification.generateFingerprint(key);
        expect(fingerprints.contains(fp), isFalse,
            reason: 'Duplicate fingerprint for key $i');
        fingerprints.add(fp);
      }
    });

    test('Similar keys (1 byte different) have different fingerprints', () async {
      final key1 = List<int>.generate(32, (i) => i);
      final key2 = List<int>.generate(32, (i) => i);
      key2[31] = key2[31] + 1;

      final fp1 = await E2eV2IdentityVerification.generateFingerprint(key1);
      final fp2 = await E2eV2IdentityVerification.generateFingerprint(key2);
      expect(fp1, isNot(equals(fp2)));
    });
  });
}

// Helper functions for fingerprint formatting
String _bytesToNumericString(List<int> bytes, int maxBytes) {
  final limited = bytes.take(maxBytes).toList();
  var digits = <int>[];
  var remaining = limited.toList();

  while (remaining.any((b) => b != 0)) {
    var carry = 0;
    final newRemaining = <int>[];
    for (final byte in remaining) {
      final value = carry * 256 + byte;
      newRemaining.add(value ~/ 10);
      carry = value % 10;
    }
    digits.add(carry);
    remaining = newRemaining;
    while (remaining.isNotEmpty && remaining.first == 0) {
      remaining.removeAt(0);
    }
  }

  digits = digits.reversed.toList();
  final result = digits.join();
  return result.padLeft(60, '0').substring(0, 60);
}

String _formatSafetyCode(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < 60; i += 5) {
    if (i > 0) buf.write(' ');
    buf.write(digits.substring(i, i + 5));
  }
  return buf.toString();
}
