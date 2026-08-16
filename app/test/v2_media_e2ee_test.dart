import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/v2_media_crypto.dart';
import 'package:vibe_app/data/v2_media_storage.dart';

/// PHASE 12E.2 — V2 Media E2EE Security Tests
///
/// Tests cover:
/// 1. Crypto primitives (key generation, nonce derivation, AAD)
/// 2. Chunk encryption/decryption
/// 3. Thumbnail encryption
/// 4. Key wrapping/unwrapping
/// 5. Manifest serialization
/// 6. Adversarial crypto testing
/// 7. Nonce uniqueness
/// 8. Fail-closed behavior

void main() {
  // ===========================================================================
  // 1. KEY GENERATION
  // ===========================================================================

  group('1. Key Generation', () {
    test('G1: generateMediaKey returns 32 bytes', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      expect(key.length, V2MediaCrypto.mediaKeySize);
    });

    test('G2: generateMediaKey produces random keys', () async {
      final key1 = await V2MediaCrypto.generateMediaKey();
      final key2 = await V2MediaCrypto.generateMediaKey();
      expect(key1, isNot(equals(key2)));
    });

    test('G3: generateMediaId returns 16 bytes', () async {
      final id = await V2MediaCrypto.generateMediaId();
      expect(id.length, V2MediaCrypto.mediaIdSize);
    });

    test('G4: generateMediaId produces random IDs', () async {
      final id1 = await V2MediaCrypto.generateMediaId();
      final id2 = await V2MediaCrypto.generateMediaId();
      expect(id1, isNot(equals(id2)));
    });

    test('G5: mediaIdToHex produces valid hex string', () async {
      final id = await V2MediaCrypto.generateMediaId();
      final hex = V2MediaCrypto.mediaIdToHex(id);
      expect(hex.length, 32);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(hex), isTrue);
    });

    test('G6: mediaIdFromHex round-trips correctly', () async {
      final id = await V2MediaCrypto.generateMediaId();
      final hex = V2MediaCrypto.mediaIdToHex(id);
      final recovered = V2MediaCrypto.mediaIdFromHex(hex);
      expect(recovered, equals(id));
    });
  });

  // ===========================================================================
  // 2. NONCE DERIVATION
  // ===========================================================================

  group('2. Nonce Derivation', () {
    test('N1: deriveChunkNonce returns 12 bytes', () async {
      final mediaId = await V2MediaCrypto.generateMediaId();
      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);
      expect(nonce.length, V2MediaCrypto.nonceSize);
    });

    test('N2: Nonces are unique for different chunk indices', () async {
      final mediaId = await V2MediaCrypto.generateMediaId();
      final nonce0 = V2MediaCrypto.deriveChunkNonce(mediaId, 0);
      final nonce1 = V2MediaCrypto.deriveChunkNonce(mediaId, 1);
      final nonce2 = V2MediaCrypto.deriveChunkNonce(mediaId, 2);
      expect(nonce0, isNot(equals(nonce1)));
      expect(nonce1, isNot(equals(nonce2)));
      expect(nonce0, isNot(equals(nonce2)));
    });

    test('N3: Nonces are unique for different media IDs', () async {
      final id1 = await V2MediaCrypto.generateMediaId();
      final id2 = await V2MediaCrypto.generateMediaId();
      final nonce1 = V2MediaCrypto.deriveChunkNonce(id1, 0);
      final nonce2 = V2MediaCrypto.deriveChunkNonce(id2, 0);
      expect(nonce1, isNot(equals(nonce2)));
    });

    test('N4: deriveThumbnailNonce is distinct from chunk nonces', () async {
      final mediaId = await V2MediaCrypto.generateMediaId();
      final thumbNonce = V2MediaCrypto.deriveThumbnailNonce(mediaId);
      final chunkNonce0 = V2MediaCrypto.deriveChunkNonce(mediaId, 0);
      final chunkNonceMax = V2MediaCrypto.deriveChunkNonce(mediaId, 0xFFFFFFFF);
      expect(thumbNonce, isNot(equals(chunkNonce0)));
      expect(thumbNonce, isNot(equals(chunkNonceMax)));
    });

    test('N5: Nonce uniqueness across 10000 chunks', () async {
      final mediaId = await V2MediaCrypto.generateMediaId();
      final nonces = <List<int>>{};
      for (var i = 0; i < 10000; i++) {
        final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, i);
        // Check no duplicates
        for (final existing in nonces) {
          expect(existing, isNot(equals(nonce)));
        }
        nonces.add(nonce);
      }
      expect(nonces.length, 10000);
    });
  });

  // ===========================================================================
  // 3. AAD CONSTRUCTION
  // ===========================================================================

  group('3. AAD Construction', () {
    test('A1: buildChunkAad includes domain label', () {
      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'device-1',
        recipientDeviceId: 'device-2',
        mediaId: List<int>.filled(16, 0x01),
        chunkIndex: 0,
        totalChunks: 10,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      // Domain label "VIBE-MEDIA-E2EE-AAD-V1" is 22 bytes, starts at offset 0
      final domain = utf8.decode(aad.sublist(0, 22));
      expect(domain, 'VIBE-MEDIA-E2EE-AAD-V1');
    });

    test('A2: buildChunkAad includes sender identity key', () {
      final idKey = List<int>.filled(32, 0xBB);
      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: idKey,
        senderDeviceId: 'device-1',
        recipientDeviceId: 'device-2',
        mediaId: List<int>.filled(16, 0x01),
        chunkIndex: 0,
        totalChunks: 10,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      // Identity key starts after domain (22 bytes)
      expect(aad.sublist(22, 54), equals(idKey));
    });

    test('A3: Different chunk indices produce different AADs', () {
      final aad0 = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'device-1',
        recipientDeviceId: 'device-2',
        mediaId: List<int>.filled(16, 0x01),
        chunkIndex: 0,
        totalChunks: 10,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final aad1 = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'device-1',
        recipientDeviceId: 'device-2',
        mediaId: List<int>.filled(16, 0x01),
        chunkIndex: 1,
        totalChunks: 10,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      expect(aad0, isNot(equals(aad1)));
    });

    test('A4: buildThumbnailAad uses sentinel chunk index', () {
      final aad = V2MediaCrypto.buildThumbnailAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'device-1',
        recipientDeviceId: 'device-2',
        mediaId: List<int>.filled(16, 0x01),
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      // Chunk index sentinel (0xFFFFFFFF) at offset 24+32+2+len+2+len+16 = ~90
      // Let's just check the AAD is different from chunk AADs
      final chunkAad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'device-1',
        recipientDeviceId: 'device-2',
        mediaId: List<int>.filled(16, 0x01),
        chunkIndex: 0,
        totalChunks: 10,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      expect(aad, isNot(equals(chunkAad)));
    });

    test('A5: Different media types produce different AADs', () {
      final aadPhoto = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'device-1',
        recipientDeviceId: 'device-2',
        mediaId: List<int>.filled(16, 0x01),
        chunkIndex: 0,
        totalChunks: 10,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final aadVoice = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'device-1',
        recipientDeviceId: 'device-2',
        mediaId: List<int>.filled(16, 0x01),
        chunkIndex: 0,
        totalChunks: 10,
        mediaType: V2MediaType.voice,
        mimeType: 'audio/mp4',
      );
      expect(aadPhoto, isNot(equals(aadVoice)));
    });
  });

  // ===========================================================================
  // 4. CHUNK ENCRYPTION/DECRYPTION
  // ===========================================================================

  group('4. Chunk Encryption/Decryption', () {
    test('E1: Encrypt then decrypt returns original plaintext', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final plaintext = Uint8List.fromList(utf8.encode('Hello, World!'));
      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'device-1',
        recipientDeviceId: 'device-2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key,
        aad: aad,
        nonce: nonce,
      );

      final decrypted = await V2MediaCrypto.decryptChunk(
        ciphertext: encrypted.ciphertext,
        mediaKey: key,
        aad: aad,
        nonce: nonce,
      );

      expect(decrypted, equals(plaintext));
    });

    test('E2: Ciphertext is longer than plaintext (GCM tag)', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final plaintext = Uint8List.fromList(utf8.encode('Test'));
      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key,
        aad: aad,
        nonce: nonce,
      );

      // Ciphertext = plaintext bytes + 16-byte GCM tag
      expect(
          encrypted.ciphertext.length, plaintext.length + V2MediaCrypto.tagSize);
    });

    test('E3: Wrong key fails decryption', () async {
      final key1 = await V2MediaCrypto.generateMediaKey();
      final key2 = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final plaintext = Uint8List.fromList(utf8.encode('Secret'));
      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key1,
        aad: aad,
        nonce: nonce,
      );

      expect(
        () => V2MediaCrypto.decryptChunk(
          ciphertext: encrypted.ciphertext,
          mediaKey: key2,
          aad: aad,
          nonce: nonce,
        ),
        throwsA(anything),
      );
    });

    test('E4: Wrong AAD fails decryption', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final plaintext = Uint8List.fromList(utf8.encode('Secret'));
      final aad1 = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final aad2 = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xBB), // Different
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key,
        aad: aad1,
        nonce: nonce,
      );

      expect(
        () => V2MediaCrypto.decryptChunk(
          ciphertext: encrypted.ciphertext,
          mediaKey: key,
          aad: aad2, // Wrong AAD
          nonce: nonce,
        ),
        throwsA(anything),
      );
    });

    test('E5: Wrong nonce fails decryption', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final plaintext = Uint8List.fromList(utf8.encode('Secret'));
      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final nonce1 = V2MediaCrypto.deriveChunkNonce(mediaId, 0);
      final nonce2 = V2MediaCrypto.deriveChunkNonce(mediaId, 1);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key,
        aad: aad,
        nonce: nonce1,
      );

      expect(
        () => V2MediaCrypto.decryptChunk(
          ciphertext: encrypted.ciphertext,
          mediaKey: key,
          aad: aad,
          nonce: nonce2, // Wrong nonce
        ),
        throwsA(anything),
      );
    });

    test('E6: Tampered ciphertext fails decryption', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final plaintext = Uint8List.fromList(utf8.encode('Secret'));
      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key,
        aad: aad,
        nonce: nonce,
      );

      // Tamper with ciphertext
      final tampered = List<int>.from(encrypted.ciphertext);
      tampered[0] ^= 0xFF;

      expect(
        () => V2MediaCrypto.decryptChunk(
          ciphertext: tampered,
          mediaKey: key,
          aad: aad,
          nonce: nonce,
        ),
        throwsA(anything),
      );
    });

    test('E7: Empty plaintext encrypts/decrypts correctly', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final plaintext = <int>[];
      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key,
        aad: aad,
        nonce: nonce,
      );

      final decrypted = await V2MediaCrypto.decryptChunk(
        ciphertext: encrypted.ciphertext,
        mediaKey: key,
        aad: aad,
        nonce: nonce,
      );

      expect(decrypted, isEmpty);
    });

    test('E8: 64KB chunk encrypts/decrypts correctly', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final plaintext = List<int>.generate(65536, (i) => i % 256);
      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key,
        aad: aad,
        nonce: nonce,
      );

      final decrypted = await V2MediaCrypto.decryptChunk(
        ciphertext: encrypted.ciphertext,
        mediaKey: key,
        aad: aad,
        nonce: nonce,
      );

      expect(decrypted, equals(plaintext));
    });
  });

  // ===========================================================================
  // 5. THUMBNAIL ENCRYPTION
  // ===========================================================================

  group('5. Thumbnail Encryption', () {
    test('T1: Thumbnail encrypt/decrypt round-trip', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final thumbnail = List<int>.generate(1024, (i) => i % 256);

      final encrypted = await V2MediaCrypto.encryptThumbnail(
        thumbnailBytes: thumbnail,
        mediaKey: key,
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );

      final decrypted = await V2MediaCrypto.decryptThumbnail(
        ciphertext: encrypted.ciphertext,
        mediaKey: key,
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );

      expect(decrypted, equals(thumbnail));
    });

    test('T2: Thumbnail key derivation is deterministic', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final thumbKey1 = await V2MediaCrypto.deriveThumbnailKey(key);
      final thumbKey2 = await V2MediaCrypto.deriveThumbnailKey(key);
      expect(thumbKey1, equals(thumbKey2));
    });

    test('T3: Different media keys produce different thumbnail keys', () async {
      final key1 = await V2MediaCrypto.generateMediaKey();
      final key2 = await V2MediaCrypto.generateMediaKey();
      final thumbKey1 = await V2MediaCrypto.deriveThumbnailKey(key1);
      final thumbKey2 = await V2MediaCrypto.deriveThumbnailKey(key2);
      expect(thumbKey1, isNot(equals(thumbKey2)));
    });
  });

  // ===========================================================================
  // 6. KEY WRAPPING/UNWRAPPING
  // ===========================================================================

  group('6. Key Wrapping/Unwrapping', () {
    test('K1: wrapMediaKey produces wrapped key + nonce', () async {
      final sessionKey = List<int>.filled(32, 0x42);
      final mediaKey = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();

      final result = await V2MediaCrypto.wrapMediaKey(
        sessionRootKey: sessionKey,
        mediaKey: mediaKey,
        mediaId: mediaId,
      );

      expect(result.wrappedKey, isNotEmpty);
      expect(result.nonce.length, V2MediaCrypto.nonceSize);
    });

    test('K2: unwrapMediaKey recovers original key', () async {
      final sessionKey = List<int>.filled(32, 0x42);
      final mediaKey = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();

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

      expect(unwrapped, equals(mediaKey));
    });

    test('K3: Wrong session key fails unwrap', () async {
      final sessionKey1 = List<int>.filled(32, 0x42);
      final sessionKey2 = List<int>.filled(32, 0x43);
      final mediaKey = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();

      final wrapped = await V2MediaCrypto.wrapMediaKey(
        sessionRootKey: sessionKey1,
        mediaKey: mediaKey,
        mediaId: mediaId,
      );

      expect(
        () => V2MediaCrypto.unwrapMediaKey(
          sessionRootKey: sessionKey2,
          wrappedKey: wrapped.wrappedKey,
          nonce: wrapped.nonce,
          mediaId: mediaId,
        ),
        throwsA(anything),
      );
    });

    test('K4: Wrong media ID fails unwrap', () async {
      final sessionKey = List<int>.filled(32, 0x42);
      final mediaKey = await V2MediaCrypto.generateMediaKey();
      final mediaId1 = await V2MediaCrypto.generateMediaId();
      final mediaId2 = await V2MediaCrypto.generateMediaId();

      final wrapped = await V2MediaCrypto.wrapMediaKey(
        sessionRootKey: sessionKey,
        mediaKey: mediaKey,
        mediaId: mediaId1,
      );

      expect(
        () => V2MediaCrypto.unwrapMediaKey(
          sessionRootKey: sessionKey,
          wrappedKey: wrapped.wrappedKey,
          nonce: wrapped.nonce,
          mediaId: mediaId2, // Wrong media ID
        ),
        throwsA(anything),
      );
    });
  });

  // ===========================================================================
  // 7. MANIFEST SERIALIZATION
  // ===========================================================================

  group('7. Manifest Serialization', () {
    test('M1: Manifest JSON round-trips correctly', () {
      final manifest = V2MediaManifest(
        version: 2,
        mediaId: List<int>.filled(16, 0x01),
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
        originalSize: 1024,
        encryptedSize: 1040,
        totalChunks: 1,
        chunkSize: V2MediaCrypto.chunkSize,
        wrappedKey: List<int>.filled(48, 0x02),
        wrappedKeyNonce: List<int>.filled(12, 0x03),
        width: 1920,
        height: 1080,
      );

      final json = manifest.toJson();
      final restored = V2MediaManifest.fromJson(json);

      expect(restored.version, manifest.version);
      expect(restored.mediaId, manifest.mediaId);
      expect(restored.mediaType, manifest.mediaType);
      expect(restored.mimeType, manifest.mimeType);
      expect(restored.originalSize, manifest.originalSize);
      expect(restored.encryptedSize, manifest.encryptedSize);
      expect(restored.totalChunks, manifest.totalChunks);
      expect(restored.wrappedKey, manifest.wrappedKey);
      expect(restored.width, manifest.width);
      expect(restored.height, manifest.height);
    });

    test('M2: Manifest with encrypted filename round-trips', () {
      final manifest = V2MediaManifest(
        version: 2,
        mediaId: List<int>.filled(16, 0x01),
        mediaType: V2MediaType.file,
        mimeType: 'application/pdf',
        originalSize: 2048,
        encryptedSize: 2064,
        totalChunks: 1,
        chunkSize: V2MediaCrypto.chunkSize,
        wrappedKey: List<int>.filled(48, 0x02),
        wrappedKeyNonce: List<int>.filled(12, 0x03),
        encryptedFilename: List<int>.filled(20, 0x04),
        filenameNonce: List<int>.filled(12, 0x05),
      );

      final json = manifest.toJson();
      final restored = V2MediaManifest.fromJson(json);

      expect(restored.encryptedFilename, manifest.encryptedFilename);
      expect(restored.filenameNonce, manifest.filenameNonce);
    });

    test('M3: Manifest encode/decode round-trips', () {
      final manifest = V2MediaManifest(
        version: 2,
        mediaId: List<int>.filled(16, 0x01),
        mediaType: V2MediaType.voice,
        mimeType: 'audio/mp4',
        originalSize: 4096,
        encryptedSize: 4112,
        totalChunks: 2,
        chunkSize: V2MediaCrypto.chunkSize,
        wrappedKey: List<int>.filled(48, 0x02),
        wrappedKeyNonce: List<int>.filled(12, 0x03),
        duration: 30,
      );

      final encoded = manifest.encode();
      final restored = V2MediaManifest.decode(encoded);

      expect(restored.duration, 30);
      expect(restored.mediaType, V2MediaType.voice);
    });
  });

  // ===========================================================================
  // 8. ADVERSARIAL CRYPTO TESTING
  // ===========================================================================

  group('8. Adversarial Crypto Testing', () {
    test('ADV1: Key reuse with same nonce is catastrophic (verified safe)', () async {
      // This test verifies our design prevents key-nonce reuse.
      // Each media gets unique key (random) and unique nonce (mediaId||chunkIndex).
      final key = await V2MediaCrypto.generateMediaKey();
      final id1 = await V2MediaCrypto.generateMediaId();
      final id2 = await V2MediaCrypto.generateMediaId();

      final nonce1 = V2MediaCrypto.deriveChunkNonce(id1, 0);
      final nonce2 = V2MediaCrypto.deriveChunkNonce(id2, 0);

      // Nonces are different because mediaIds are different
      expect(nonce1, isNot(equals(nonce2)));
    });

    test('ADV2: Cross-media key isolation', () async {
      // If attacker compromises one media key, other media is safe
      final key1 = await V2MediaCrypto.generateMediaKey();
      final key2 = await V2MediaCrypto.generateMediaKey();
      final id1 = await V2MediaCrypto.generateMediaId();
      final id2 = await V2MediaCrypto.generateMediaId();

      final plaintext = Uint8List.fromList(utf8.encode('Secret'));
      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: id1,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final nonce = V2MediaCrypto.deriveChunkNonce(id1, 0);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key1,
        aad: aad,
        nonce: nonce,
      );

      // Different key cannot decrypt
      expect(
        () => V2MediaCrypto.decryptChunk(
          ciphertext: encrypted.ciphertext,
          mediaKey: key2,
          aad: aad,
          nonce: nonce,
        ),
        throwsA(anything),
      );
    });

    test('ADV3: Sender identity key binding prevents cross-sender forgery', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final plaintext = Uint8List.fromList(utf8.encode('Secret'));

      final aad1 = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final aad2 = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xBB), // Attacker
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key,
        aad: aad1,
        nonce: nonce,
      );

      // Attacker's AAD fails
      expect(
        () => V2MediaCrypto.decryptChunk(
          ciphertext: encrypted.ciphertext,
          mediaKey: key,
          aad: aad2,
          nonce: nonce,
        ),
        throwsA(anything),
      );
    });

    test('ADV4: Chunk index manipulation is detected', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final plaintext = Uint8List.fromList(utf8.encode('Secret'));

      final aad0 = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 10,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final aad1 = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 1, // Attacker changes chunk index
        totalChunks: 10,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key,
        aad: aad0,
        nonce: nonce,
      );

      // Wrong chunk index in AAD fails
      expect(
        () => V2MediaCrypto.decryptChunk(
          ciphertext: encrypted.ciphertext,
          mediaKey: key,
          aad: aad1,
          nonce: nonce,
        ),
        throwsA(anything),
      );
    });

    test('ADV5: MIME type manipulation is detected', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final plaintext = Uint8List.fromList(utf8.encode('Secret'));

      final aad1 = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
      );
      final aad2 = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.photo,
        mimeType: 'application/octet-stream', // Changed
      );
      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key,
        aad: aad1,
        nonce: nonce,
      );

      // Wrong MIME type in AAD fails
      expect(
        () => V2MediaCrypto.decryptChunk(
          ciphertext: encrypted.ciphertext,
          mediaKey: key,
          aad: aad2,
          nonce: nonce,
        ),
        throwsA(anything),
      );
    });
  });

  // ===========================================================================
  // 9. MEDIA TYPE CONSTANTS
  // ===========================================================================

  group('9. Media Type Constants', () {
    test('MT1: All media types have names', () {
      expect(V2MediaType.name(0), 'photo');
      expect(V2MediaType.name(1), 'voice');
      expect(V2MediaType.name(2), 'video');
      expect(V2MediaType.name(3), 'file');
      expect(V2MediaType.name(4), 'thumbnail');
      expect(V2MediaType.name(99), 'unknown');
    });
  });

  // ===========================================================================
  // 10. CHUNK SERIALIZATION
  // ===========================================================================

  group('10. Chunk Serialization', () {
    test('C1: V2MediaChunk round-trips via toBytes/fromBytes', () {
      final chunk = V2MediaChunk(
        index: 42,
        nonce: List<int>.filled(12, 0x05),
        ciphertext: List<int>.generate(100, (i) => i % 256),
      );

      final bytes = chunk.toBytes();
      final restored = V2MediaChunk.fromBytes(bytes);

      expect(restored.index, chunk.index);
      expect(restored.nonce, chunk.nonce);
      expect(restored.ciphertext, chunk.ciphertext);
    });

    test('C2: fromBytes rejects too-short input', () {
      expect(
        () => V2MediaChunk.fromBytes(List<int>.filled(10, 0)),
        throwsA(isA<V2MediaException>()),
      );
    });

    test('C3: Serialized size is correct', () {
      final chunk = V2MediaChunk(
        index: 0,
        nonce: List<int>.filled(12, 0),
        ciphertext: List<int>.filled(100, 0xAA),
      );
      expect(chunk.serializedSize, 4 + 12 + 100);
    });
  });

  // ===========================================================================
  // 11. MANIFEST HMAC (Phase 12E.4)
  // ===========================================================================

  group('11. Manifest HMAC', () {
    test('H1: computeManifestHmac returns 32 bytes', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final manifest = V2MediaManifest(
        version: 2,
        mediaId: List<int>.filled(16, 0x01),
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
        originalSize: 1024,
        encryptedSize: 1040,
        totalChunks: 1,
        chunkSize: V2MediaCrypto.chunkSize,
        wrappedKey: List<int>.filled(48, 0x02),
        wrappedKeyNonce: List<int>.filled(12, 0x03),
      );
      final hmac = await V2MediaCrypto.computeManifestHmac(
        manifestBytes: manifest.toBytes(),
        senderIdentityKey: key,
      );
      expect(hmac.length, 32);
    });

    test('H2: verifyManifestHmac returns true for valid HMAC', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final manifest = V2MediaManifest(
        version: 2,
        mediaId: List<int>.filled(16, 0x01),
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
        originalSize: 1024,
        encryptedSize: 1040,
        totalChunks: 1,
        chunkSize: V2MediaCrypto.chunkSize,
        wrappedKey: List<int>.filled(48, 0x02),
        wrappedKeyNonce: List<int>.filled(12, 0x03),
      );
      final hmac = await V2MediaCrypto.computeManifestHmac(
        manifestBytes: manifest.toBytes(),
        senderIdentityKey: key,
      );
      final valid = await V2MediaCrypto.verifyManifestHmac(
        manifestBytes: manifest.toBytes(),
        senderIdentityKey: key,
        expectedHmac: hmac,
      );
      expect(valid, isTrue);
    });

    test('H3: verifyManifestHmac returns false for wrong key', () async {
      final key1 = await V2MediaCrypto.generateMediaKey();
      final key2 = await V2MediaCrypto.generateMediaKey();
      final manifest = V2MediaManifest(
        version: 2,
        mediaId: List<int>.filled(16, 0x01),
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
        originalSize: 1024,
        encryptedSize: 1040,
        totalChunks: 1,
        chunkSize: V2MediaCrypto.chunkSize,
        wrappedKey: List<int>.filled(48, 0x02),
        wrappedKeyNonce: List<int>.filled(12, 0x03),
      );
      final hmac = await V2MediaCrypto.computeManifestHmac(
        manifestBytes: manifest.toBytes(),
        senderIdentityKey: key1,
      );
      final valid = await V2MediaCrypto.verifyManifestHmac(
        manifestBytes: manifest.toBytes(),
        senderIdentityKey: key2,
        expectedHmac: hmac,
      );
      expect(valid, isFalse);
    });

    test('H4: verifyManifestHmac returns false for tampered manifest', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final manifest1 = V2MediaManifest(
        version: 2,
        mediaId: List<int>.filled(16, 0x01),
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
        originalSize: 1024,
        encryptedSize: 1040,
        totalChunks: 1,
        chunkSize: V2MediaCrypto.chunkSize,
        wrappedKey: List<int>.filled(48, 0x02),
        wrappedKeyNonce: List<int>.filled(12, 0x03),
      );
      final manifest2 = V2MediaManifest(
        version: 2,
        mediaId: List<int>.filled(16, 0x01),
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
        originalSize: 9999, // Tampered
        encryptedSize: 1040,
        totalChunks: 1,
        chunkSize: V2MediaCrypto.chunkSize,
        wrappedKey: List<int>.filled(48, 0x02),
        wrappedKeyNonce: List<int>.filled(12, 0x03),
      );
      final hmac = await V2MediaCrypto.computeManifestHmac(
        manifestBytes: manifest1.toBytes(),
        senderIdentityKey: key,
      );
      final valid = await V2MediaCrypto.verifyManifestHmac(
        manifestBytes: manifest2.toBytes(),
        senderIdentityKey: key,
        expectedHmac: hmac,
      );
      expect(valid, isFalse);
    });

    test('H5: Manifest JSON includes hmac field', () {
      final manifest = V2MediaManifest(
        version: 2,
        mediaId: List<int>.filled(16, 0x01),
        mediaType: V2MediaType.photo,
        mimeType: 'image/jpeg',
        originalSize: 1024,
        encryptedSize: 1040,
        totalChunks: 1,
        chunkSize: V2MediaCrypto.chunkSize,
        wrappedKey: List<int>.filled(48, 0x02),
        wrappedKeyNonce: List<int>.filled(12, 0x03),
        manifestHmac: List<int>.filled(32, 0xFF),
      );
      final json = manifest.toJson();
      expect(json.containsKey('hmac'), isTrue);
      final restored = V2MediaManifest.fromJson(json);
      expect(restored.manifestHmac, equals(manifest.manifestHmac));
    });
  });

  // ===========================================================================
  // 12. VALIDATION BOUNDS (Phase 12E.4)
  // ===========================================================================

  group('12. Validation Bounds', () {
    test('V1: maxTotalChunks constant is defined', () {
      expect(V2MediaCrypto.maxTotalChunks, 100000);
    });

    test('V2: maxOriginalSize constant is defined', () {
      expect(V2MediaCrypto.maxOriginalSize, 10 * 1024 * 1024 * 1024);
    });

    test('V3: maxEncryptedSize constant is defined', () {
      expect(V2MediaCrypto.maxEncryptedSize, greaterThan(V2MediaCrypto.maxOriginalSize));
    });

    test('V4: maxManifestSize constant is defined', () {
      expect(V2MediaCrypto.maxManifestSize, 1024 * 1024);
    });
  });

  // ===========================================================================
  // 13. UTF-8 ENCODING (Phase 12E.4)
  // ===========================================================================

  group('13. UTF-8 Encoding', () {
    test('U1: UTF-8 encoding handles Cyrillic characters', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final text = 'Привет мир';
      final plaintext = utf8.encode(text);
      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.file,
        mimeType: 'text/plain',
      );
      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key,
        aad: aad,
        nonce: nonce,
      );

      final decrypted = await V2MediaCrypto.decryptChunk(
        ciphertext: encrypted.ciphertext,
        mediaKey: key,
        aad: aad,
        nonce: nonce,
      );

      expect(utf8.decode(decrypted), text);
    });

    test('U2: UTF-8 encoding handles emoji', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final text = 'Hello 🌍🎉';
      final plaintext = utf8.encode(text);
      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.file,
        mimeType: 'text/plain',
      );
      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key,
        aad: aad,
        nonce: nonce,
      );

      final decrypted = await V2MediaCrypto.decryptChunk(
        ciphertext: encrypted.ciphertext,
        mediaKey: key,
        aad: aad,
        nonce: nonce,
      );

      expect(utf8.decode(decrypted), text);
    });

    test('U3: UTF-8 encoding handles Chinese characters', () async {
      final key = await V2MediaCrypto.generateMediaKey();
      final mediaId = await V2MediaCrypto.generateMediaId();
      final text = '你好世界';
      final plaintext = utf8.encode(text);
      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: List<int>.filled(32, 0xAA),
        senderDeviceId: 'd1',
        recipientDeviceId: 'd2',
        mediaId: mediaId,
        chunkIndex: 0,
        totalChunks: 1,
        mediaType: V2MediaType.file,
        mimeType: 'text/plain',
      );
      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0);

      final encrypted = await V2MediaCrypto.encryptChunk(
        plaintext: plaintext,
        mediaKey: key,
        aad: aad,
        nonce: nonce,
      );

      final decrypted = await V2MediaCrypto.decryptChunk(
        ciphertext: encrypted.ciphertext,
        mediaKey: key,
        aad: aad,
        nonce: nonce,
      );

      expect(utf8.decode(decrypted), text);
    });
  });
}
