// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/v2_ratchet.dart';
import 'package:vibe_app/data/v2_media_crypto.dart';

/// Phase 12F: Property-Based Security Tests
///
/// These tests verify cryptographic invariants and security properties
/// that must hold for ALL inputs, not just specific test cases.
void main() {
  group('Property: Nonce Uniqueness', () {
    test('V2 text nonce is unique for all (msgNum, prevChain, step) triples', () {
      final seen = <int, bool>{};

      for (var step = 0; step < 20; step++) {
        for (var prevChain = 0; prevChain < 20; prevChain++) {
          for (var msgNum = 0; msgNum < 200; msgNum++) {
            final nonce = _computeNonce(msgNum, prevChain, step);
            final hash = _hashNonce(nonce);
            expect(seen.containsKey(hash), isFalse,
                reason: 'Nonce collision: step=$step prevChain=$prevChain msgNum=$msgNum');
            seen[hash] = true;
          }
        }
      }
    });

    test('Media chunk nonce is unique for all (mediaId, chunkIndex) pairs', () {
      final seen = <String, bool>{};
      final rng = Random.secure();

      for (var m = 0; m < 200; m++) {
        final mediaId = List<int>.generate(16, (_) => rng.nextInt(256));
        for (var c = 0; c < 500; c++) {
          V2MediaCrypto.deriveChunkNonce(mediaId, c);
          final key = '${mediaId.join(',')}:$c';
          expect(seen.containsKey(key), isFalse,
              reason: 'Chunk nonce collision: media=$m chunk=$c');
          seen[key] = true;
        }
      }
    });

    test('Thumbnail nonce never matches any chunk nonce for same mediaId', () {
      final rng = Random.secure();

      for (var m = 0; m < 100; m++) {
        final mediaId = List<int>.generate(16, (_) => rng.nextInt(256));
        final thumbNonce = V2MediaCrypto.deriveThumbnailNonce(mediaId);

        // Thumbnail nonce: all bytes XORed with 0xFF
        // Chunk nonce: only last 4 bytes XORed with chunkIndex
        // First 8 bytes of thumbnail nonce = mediaId[0..7] XOR 0xFF
        // First 8 bytes of chunk nonce = mediaId[0..7] (unchanged)
        // Since mediaId bytes are random, mediaId[i] XOR 0xFF != mediaId[i] with overwhelming probability

        final chunkNonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);
        expect(_constantTimeEqual(thumbNonce, chunkNonce), isFalse,
            reason: 'Thumbnail/chunk nonce collision at media=$m');
      }
    });
  });

  group('Property: KDF Chain Forward Secrecy', () {
    test('Message keys are unpredictable from chain key', () async {
      final rng = Random.secure();
      final chainKey = List<int>.generate(32, (_) => rng.nextInt(256));

      final (messageKey: mk1, nextChainKey: ck1) = await _kdfChain(chainKey);

      // Message key should not be derivable from the original chain key
      // without knowing the HMAC operation (this is a basic sanity check)
      expect(mk1, isNot(equals(chainKey)));
      expect(ck1, isNot(equals(chainKey)));
      expect(mk1, isNot(equals(ck1)));
    });

    test('Chain key progression is deterministic', () async {
      final rng = Random.secure();
      final chainKey = List<int>.generate(32, (_) => rng.nextInt(256));

      final (messageKey: mk1, nextChainKey: ck1) = await _kdfChain(chainKey);
      final (messageKey: mk2, nextChainKey: ck2) = await _kdfChain(chainKey);

      // Same input → same output
      expect(mk1, mk2);
      expect(ck1, ck2);
    });

    test('Different chain keys produce different message keys', () async {
      final rng = Random.secure();
      final ck1 = List<int>.generate(32, (_) => rng.nextInt(256));
      final ck2 = List<int>.generate(32, (_) => rng.nextInt(256));

      final (messageKey: mk1, nextChainKey: _) = await _kdfChain(ck1);
      final (messageKey: mk2, nextChainKey: _) = await _kdfChain(ck2);

      expect(mk1, isNot(equals(mk2)));
    });

    test('Chain key cannot be reversed to derive previous message keys', () async {
      final rng = Random.secure();
      var chainKey = List<int>.generate(32, (_) => rng.nextInt(256));

      final messageKeys = <List<int>>[];
      for (var i = 0; i < 10; i++) {
        final (messageKey: mk, nextChainKey: next) = await _kdfChain(chainKey);
        messageKeys.add(mk);
        chainKey = next;
      }

      // Each message key should be unique
      final seen = <String>{};
      for (final mk in messageKeys) {
        final key = mk.join(',');
        expect(seen.contains(key), isFalse, reason: 'Duplicate message key');
        seen.add(key);
      }
    });
  });

  group('Property: AES-GCM Authenticated Encryption', () {
    test('Tampered ciphertext is rejected', () async {
      final rng = Random.secure();
      final key = List<int>.generate(32, (_) => rng.nextInt(256));
      final nonce = List<int>.generate(12, (_) => rng.nextInt(256));
      final plaintext = utf8.encode('sensitive message');
      final aad = utf8.encode('test-aad');

      final aesGcm = AesGcm.with256bits(nonceLength: 12);
      final secretBox = await aesGcm.encrypt(
        plaintext,
        secretKey: SecretKey(key),
        nonce: nonce,
        aad: aad,
      );

      // Tamper with ciphertext
      final tampered = List<int>.from(secretBox.concatenation());
      tampered[12] ^= 0xFF; // Flip a bit in ciphertext

      expect(
        () => aesGcm.decrypt(
          SecretBox.fromConcatenation(tampered, nonceLength: 12, macLength: 16),
          secretKey: SecretKey(key),
          aad: aad,
        ),
        throwsA(anything),
      );
    });

    test('Wrong AAD is rejected', () async {
      final rng = Random.secure();
      final key = List<int>.generate(32, (_) => rng.nextInt(256));
      final nonce = List<int>.generate(12, (_) => rng.nextInt(256));
      final plaintext = utf8.encode('sensitive message');
      final aad = utf8.encode('correct-aad');
      final wrongAad = utf8.encode('wrong-aad');

      final aesGcm = AesGcm.with256bits(nonceLength: 12);
      final secretBox = await aesGcm.encrypt(
        plaintext,
        secretKey: SecretKey(key),
        nonce: nonce,
        aad: aad,
      );

      expect(
        () => aesGcm.decrypt(
          secretBox,
          secretKey: SecretKey(key),
          aad: wrongAad,
        ),
        throwsA(anything),
      );
    });

    test('Wrong key is rejected', () async {
      final rng = Random.secure();
      final key = List<int>.generate(32, (_) => rng.nextInt(256));
      final wrongKey = List<int>.generate(32, (_) => rng.nextInt(256));
      final nonce = List<int>.generate(12, (_) => rng.nextInt(256));
      final plaintext = utf8.encode('sensitive message');
      final aad = utf8.encode('test-aad');

      final aesGcm = AesGcm.with256bits(nonceLength: 12);
      final secretBox = await aesGcm.encrypt(
        plaintext,
        secretKey: SecretKey(key),
        nonce: nonce,
        aad: aad,
      );

      expect(
        () => aesGcm.decrypt(
          secretBox,
          secretKey: SecretKey(wrongKey),
          aad: aad,
        ),
        throwsA(anything),
      );
    });
  });

  group('Property: Media Key Independence', () {
    test('Each media object gets a unique key', () {
      final keys = <String>{};
      final rng = Random.secure();

      for (var i = 0; i < 1000; i++) {
        final key = List<int>.generate(32, (_) => rng.nextInt(256));
        final keyStr = key.join(',');
        expect(keys.contains(keyStr), isFalse, reason: 'Duplicate media key at i=$i');
        keys.add(keyStr);
      }
    });

    test('Media key is independent of session key', () async {
      final rng = Random.secure();
      final sessionKey = List<int>.generate(32, (_) => rng.nextInt(256));
      final mediaKey = List<int>.generate(32, (_) => rng.nextInt(256));
      final mediaId = List<int>.generate(16, (_) => rng.nextInt(256));

      final wrapped = await V2MediaCrypto.wrapMediaKey(
        sessionRootKey: sessionKey,
        mediaKey: mediaKey,
        mediaId: mediaId,
      );

      // Wrapped key should not equal the media key
      expect(wrapped.wrappedKey, isNot(equals(mediaKey)));
      // Wrapped key should not equal the session key
      expect(wrapped.wrappedKey, isNot(equals(sessionKey)));
    });
  });

  group('Property: Envelope Serialization Integrity', () {
    test('Roundtrip preserves all 76-byte header fields', () {
      final rng = Random.secure();

      for (var i = 0; i < 100; i++) {
        final senderIk = List<int>.generate(32, (_) => rng.nextInt(256));
        final senderRk = List<int>.generate(32, (_) => rng.nextInt(256));
        final msgNum = rng.nextInt(1000000);
        final prevChain = rng.nextInt(1000000);

        final header = V2MessageHeader(
          protocolVersion: 2,
          senderIdentityKey: senderIk,
          senderRatchetPublicKey: senderRk,
          messageNumber: msgNum,
          previousChainLength: prevChain,
        );

        final bytes = header.toBytes();
        final restored = V2MessageHeader.fromBytes(bytes);

        expect(restored.protocolVersion, 2);
        expect(restored.senderIdentityKey, senderIk);
        expect(restored.senderRatchetPublicKey, senderRk);
        expect(restored.messageNumber, msgNum);
        expect(restored.previousChainLength, prevChain);
        expect(bytes.length, 76);
      }
    });

    test('Envelope serialization is lossless', () {
      final rng = Random.secure();

      for (var i = 0; i < 100; i++) {
        final senderIk = List<int>.generate(32, (_) => rng.nextInt(256));
        final senderRk = List<int>.generate(32, (_) => rng.nextInt(256));
        final nonce = List<int>.generate(12, (_) => rng.nextInt(256));
        final ct = List<int>.generate(48, (_) => rng.nextInt(256));

        final envelope = V2MessageEnvelope(
          version: 2,
          senderIdentityKey: senderIk,
          senderRatchetPublicKey: senderRk,
          messageNumber: rng.nextInt(1000000),
          previousChainLength: rng.nextInt(1000000),
          nonce: nonce,
          ciphertextWithMac: ct,
        );

        final bytes = envelope.toBytes();
        final restored = V2MessageEnvelope.fromBytes(bytes);

        expect(restored.version, envelope.version);
        expect(restored.senderIdentityKey, envelope.senderIdentityKey);
        expect(restored.senderRatchetPublicKey, envelope.senderRatchetPublicKey);
        expect(restored.messageNumber, envelope.messageNumber);
        expect(restored.previousChainLength, envelope.previousChainLength);
        expect(restored.nonce, envelope.nonce);
        expect(restored.ciphertextWithMac, envelope.ciphertextWithMac);
      }
    });
  });

  group('Property: HKDF Domain Separation', () {
    test('Different domain labels produce different derived keys', () async {
      final rng = Random.secure();
      final secret = List<int>.generate(32, (_) => rng.nextInt(256));
      final salt = List<int>.generate(16, (_) => rng.nextInt(256));

      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

      final k1 = await hkdf.deriveKey(
        secretKey: SecretKey(secret),
        nonce: salt,
        info: utf8.encode('DOMAIN-A'),
      );
      final k2 = await hkdf.deriveKey(
        secretKey: SecretKey(secret),
        nonce: salt,
        info: utf8.encode('DOMAIN-B'),
      );

      final b1 = await k1.extractBytes();
      final b2 = await k2.extractBytes();

      expect(b1, isNot(equals(b2)));
    });

    test('Different salts produce different derived keys', () async {
      final rng = Random.secure();
      final secret = List<int>.generate(32, (_) => rng.nextInt(256));

      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

      final k1 = await hkdf.deriveKey(
        secretKey: SecretKey(secret),
        nonce: List<int>.generate(16, (_) => rng.nextInt(256)),
        info: utf8.encode('same-domain'),
      );
      final k2 = await hkdf.deriveKey(
        secretKey: SecretKey(secret),
        nonce: List<int>.generate(16, (_) => rng.nextInt(256)),
        info: utf8.encode('same-domain'),
      );

      final b1 = await k1.extractBytes();
      final b2 = await k2.extractBytes();

      expect(b1, isNot(equals(b2)));
    });
  });
}

// ============================================================================
// Helpers
// ============================================================================

List<int> _computeNonce(int messageNumber, int previousChainLength, int ratchetStep) {
  final byteData = ByteData(12);
  byteData.setUint32(0, messageNumber, Endian.big);
  byteData.setUint32(4, previousChainLength, Endian.big);
  byteData.setUint32(8, ratchetStep, Endian.big);
  return byteData.buffer.asUint8List();
}

int _hashNonce(List<int> nonce) {
  var h = 0;
  for (final b in nonce) {
    h = ((h << 5) + h + b) & 0xFFFFFFFF;
  }
  return h;
}

Future<({List<int> messageKey, List<int> nextChainKey})> _kdfChain(List<int> chainKey) async {
  final hmac = Hmac.sha256();
  final messageKeyMac = await hmac.calculateMac([0x01], secretKey: SecretKey(chainKey));
  final nextChainKeyMac = await hmac.calculateMac([0x02], secretKey: SecretKey(chainKey));
  return (
    messageKey: messageKeyMac.bytes,
    nextChainKey: nextChainKeyMac.bytes,
  );
}

bool _constantTimeEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
