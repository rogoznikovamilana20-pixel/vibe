import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/v2_ratchet.dart';
import 'package:vibe_app/data/v2_media_crypto.dart';
import 'package:vibe_app/data/v2_message_storage.dart';

/// Phase 12F: Fuzz Tests
///
/// These tests feed random/malformed inputs to crypto primitives
/// and verify that the system fails safely (throws, never crashes
/// or produces incorrect output).
void main() {
  group('Fuzz: Envelope Deserialization', () {
    test('Random bytes do not cause unhandled exceptions', () {
      final rng = Random.secure();

      for (var i = 0; i < 1000; i++) {
        final len = rng.nextInt(200) + 1;
        final bytes = List<int>.generate(len, (_) => rng.nextInt(256));
        bytes[0] = 2; // Force version=2 to pass version check

        try {
          V2MessageEnvelope.fromBytes(bytes);
        } on V2RatchetException {
          // Expected — structural validation
        } catch (e) {
          fail('Unhandled exception on random bytes: $e');
        }
      }
    });

    test('Empty input is handled safely', () {
      expect(
        () => V2MessageEnvelope.fromBytes([]),
        throwsA(isA<V2RatchetException>()),
      );
    });

    test('Single byte input is handled safely', () {
      expect(
        () => V2MessageEnvelope.fromBytes([2]),
        throwsA(isA<V2RatchetException>()),
      );
    });
  });

  group('Fuzz: Base64 Envelope Decoding', () {
    test('Random base64 strings are handled safely', () {
      final rng = Random.secure();
      final validChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';

      for (var i = 0; i < 500; i++) {
        final len = rng.nextInt(200) + 1;
        final chars = List.generate(len, (_) => validChars[rng.nextInt(validChars.length)]);
        final b64 = chars.join();

        try {
          V2StoredMessage.decodeFromBase64(b64);
        } on V2RatchetException {
          // Expected
        } catch (e) {
          fail('Unhandled exception on random base64: $e');
        }
      }
    });

    test('Non-base64 characters are rejected', () {
      expect(
        () => V2StoredMessage.decodeFromBase64('!!!invalid!!!'),
        throwsA(isA<V2RatchetException>()),
      );
    });
  });

  group('Fuzz: Media Nonce Derivation', () {
    test('Chunk nonce with random mediaId never throws', () {
      final rng = Random.secure();

      for (var i = 0; i < 1000; i++) {
        final mediaId = List<int>.generate(16, (_) => rng.nextInt(256));
        final chunkIndex = rng.nextInt(100000);

        final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, chunkIndex);
        expect(nonce.length, 12);
      }
    });

    test('Thumbnail nonce with random mediaId never throws', () {
      final rng = Random.secure();

      for (var i = 0; i < 1000; i++) {
        final mediaId = List<int>.generate(16, (_) => rng.nextInt(256));

        final nonce = V2MediaCrypto.deriveThumbnailNonce(mediaId);
        expect(nonce.length, 12);
      }
    });

    test('MediaId hex conversion roundtrip', () {
      final rng = Random.secure();

      for (var i = 0; i < 1000; i++) {
        final mediaId = List<int>.generate(16, (_) => rng.nextInt(256));
        final hex = V2MediaCrypto.mediaIdToHex(mediaId);
        final restored = V2MediaCrypto.mediaIdFromHex(hex);

        expect(restored, mediaId);
      }
    });
  });

  group('Fuzz: AAD Construction', () {
    test('Chunk AAD with random inputs never throws', () {
      final rng = Random.secure();

      for (var i = 0; i < 500; i++) {
        final senderIk = List<int>.generate(32, (_) => rng.nextInt(256));
        final mediaId = List<int>.generate(16, (_) => rng.nextInt(256));

        final aad = V2MediaCrypto.buildChunkAad(
          senderIdentityKey: senderIk,
          senderDeviceId: 'device-${rng.nextInt(1000)}',
          recipientDeviceId: 'device-${rng.nextInt(1000)}',
          mediaId: mediaId,
          chunkIndex: rng.nextInt(100000),
          totalChunks: rng.nextInt(1000) + 1,
          mediaType: rng.nextInt(4),
          mimeType: 'application/octet-stream',
        );

        expect(aad.isNotEmpty, isTrue);
      }
    });

    test('Thumbnail AAD with random inputs never throws', () {
      final rng = Random.secure();

      for (var i = 0; i < 500; i++) {
        final senderIk = List<int>.generate(32, (_) => rng.nextInt(256));
        final mediaId = List<int>.generate(16, (_) => rng.nextInt(256));

        final aad = V2MediaCrypto.buildThumbnailAad(
          senderIdentityKey: senderIk,
          senderDeviceId: 'device-${rng.nextInt(1000)}',
          recipientDeviceId: 'device-${rng.nextInt(1000)}',
          mediaId: mediaId,
          mediaType: rng.nextInt(4),
          mimeType: 'image/jpeg',
        );

        expect(aad.isNotEmpty, isTrue);
      }
    });
  });

  group('Fuzz: Manifest HMAC', () {
    test('HMAC with random data never throws', () async {
      final rng = Random.secure();

      for (var i = 0; i < 200; i++) {
        final dataLen = rng.nextInt(10000) + 1;
        final data = List<int>.generate(dataLen, (_) => rng.nextInt(256));
        final key = List<int>.generate(32, (_) => rng.nextInt(256));

        final hmac = await V2MediaCrypto.computeManifestHmac(
          manifestBytes: data,
          senderIdentityKey: key,
        );

        expect(hmac.length, 32);
      }
    });

    test('HMAC verification with random data never throws', () async {
      final rng = Random.secure();

      for (var i = 0; i < 200; i++) {
        final data = List<int>.generate(rng.nextInt(1000) + 1, (_) => rng.nextInt(256));
        final key = List<int>.generate(32, (_) => rng.nextInt(256));
        final hmac = await V2MediaCrypto.computeManifestHmac(
          manifestBytes: data,
          senderIdentityKey: key,
        );

        final valid = await V2MediaCrypto.verifyManifestHmac(
          manifestBytes: data,
          senderIdentityKey: key,
          expectedHmac: hmac,
        );
        expect(valid, isTrue);
      }
    });
  });

  group('Fuzz: Key Wrapping', () {
    test('Wrap/unwrap with random keys never throws', () async {
      final rng = Random.secure();

      for (var i = 0; i < 200; i++) {
        final sessionKey = List<int>.generate(32, (_) => rng.nextInt(256));
        final mediaKey = List<int>.generate(32, (_) => rng.nextInt(256));
        final mediaId = List<int>.generate(16, (_) => rng.nextInt(256));

        final wrapped = await V2MediaCrypto.wrapMediaKey(
          sessionRootKey: sessionKey,
          mediaKey: mediaKey,
          mediaId: mediaId,
        );

        final unwrapped = await V2MediaCrypto.unwrapMediaKey(
          sessionRootKey: sessionKey,
          wrappedKey: wrapped.wrappedKey,
          nonce: wrapped.nonce,
          mediaId: mediaId,
        );

        expect(unwrapped, mediaKey);
      }
    });

    test('Wrap with different session keys produces different wrapped keys', () async {
      final rng = Random.secure();
      final mediaKey = List<int>.generate(32, (_) => rng.nextInt(256));
      final mediaId = List<int>.generate(16, (_) => rng.nextInt(256));

      final wrapped1 = await V2MediaCrypto.wrapMediaKey(
        sessionRootKey: List<int>.generate(32, (_) => rng.nextInt(256)),
        mediaKey: mediaKey,
        mediaId: mediaId,
      );

      final wrapped2 = await V2MediaCrypto.wrapMediaKey(
        sessionRootKey: List<int>.generate(32, (_) => rng.nextInt(256)),
        mediaKey: mediaKey,
        mediaId: mediaId,
      );

      // Different session keys should produce different wrapped keys
      expect(wrapped1.wrappedKey, isNot(equals(wrapped2.wrappedKey)));
    });
  });

  group('Fuzz: Edge Cases', () {
    test('Zero-length plaintext is handled', () async {
      final rng = Random.secure();
      final key = List<int>.generate(32, (_) => rng.nextInt(256));
      final nonce = List<int>.generate(12, (_) => rng.nextInt(256));

      final aesGcm = AesGcm.with256bits(nonceLength: 12);
      final secretBox = await aesGcm.encrypt(
        [],
        secretKey: SecretKey(key),
        nonce: nonce,
      );

      final plaintext = await aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(key),
      );

      expect(plaintext, isEmpty);
    });

    test('Max-size plaintext is handled', () async {
      final rng = Random.secure();
      final key = List<int>.generate(32, (_) => rng.nextInt(256));
      final nonce = List<int>.generate(12, (_) => rng.nextInt(256));

      // 64KB chunk size
      final plaintext = List<int>.generate(65536, (_) => rng.nextInt(256));

      final aesGcm = AesGcm.with256bits(nonceLength: 12);
      final secretBox = await aesGcm.encrypt(
        plaintext,
        secretKey: SecretKey(key),
        nonce: nonce,
      );

      final decrypted = await aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(key),
      );

      expect(decrypted, plaintext);
    });

    test('Media ID with all zeros is handled', () {
      final mediaId = List<int>.filled(16, 0);

      final chunkNonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);
      expect(chunkNonce.length, 12);

      final thumbNonce = V2MediaCrypto.deriveThumbnailNonce(mediaId);
      expect(thumbNonce.length, 12);

      // Thumb nonce should be all 0xFF (0 XOR 0xFF = 0xFF)
      expect(thumbNonce, everyElement(equals(0xFF)));
    });

    test('Media ID with all 0xFF is handled', () {
      final mediaId = List<int>.filled(16, 0xFF);

      final chunkNonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);
      expect(chunkNonce.length, 12);

      final thumbNonce = V2MediaCrypto.deriveThumbnailNonce(mediaId);
      expect(thumbNonce.length, 12);

      // Thumb nonce should be all zeros (0xFF XOR 0xFF = 0)
      expect(thumbNonce, everyElement(equals(0x00)));
    });
  });
}
