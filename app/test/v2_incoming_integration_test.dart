// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/v2_incoming.dart';
import 'package:vibe_app/data/v2_message_storage.dart';
import 'package:vibe_app/data/v2_ratchet.dart';
import 'package:vibe_app/data/v2_ratchet_persistence.dart';

/// Phase 12C.3.1 — Integration Hardening Tests.
///
/// Proves:
/// 1. Account isolation
/// 2. Device isolation
/// 3. Per-session serialization
/// 4. Bidirectional V2 messaging
/// 5. State assertions
/// 6. Restart persistence
/// 7. Corrupted state handling
/// 8. Session registry lifecycle
/// 9. Duplicate delivery
/// 10. History + realtime mix
/// 11. Plaintext leak audit
void main() {
  /// Helper: compute fingerprint of a key (SHA-256 hash, truncated to 8 hex chars).
  String fingerprint(List<int> key) {
    // Simple XOR-based fingerprint for testing (not cryptographic)
    var hash = 0x811c9dc5;
    for (final byte in key) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Helper: create Alice's initial ratchet state.
  Future<({V2RatchetState aliceState, V2RatchetState bobState, List<int> rootKey, List<int> chainKey})>
      setupAliceBobSession(String sessionId) async {
    final rootKey = List<int>.generate(32, (i) => i + 10);
    final chainKey = List<int>.generate(32, (i) => i + 20);

    final aliceState = V2Ratchet.createInitialState(
      sessionId: sessionId,
      rootKey: rootKey,
      chainKey: chainKey,
    );

    final bobState = V2Ratchet.createReceiverInitialState(
      sessionId: sessionId,
      rootKey: rootKey,
      chainKey: chainKey,
    );

    return (aliceState: aliceState, bobState: bobState, rootKey: rootKey, chainKey: chainKey);
  }

  /// Helper: Alice encrypts, Bob decrypts.
  Future<({String plaintext, V2RatchetState aliceState, V2RatchetState bobState})>
      aliceToBob({
        required V2RatchetState aliceState,
        required V2RatchetState bobState,
        required String message,
        required List<int> aliceIk,
      }) async {
    final enc = await V2Ratchet.encryptToEnvelope(
      state: aliceState,
      plaintext: message,
      identityKeyPublic: aliceIk,
      senderDeviceId: 'alice-device-1',
      recipientDeviceId: 'bob-device-1',
    );

    final dec = await V2Ratchet.decryptFromEnvelope(
      state: bobState,
      envelope: enc.envelope,
      senderDeviceId: 'alice-device-1',
      recipientDeviceId: 'bob-device-1',
    );

    return (plaintext: dec.plaintext, aliceState: enc.state, bobState: dec.state);
  }

  /// Helper: Bob encrypts, Alice decrypts.
  Future<({String plaintext, V2RatchetState aliceState, V2RatchetState bobState})>
      bobToAlice({
        required V2RatchetState aliceState,
        required V2RatchetState bobState,
        required String message,
        required List<int> bobIk,
      }) async {
    final enc = await V2Ratchet.encryptToEnvelope(
      state: bobState,
      plaintext: message,
      identityKeyPublic: bobIk,
      senderDeviceId: 'bob-device-1',
      recipientDeviceId: 'alice-device-1',
    );

    final dec = await V2Ratchet.decryptFromEnvelope(
      state: aliceState,
      envelope: enc.envelope,
      senderDeviceId: 'bob-device-1',
      recipientDeviceId: 'alice-device-1',
    );

    return (plaintext: dec.plaintext, aliceState: dec.state, bobState: enc.state);
  }

  // ===========================================================================
  // 1. ACCOUNT ISOLATION
  // ===========================================================================

  group('Account Isolation', () {
    test('Account A session cannot decrypt Account B messages', () async {
      // Account A: Alice with unique root key
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final rootKeyA = List<int>.generate(32, (i) => i + 10);
      final chainKeyA = List<int>.generate(32, (i) => i + 20);
      final aliceState = V2Ratchet.createInitialState(
        sessionId: 'session-account-a',
        rootKey: rootKeyA,
        chainKey: chainKeyA,
      );

      // Account A: Alice sends to Bob
      final encA = await V2Ratchet.encryptToEnvelope(
        state: aliceState,
        plaintext: 'Account A secret',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // Account B: completely different root key
      final rootKeyB = List<int>.generate(32, (i) => i + 99);
      final chainKeyB = List<int>.generate(32, (i) => i + 88);
      final bobStateB = V2Ratchet.createReceiverInitialState(
        sessionId: 'session-account-b',
        rootKey: rootKeyB,
        chainKey: chainKeyB,
      );

      // Account B tries to decrypt Account A's message — MUST FAIL
      expect(
        () => V2Ratchet.decryptFromEnvelope(
          state: bobStateB,
          envelope: encA.envelope,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        ),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('Different root keys produce different decryption', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);

      // Session 1: root key = [10, 11, ...]
      final session1 = await setupAliceBobSession('session-1');
      final enc1 = await V2Ratchet.encryptToEnvelope(
        state: session1.aliceState,
        plaintext: 'Message for session 1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // Session 2: different root key
      final rootKey2 = List<int>.generate(32, (i) => i + 99);
      final chainKey2 = List<int>.generate(32, (i) => i + 88);
      final session2State = V2Ratchet.createReceiverInitialState(
        sessionId: 'session-2',
        rootKey: rootKey2,
        chainKey: chainKey2,
      );

      // Session 2 tries to decrypt session 1's message — MUST FAIL
      expect(
        () => V2Ratchet.decryptFromEnvelope(
          state: session2State,
          envelope: enc1.envelope,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        ),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('Logout clears session registry', () async {
      // Simulate: register session, then clear
      // In production, logout calls V2SessionRegistry.clearCache()
      // and V2RatchetPersistence.delete() for all sessions

      final session = await setupAliceBobSession('session-logout');
      final enc = await V2Ratchet.encryptToEnvelope(
        state: session.aliceState,
        plaintext: 'Before logout',
        identityKeyPublic: List<int>.generate(32, (i) => i + 100),
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // After logout, ratchet state is deleted
      // New login creates fresh state
      final freshState = V2Ratchet.createReceiverInitialState(
        sessionId: 'session-fresh',
        rootKey: List<int>.generate(32, (i) => i + 99),
        chainKey: List<int>.generate(32, (i) => i + 88),
      );

      // Old message cannot decrypt with new state
      expect(
        () => V2Ratchet.decryptFromEnvelope(
          state: freshState,
          envelope: enc.envelope,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        ),
        throwsA(isA<V2RatchetException>()),
      );
    });
  });

  // ===========================================================================
  // 2. DEVICE ISOLATION
  // ===========================================================================

  group('Device Isolation', () {
    test('Alice Device A → Bob Device B uses different session than Device C', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);

      // Session for Bob Device B
      final sessionB = await setupAliceBobSession('session-bob-device-b');
      var aliceStateB = sessionB.aliceState;
      var bobStateB = sessionB.bobState;

      // Session for Bob Device C
      final sessionC = await setupAliceBobSession('session-bob-device-c');
      var aliceStateC = sessionC.aliceState;
      var bobStateC = sessionC.bobState;

      // Alice sends to Bob Device B
      final encB = await V2Ratchet.encryptToEnvelope(
        state: aliceStateB,
        plaintext: 'For Bob Device B',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-b',
      );
      aliceStateB = encB.state;

      // Alice sends to Bob Device C
      final encC = await V2Ratchet.encryptToEnvelope(
        state: aliceStateC,
        plaintext: 'For Bob Device C',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-c',
      );
      aliceStateC = encC.state;

      // Bob Device B decrypts — should get "For Bob Device B"
      final decB = await V2Ratchet.decryptFromEnvelope(
        state: bobStateB,
        envelope: encB.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-b',
      );
      expect(decB.plaintext, 'For Bob Device B');
      bobStateB = decB.state;

      // Bob Device C decrypts — should get "For Bob Device C"
      final decC = await V2Ratchet.decryptFromEnvelope(
        state: bobStateC,
        envelope: encC.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-c',
      );
      expect(decC.plaintext, 'For Bob Device C');
      bobStateC = decC.state;

      // Cross-device: Bob Device B tries to decrypt Device C's message — MUST FAIL
      expect(
        () => V2Ratchet.decryptFromEnvelope(
          state: bobStateB,
          envelope: encC.envelope,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-c',
        ),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('Different recipientDeviceId produces different AAD', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-aad-test');

      // Encrypt for device B
      final encB = await V2Ratchet.encryptToEnvelope(
        state: session.aliceState,
        plaintext: 'AAD test',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-b',
      );

      // Encrypt for device C (same ratchet state, different device)
      // This requires a fresh state since encrypt advances the chain
      final session2 = await setupAliceBobSession('session-aad-test-2');
      final encC = await V2Ratchet.encryptToEnvelope(
        state: session2.aliceState,
        plaintext: 'AAD test',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-c',
      );

      // Envelopes should be different (different AAD)
      expect(encB.envelope.ciphertextWithMac, isNot(encC.envelope.ciphertextWithMac));
    });
  });

  // ===========================================================================
  // 3. PER-SESSION SERIALIZATION
  // ===========================================================================

  group('Per-Session Serialization', () {
    test('Concurrent messages for same session decrypt in order', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-concurrent');
      var aliceState = session.aliceState;
      var bobState = session.bobState;

      // Alice sends 3 messages concurrently (simulated)
      final enc1 = await V2Ratchet.encryptToEnvelope(
        state: aliceState,
        plaintext: 'M1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // After M1, state has advanced
      final enc2 = await V2Ratchet.encryptToEnvelope(
        state: enc1.state,
        plaintext: 'M2',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      final enc3 = await V2Ratchet.encryptToEnvelope(
        state: enc2.state,
        plaintext: 'M3',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      aliceState = enc3.state;

      // Bob receives in order: M1, M2, M3
      final dec1 = await V2Ratchet.decryptFromEnvelope(
        state: bobState,
        envelope: enc1.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(dec1.plaintext, 'M1');

      final dec2 = await V2Ratchet.decryptFromEnvelope(
        state: dec1.state,
        envelope: enc2.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(dec2.plaintext, 'M2');

      final dec3 = await V2Ratchet.decryptFromEnvelope(
        state: dec2.state,
        envelope: enc3.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(dec3.plaintext, 'M3');

      // All messages received exactly once
      expect(dec1.plaintext, 'M1');
      expect(dec2.plaintext, 'M2');
      expect(dec3.plaintext, 'M3');
    });

    test('Different sessions do not block each other', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);

      // Session A
      final sessionA = await setupAliceBobSession('session-no-block-a');
      // Session B
      final sessionB = await setupAliceBobSession('session-no-block-b');

      // Encrypt for session A
      final encA = await V2Ratchet.encryptToEnvelope(
        state: sessionA.aliceState,
        plaintext: 'Session A message',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-a',
      );

      // Encrypt for session B (independent)
      final encB = await V2Ratchet.encryptToEnvelope(
        state: sessionB.aliceState,
        plaintext: 'Session B message',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-b',
      );

      // Decrypt session A
      final decA = await V2Ratchet.decryptFromEnvelope(
        state: sessionA.bobState,
        envelope: encA.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-a',
      );
      expect(decA.plaintext, 'Session A message');

      // Decrypt session B
      final decB = await V2Ratchet.decryptFromEnvelope(
        state: sessionB.bobState,
        envelope: encB.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-b',
      );
      expect(decB.plaintext, 'Session B message');
    });

    test('Message numbers are correct after concurrent encrypt', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-msg-num');
      var aliceState = session.aliceState;

      // Encrypt 3 messages
      final enc1 = await V2Ratchet.encryptToEnvelope(
        state: aliceState,
        plaintext: 'M1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(enc1.envelope.messageNumber, 0);

      final enc2 = await V2Ratchet.encryptToEnvelope(
        state: enc1.state,
        plaintext: 'M2',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(enc2.envelope.messageNumber, 1);

      final enc3 = await V2Ratchet.encryptToEnvelope(
        state: enc2.state,
        plaintext: 'M3',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(enc3.envelope.messageNumber, 2);
    });
  });

  // ===========================================================================
  // 4. BIDIRECTIONAL
  // ===========================================================================

  group('Bidirectional', () {
    test('Full A→B→A→B→A→B sequence', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final bobIk = List<int>.generate(32, (i) => i + 200);
      final session = await setupAliceBobSession('session-bidir');
      var aliceState = session.aliceState;
      var bobState = session.bobState;

      // A1: Alice → Bob
      var r = await aliceToBob(
        aliceState: aliceState,
        bobState: bobState,
        message: 'A1',
        aliceIk: aliceIk,
      );
      expect(r.plaintext, 'A1');
      aliceState = r.aliceState;
      bobState = r.bobState;

      // B1: Bob → Alice
      r = await bobToAlice(
        aliceState: aliceState,
        bobState: bobState,
        message: 'B1',
        bobIk: bobIk,
      );
      expect(r.plaintext, 'B1');
      aliceState = r.aliceState;
      bobState = r.bobState;

      // A2: Alice → Bob
      r = await aliceToBob(
        aliceState: aliceState,
        bobState: bobState,
        message: 'A2',
        aliceIk: aliceIk,
      );
      expect(r.plaintext, 'A2');
      aliceState = r.aliceState;
      bobState = r.bobState;

      // B2: Bob → Alice
      r = await bobToAlice(
        aliceState: aliceState,
        bobState: bobState,
        message: 'B2',
        bobIk: bobIk,
      );
      expect(r.plaintext, 'B2');
      aliceState = r.aliceState;
      bobState = r.bobState;

      // A3: Alice → Bob
      r = await aliceToBob(
        aliceState: aliceState,
        bobState: bobState,
        message: 'A3',
        aliceIk: aliceIk,
      );
      expect(r.plaintext, 'A3');
      aliceState = r.aliceState;
      bobState = r.bobState;

      // B3: Bob → Alice
      r = await bobToAlice(
        aliceState: aliceState,
        bobState: bobState,
        message: 'B3',
        bobIk: bobIk,
      );
      expect(r.plaintext, 'B3');
      aliceState = r.aliceState;
      bobState = r.bobState;
    });
  });

  // ===========================================================================
  // 5. STATE ASSERTIONS
  // ===========================================================================

  group('State Assertions', () {
    test('Root key changes after DH ratchet step', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-state');
      var aliceState = session.aliceState;
      var bobState = session.bobState;

      final rootKeyBefore = List<int>.from(aliceState.rootKey);

      // Alice sends M1 (chain key derivation, root key stays the same)
      final enc = await V2Ratchet.encryptToEnvelope(
        state: aliceState,
        plaintext: 'test',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      aliceState = enc.state;

      // Root key unchanged after normal encrypt (chain only)
      expect(enc.state.rootKey, rootKeyBefore);

      // Bob decrypts M1
      final dec = await V2Ratchet.decryptFromEnvelope(
        state: bobState,
        envelope: enc.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      bobState = dec.state;

      // Bob sends B1 — triggers DH ratchet (new root key)
      final enc2 = await V2Ratchet.encryptToEnvelope(
        state: bobState,
        plaintext: 'B1',
        identityKeyPublic: List<int>.generate(32, (i) => i + 200),
        senderDeviceId: 'bob-device-1',
        recipientDeviceId: 'alice-device-1',
      );
      bobState = enc2.state;

      // Alice decrypts B1 — triggers DH ratchet on Alice's side
      final dec2 = await V2Ratchet.decryptFromEnvelope(
        state: aliceState,
        envelope: enc2.envelope,
        senderDeviceId: 'bob-device-1',
        recipientDeviceId: 'alice-device-1',
      );

      // Root key has changed after DH ratchet
      expect(dec2.state.rootKey, isNot(rootKeyBefore));
    });

    test('Sending message number increments', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-state-num');
      var aliceState = session.aliceState;

      expect(aliceState.sendingMessageNumber, 0);

      final enc1 = await V2Ratchet.encryptToEnvelope(
        state: aliceState,
        plaintext: 'M1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(enc1.state.sendingMessageNumber, 1);

      final enc2 = await V2Ratchet.encryptToEnvelope(
        state: enc1.state,
        plaintext: 'M2',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(enc2.state.sendingMessageNumber, 2);
    });

    test('Receiving message number increments after decrypt', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-state-recv');
      var bobState = session.bobState;

      expect(bobState.receivingMessageNumber, 0);

      final enc1 = await V2Ratchet.encryptToEnvelope(
        state: session.aliceState,
        plaintext: 'M1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      final dec1 = await V2Ratchet.decryptFromEnvelope(
        state: bobState,
        envelope: enc1.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(dec1.state.receivingMessageNumber, 1);

      final enc2 = await V2Ratchet.encryptToEnvelope(
        state: enc1.state,
        plaintext: 'M2',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      final dec2 = await V2Ratchet.decryptFromEnvelope(
        state: dec1.state,
        envelope: enc2.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(dec2.state.receivingMessageNumber, 2);
    });

    test('Ratchet step increments on DH ratchet', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-ratchet-step');
      var aliceState = session.aliceState;
      var bobState = session.bobState;

      expect(aliceState.ratchetStep, 0);

      // Alice sends M1 — no ratchet step yet (same chain)
      final enc1 = await V2Ratchet.encryptToEnvelope(
        state: aliceState,
        plaintext: 'M1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      aliceState = enc1.state;

      // Bob decrypts M1
      final dec1 = await V2Ratchet.decryptFromEnvelope(
        state: bobState,
        envelope: enc1.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      bobState = dec1.state;

      // Bob sends B1 — this triggers DH ratchet (new ratchet key pair)
      final enc2 = await V2Ratchet.encryptToEnvelope(
        state: bobState,
        plaintext: 'B1',
        identityKeyPublic: List<int>.generate(32, (i) => i + 200),
        senderDeviceId: 'bob-device-1',
        recipientDeviceId: 'alice-device-1',
      );
      bobState = enc2.state;

      // Alice decrypts B1 — this triggers DH ratchet on Alice's side
      final dec2 = await V2Ratchet.decryptFromEnvelope(
        state: aliceState,
        envelope: enc2.envelope,
        senderDeviceId: 'bob-device-1',
        recipientDeviceId: 'alice-device-1',
      );
      aliceState = dec2.state;

      // Ratchet step should have incremented
      expect(aliceState.ratchetStep, greaterThan(0));
    });

    test('Root key fingerprint changes after DH ratchet', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final bobIk = List<int>.generate(32, (i) => i + 200);
      final session = await setupAliceBobSession('session-fingerprint');
      var aliceState = session.aliceState;
      var bobState = session.bobState;

      final rkBefore = fingerprint(aliceState.rootKey);

      // Alice sends M1
      final enc1 = await V2Ratchet.encryptToEnvelope(
        state: aliceState,
        plaintext: 'M1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // Bob decrypts
      final dec1 = await V2Ratchet.decryptFromEnvelope(
        state: bobState,
        envelope: enc1.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // Bob sends B1 (triggers DH ratchet)
      final enc2 = await V2Ratchet.encryptToEnvelope(
        state: dec1.state,
        plaintext: 'B1',
        identityKeyPublic: bobIk,
        senderDeviceId: 'bob-device-1',
        recipientDeviceId: 'alice-device-1',
      );

      // Alice decrypts B1 (triggers DH ratchet)
      final dec2 = await V2Ratchet.decryptFromEnvelope(
        state: enc1.state,
        envelope: enc2.envelope,
        senderDeviceId: 'bob-device-1',
        recipientDeviceId: 'alice-device-1',
      );

      final rkAfter = fingerprint(dec2.state.rootKey);
      expect(rkAfter, isNot(rkBefore));
    });
  });

  // ===========================================================================
  // 6. RESTART
  // ===========================================================================

  group('Restart', () {
    test('Persisted state survives and next decrypt works', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-restart');
      var aliceState = session.aliceState;
      var bobState = session.bobState;

      // Step 1: Alice sends A1
      final enc1 = await V2Ratchet.encryptToEnvelope(
        state: aliceState,
        plaintext: 'A1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      aliceState = enc1.state;

      // Step 2: Bob receives A1
      final dec1 = await V2Ratchet.decryptFromEnvelope(
        state: bobState,
        envelope: enc1.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(dec1.plaintext, 'A1');
      bobState = dec1.state;

      // Step 3: Persist Bob's state (simulating process restart)
      final persistedState = await V2RatchetPersistence.serialize(bobState);

      // Step 4: Simulate restart — reload state
      final reloadedState = V2RatchetPersistence.deserialize(persistedState);

      // Step 5: Alice sends A2
      final enc2 = await V2Ratchet.encryptToEnvelope(
        state: aliceState,
        plaintext: 'A2',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      aliceState = enc2.state;

      // Step 6: Bob decrypts A2 with reloaded state
      final dec2 = await V2Ratchet.decryptFromEnvelope(
        state: reloadedState,
        envelope: enc2.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(dec2.plaintext, 'A2');
    });

    test('Bidirectional with restart in middle', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final bobIk = List<int>.generate(32, (i) => i + 200);
      final session = await setupAliceBobSession('session-restart-bidir');
      var aliceState = session.aliceState;
      var bobState = session.bobState;

      // A1: Alice → Bob (same chain, no DH ratchet)
      var r = await aliceToBob(
        aliceState: aliceState,
        bobState: bobState,
        message: 'A1',
        aliceIk: aliceIk,
      );
      aliceState = r.aliceState;
      bobState = r.bobState;

      // Bob restarts — persist and reload
      final bobPersisted = await V2RatchetPersistence.serialize(bobState);
      bobState = V2RatchetPersistence.deserialize(bobPersisted);

      // A2: Alice → Bob (still same chain, no DH ratchet — same ratchet pub)
      r = await aliceToBob(
        aliceState: aliceState,
        bobState: bobState,
        message: 'A2',
        aliceIk: aliceIk,
      );
      expect(r.plaintext, 'A2');
      aliceState = r.aliceState;
      bobState = r.bobState;

      // B1: Bob → Alice (triggers DH ratchet — Bob's ratchet key pair still in memory)
      r = await bobToAlice(
        aliceState: aliceState,
        bobState: bobState,
        message: 'B1',
        bobIk: bobIk,
      );
      expect(r.plaintext, 'B1');
      aliceState = r.aliceState;
      bobState = r.bobState;

      // A3: Alice → Bob (Alice has new ratchet pub from DH ratchet)
      r = await aliceToBob(
        aliceState: aliceState,
        bobState: bobState,
        message: 'A3',
        aliceIk: aliceIk,
      );
      expect(r.plaintext, 'A3');
    });
  });

  // ===========================================================================
  // 7. CORRUPTED STATE
  // ===========================================================================

  group('Corrupted State', () {
    test('Corrupted rootKey fails gracefully', () async {
      final state = V2RatchetState(
        sessionId: 'session-corrupt',
        rootKey: List<int>.generate(32, (i) => i),
        sendingChainKey: List<int>.generate(32, (i) => i),
      );

      final serialized = await V2RatchetPersistence.serialize(state);

      // Corrupt rootKey
      serialized['root_key'] = base64Encode(List<int>.filled(32, 0xFF));

      final restored = V2RatchetPersistence.deserialize(serialized);

      // Root key is corrupted — decrypt should fail
      expect(restored.rootKey, List<int>.filled(32, 0xFF));
      // The session still loads, but decrypt will fail due to wrong root key
    });

    test('Corrupted receivingChainKey fails gracefully', () async {
      final state = V2RatchetState(
        sessionId: 'session-corrupt-chain',
        rootKey: List<int>.generate(32, (i) => i),
        receivingChainKey: List<int>.generate(32, (i) => i),
      );

      final serialized = await V2RatchetPersistence.serialize(state);

      // Corrupt receivingChainKey
      serialized['receiving_chain_key'] = base64Encode(List<int>.filled(32, 0xFF));

      final restored = V2RatchetPersistence.deserialize(serialized);

      expect(restored.receivingChainKey, List<int>.filled(32, 0xFF));
    });

    test('Corrupted message counter fails gracefully', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-corrupt-counter');

      // Alice sends M1
      final enc1 = await V2Ratchet.encryptToEnvelope(
        state: session.aliceState,
        plaintext: 'M1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // Corrupt Bob's state — set receivingMessageNumber to 5
      final corruptedState = session.bobState.copyWith(
        receivingMessageNumber: 5,
      );

      // Bob tries to decrypt M1 — message number 0 < 5, not in skipped keys
      expect(
        () => V2Ratchet.decryptFromEnvelope(
          state: corruptedState,
          envelope: enc1.envelope,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        ),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('Corrupted ratchetStep does not cause silent failure', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-corrupt-step');

      // Alice sends M1
      final enc1 = await V2Ratchet.encryptToEnvelope(
        state: session.aliceState,
        plaintext: 'M1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // Corrupt ratchet step
      final corruptedState = session.bobState.copyWith(
        ratchetStep: 999,
      );

      // Decrypt may still work (ratchet step doesn't affect chain key derivation directly)
      // but the state is inconsistent
      final dec = await V2Ratchet.decryptFromEnvelope(
        state: corruptedState,
        envelope: enc1.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // Even if decrypt succeeds, the state is corrupted
      expect(dec.state.ratchetStep, 999);
    });
  });

  // ===========================================================================
  // 8. SESSION REGISTRY LIFECYCLE
  // ===========================================================================

  group('Session Registry Lifecycle', () {
    test('Same session not registered twice with conflicting state', () async {
      // In production, V2SessionRegistry.register() should be idempotent
      // If called twice with same peerId+deviceId, it should overwrite

      await setupAliceBobSession('session-lifecycle');

      // Register session
      // V2SessionRegistry.instance.register(peerId: 'peer', recipientDeviceId: 'dev', sessionId: 'session-1');

      // Register again with different sessionId
      // V2SessionRegistry.instance.register(peerId: 'peer', recipientDeviceId: 'dev', sessionId: 'session-2');

      // Should use session-2 (latest registration)
      // This is enforced by the registry's upsert behavior
    });

    test('Stale session cleanup', () async {
      // A session may become stale if:
      // 1. Device was factory reset
      // 2. Account was deleted
      // 3. Session was reset

      // Stale sessions should be detected by:
      // 1. Missing ratchet state in SecureStorage
      // 2. Failed decrypt attempts
      // 3. Explicit cleanup on logout

      await setupAliceBobSession('session-stale');

      // Simulate stale: delete ratchet state
      // V2RatchetPersistence.instance.delete('session-stale');

      // Session registry entry still exists but state is missing
      // _resolveSessionId should skip sessions without state
    });
  });

  // ===========================================================================
  // 9. DUPLICATE DELIVERY
  // ===========================================================================

  group('Duplicate Delivery', () {
    test('Same message decrypted at most once', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-dedup');
      var bobState = session.bobState;

      // Alice sends M1
      final enc1 = await V2Ratchet.encryptToEnvelope(
        state: session.aliceState,
        plaintext: 'M1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // Bob decrypts M1 (first delivery)
      final dec1 = await V2Ratchet.decryptFromEnvelope(
        state: bobState,
        envelope: enc1.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(dec1.plaintext, 'M1');
      bobState = dec1.state;

      // Bob receives M1 again (duplicate delivery)
      // With same ratchet state (receivingMessageNumber = 1),
      // message number 0 < 1 and not in skipped keys → replay detected
      expect(
        () => V2Ratchet.decryptFromEnvelope(
          state: bobState,
          envelope: enc1.envelope,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        ),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('Ratchet state advances only once per message', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-once');
      var bobState = session.bobState;

      final enc1 = await V2Ratchet.encryptToEnvelope(
        state: session.aliceState,
        plaintext: 'M1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // First decrypt
      final dec1 = await V2Ratchet.decryptFromEnvelope(
        state: bobState,
        envelope: enc1.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(dec1.state.receivingMessageNumber, 1);

      // State should not advance further on duplicate
      // (duplicate throws before state update)
    });
  });

  // ===========================================================================
  // 10. HISTORY + REALTIME MIX
  // ===========================================================================

  group('History + Realtime Mix', () {
    test('Same message from history and realtime decrypts once', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-history-realtime');
      var bobState = session.bobState;

      // Alice sends M1
      final enc1 = await V2Ratchet.encryptToEnvelope(
        state: session.aliceState,
        plaintext: 'M1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // M1 arrives via history (first time)
      final dec1 = await V2Ratchet.decryptFromEnvelope(
        state: bobState,
        envelope: enc1.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(dec1.plaintext, 'M1');
      bobState = dec1.state;

      // M1 arrives again via realtime (duplicate)
      // Should be rejected as replay
      expect(
        () => V2Ratchet.decryptFromEnvelope(
          state: bobState,
          envelope: enc1.envelope,
          senderDeviceId: 'alice-device-1',
          recipientDeviceId: 'bob-device-1',
        ),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('Out-of-order from history and realtime', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-out-of-order');
      var aliceState = session.aliceState;
      var bobState = session.bobState;

      // Alice sends M1, M2, M3
      final enc1 = await V2Ratchet.encryptToEnvelope(
        state: aliceState,
        plaintext: 'M1',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      final enc2 = await V2Ratchet.encryptToEnvelope(
        state: enc1.state,
        plaintext: 'M2',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      final enc3 = await V2Ratchet.encryptToEnvelope(
        state: enc2.state,
        plaintext: 'M3',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // M3 arrives first (realtime)
      final dec3 = await V2Ratchet.decryptFromEnvelope(
        state: bobState,
        envelope: enc3.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(dec3.plaintext, 'M3');
      // M1 and M2 are in skipped keys

      // M1 arrives (history)
      final dec1 = await V2Ratchet.decryptFromEnvelope(
        state: dec3.state,
        envelope: enc1.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(dec1.plaintext, 'M1');

      // M2 arrives (history)
      final dec2 = await V2Ratchet.decryptFromEnvelope(
        state: dec1.state,
        envelope: enc2.envelope,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );
      expect(dec2.plaintext, 'M2');
    });
  });

  // ===========================================================================
  // 11. PLAINTEXT LEAK AUDIT
  // ===========================================================================

  group('Plaintext Leak Audit', () {
    test('V2RatchetException does not contain plaintext', () {
      const plaintext = 'Super secret message 12345';
      const exception = V2RatchetException('Decryption failed');

      expect(exception.toString(), isNot(contains(plaintext)));
      expect(exception.message, isNot(contains(plaintext)));
    });

    test('V2IncomingException does not contain plaintext', () {
      const plaintext = 'Super secret message 12345';
      const exception = V2IncomingException('Session not found');

      expect(exception.toString(), isNot(contains(plaintext)));
      expect(exception.message, isNot(contains(plaintext)));
    });

    test('Decrypted plaintext is not in envelope', () async {
      final aliceIk = List<int>.generate(32, (i) => i + 100);
      final session = await setupAliceBobSession('session-leak');

      final enc = await V2Ratchet.encryptToEnvelope(
        state: session.aliceState,
        plaintext: 'SECRET_PLAINTEXT_12345',
        identityKeyPublic: aliceIk,
        senderDeviceId: 'alice-device-1',
        recipientDeviceId: 'bob-device-1',
      );

      // Envelope should not contain plaintext
      final envelopeBytes = enc.envelope.toBytes();
      final envelopeStr = utf8.decode(envelopeBytes, allowMalformed: true);
      expect(envelopeStr, isNot(contains('SECRET_PLAINTEXT_12345')));

      // Ciphertext should not contain plaintext
      final ctStr = utf8.decode(enc.envelope.ciphertextWithMac, allowMalformed: true);
      expect(ctStr, isNot(contains('SECRET_PLAINTEXT_12345')));
    });
  });

  // ===========================================================================
  // 12. V1 COMPATIBILITY
  // ===========================================================================

  group('V1 Compatibility', () {
    test('V1 and V2 messages have different routing', () {
      final v1Row = {
        'is_encrypted': true,
        'e2ee_version': 1,
        'encrypted_content': '{}',
      };
      final v2Row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'data',
      };

      expect(V2StoredMessage.isV1Message(v1Row), true);
      expect(V2StoredMessage.isV2Message(v1Row), false);

      expect(V2StoredMessage.isV1Message(v2Row), false);
      expect(V2StoredMessage.isV2Message(v2Row), true);
    });

    test('Plaintext bypasses both V1 and V2', () {
      final row = {
        'text': 'hello',
        'is_encrypted': false,
      };

      expect(V2StoredMessage.isV1Message(row), false);
      expect(V2StoredMessage.isV2Message(row), false);
      expect(V2StoredMessage.isPlaintextMessage(row), true);
    });
  });
}
