import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibe_app/data/e2e_v2_service.dart';
import 'package:vibe_app/data/v2_media_crypto.dart';
import 'package:vibe_app/data/v2_media_storage.dart';
import 'package:vibe_app/data/v2_ratchet_persistence.dart';
import 'package:vibe_app/data/v2_session_registry.dart';

/// V2 media incoming handler — downloads and decrypts media.
///
/// ## Architecture
///
/// 1. Download manifest from storage
/// 2. Parse manifest to get wrapped media key, chunks, metadata
/// 3. Resolve session (sender identity → session ID)
/// 4. Unwrap media key using session root key
/// 5. Download and decrypt each chunk
/// 6. Reassemble plaintext
/// 7. Optionally decrypt thumbnail
/// 8. Return decrypted bytes + metadata
///
/// ## Security properties
///
/// - Media key unwrapped with HKDF-derived key from session root key
/// - Each chunk authenticated via AES-256-GCM (tamper detection)
/// - AAD validates sender, recipient, media, and chunk position
/// - Fail-closed: any decryption failure aborts entire media
/// - No plaintext written to disk (returned as memory buffer)
class V2MediaIncoming {
  V2MediaIncoming._();
  static final instance = V2MediaIncoming._();

  /// Decrypts media from storage.
  ///
  /// [manifestPath] — path to manifest.json in storage.
  /// [senderId] — sender user ID for session resolution.
  ///
  /// Returns [V2MediaDecryptResult] with decrypted bytes and metadata.
  ///
  /// Throws [V2MediaException] on:
  /// - Manifest not found
  /// - Session not found
  /// - Key unwrap failure
  /// - Chunk decryption failure
  static Future<V2MediaDecryptResult> downloadAndDecrypt({
    required String manifestPath,
    required String senderId,
  }) async {
    final e2e = E2eV2Service.instance;
    if (!e2e.isReady) {
      throw const V2MediaException('V2 E2E service not ready');
    }

    final client = Supabase.instance.client;

    // 1. Download manifest
    final manifestData =
        await client.storage.from('avatars').download(manifestPath);

    // 1a. Validate manifest size (F-027)
    if (manifestData.length > V2MediaCrypto.maxManifestSize) {
      throw const V2MediaException('Manifest too large');
    }

    final manifestJson = utf8.decode(manifestData);
    final manifest = V2MediaManifest.decode(manifestJson);

    // 1b. Validate manifest fields (F-026, F-030)
    if (manifest.totalChunks < 1 || manifest.totalChunks > V2MediaCrypto.maxTotalChunks) {
      throw V2MediaException(
          'Invalid chunk count: ${manifest.totalChunks}');
    }
    if (manifest.originalSize < 1 || manifest.originalSize > V2MediaCrypto.maxOriginalSize) {
      throw V2MediaException(
          'Invalid original size: ${manifest.originalSize}');
    }
    if (manifest.encryptedSize < 1 || manifest.encryptedSize > V2MediaCrypto.maxEncryptedSize) {
      throw V2MediaException(
          'Invalid encrypted size: ${manifest.encryptedSize}');
    }

    // 2. Resolve session
    final resolved = await _resolveSession(senderId: senderId);
    if (resolved == null) {
      throw const V2MediaException('No V2 session found for sender');
    }

    final sessionId = resolved.sessionId;

    // 3. Load ratchet state to get root key
    final ratchetState =
        await V2RatchetPersistence.instance.load(sessionId);
    if (ratchetState == null) {
      throw V2MediaException('Ratchet state not found: $sessionId');
    }

    // 4. Unwrap media key
    final mediaKey = await V2MediaCrypto.unwrapMediaKey(
      sessionRootKey: ratchetState.rootKey,
      wrappedKey: manifest.wrappedKey,
      nonce: manifest.wrappedKeyNonce,
      mediaId: manifest.mediaId,
    );

    // 5. Get identity keys and device IDs for AAD validation
    final identityKeyPublic = await e2e.getIdentityKeyPublicBytes();
    if (identityKeyPublic == null) {
      throw const V2MediaException('Identity key not available');
    }
    final recipientDeviceId = await e2e.getDeviceId();
    if (recipientDeviceId == null) {
      throw const V2MediaException('Device ID not available');
    }

    // We need the sender's device ID for AAD. It's stored in the X3DH session.
    final senderDeviceId = await _resolveSenderDeviceId(sessionId);
    if (senderDeviceId == null) {
      throw const V2MediaException('Sender device ID not found in session');
    }

    // 5a. Verify manifest HMAC (MANDATORY for V2 — F-025, F-033)
    // V2 media is new; there is no legacy unsigned V2 media.
    // An attacker who strips the HMAC field must be rejected.
    if (manifest.manifestHmac.isEmpty ||
        manifest.manifestHmac.length != V2MediaCrypto.hmacSize) {
      throw const V2MediaException(
          'V2 manifest HMAC missing or malformed — rejecting');
    }
    // Re-serialize manifest without HMAC for verification
    final manifestForVerification = V2MediaManifest(
      version: manifest.version,
      mediaId: manifest.mediaId,
      mediaType: manifest.mediaType,
      mimeType: manifest.mimeType,
      originalSize: manifest.originalSize,
      encryptedSize: manifest.encryptedSize,
      totalChunks: manifest.totalChunks,
      chunkSize: manifest.chunkSize,
      wrappedKey: manifest.wrappedKey,
      wrappedKeyNonce: manifest.wrappedKeyNonce,
      encryptedFilename: manifest.encryptedFilename,
      filenameNonce: manifest.filenameNonce,
      encryptedCaption: manifest.encryptedCaption,
      captionNonce: manifest.captionNonce,
      thumbnailMediaId: manifest.thumbnailMediaId,
      width: manifest.width,
      height: manifest.height,
      duration: manifest.duration,
    );
    final manifestBytes = manifestForVerification.toBytes();
    final valid = await V2MediaCrypto.verifyManifestHmac(
      manifestBytes: manifestBytes,
      senderIdentityKey: identityKeyPublic,
      expectedHmac: manifest.manifestHmac,
    );
    if (!valid) {
      throw const V2MediaException('Manifest HMAC verification failed');
    }

    // 6. Download and decrypt chunks
    final plaintextChunks = <List<int>>[];
    for (var i = 0; i < manifest.totalChunks; i++) {
      final chunkPath =
          '${manifestPath.replaceAll('/manifest.json', '')}/chunk_$i';
      final chunkData =
          await client.storage.from('avatars').download(chunkPath);

      final chunk = V2MediaChunk.fromBytes(chunkData);

      // Validate chunk index
      if (chunk.index != i) {
        throw V2MediaException(
            'Chunk index mismatch: expected $i, got ${chunk.index}');
      }

      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: identityKeyPublic,
        senderDeviceId: senderDeviceId,
        recipientDeviceId: recipientDeviceId,
        mediaId: manifest.mediaId,
        chunkIndex: i,
        totalChunks: manifest.totalChunks,
        mediaType: manifest.mediaType,
        mimeType: manifest.mimeType,
      );

      final plaintext = await V2MediaCrypto.decryptChunk(
        ciphertext: chunk.ciphertext,
        mediaKey: mediaKey,
        aad: aad,
        nonce: chunk.nonce,
      );

      plaintextChunks.add(plaintext);
    }

    // 7. Reassemble plaintext
    final totalSize = plaintextChunks.fold(0, (sum, c) => sum + c.length);
    final plaintext = Uint8List(totalSize);
    var offset = 0;
    for (final chunk in plaintextChunks) {
      plaintext.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    // 8. Decrypt thumbnail if present
    List<int>? thumbnailBytes;
    if (manifest.thumbnailMediaId.isNotEmpty) {
      final thumbPath =
          '${manifestPath.replaceAll('/manifest.json', '')}/../${V2MediaCrypto.mediaIdToHex(manifest.thumbnailMediaId)}/thumb';
      try {
        final thumbData =
            await client.storage.from('avatars').download(thumbPath);
        thumbnailBytes = await V2MediaCrypto.decryptThumbnail(
          ciphertext: thumbData,
          mediaKey: mediaKey,
          senderIdentityKey: identityKeyPublic,
          senderDeviceId: senderDeviceId,
          recipientDeviceId: recipientDeviceId,
          mediaId: manifest.mediaId,
          mediaType: manifest.mediaType,
          mimeType: manifest.mimeType,
        );
      } catch (_) {
        // Thumbnail is optional — don't fail if missing
      }
    }

    // 9. Decrypt filename if present
    String? filename;
    if (manifest.encryptedFilename.isNotEmpty) {
      final fnAad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: identityKeyPublic,
        senderDeviceId: senderDeviceId,
        recipientDeviceId: recipientDeviceId,
        mediaId: manifest.mediaId,
        chunkIndex: 0x7FFFFFFE,
        totalChunks: 0,
        mediaType: manifest.mediaType,
        mimeType: manifest.mimeType,
      );
      final fnBytes = await V2MediaCrypto.decryptChunk(
        ciphertext: manifest.encryptedFilename,
        mediaKey: mediaKey,
        aad: fnAad,
        nonce: manifest.filenameNonce,
      );
      filename = utf8.decode(fnBytes);
    }

    // 10. Decrypt caption if present
    String? caption;
    if (manifest.encryptedCaption.isNotEmpty) {
      final capAad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: identityKeyPublic,
        senderDeviceId: senderDeviceId,
        recipientDeviceId: recipientDeviceId,
        mediaId: manifest.mediaId,
        chunkIndex: 0x7FFFFFFD,
        totalChunks: 0,
        mediaType: manifest.mediaType,
        mimeType: manifest.mimeType,
      );
      final capBytes = await V2MediaCrypto.decryptChunk(
        ciphertext: manifest.encryptedCaption,
        mediaKey: mediaKey,
        aad: capAad,
        nonce: manifest.captionNonce,
      );
      caption = utf8.decode(capBytes);
    }

    return V2MediaDecryptResult(
      plaintext: plaintext,
      mediaType: manifest.mediaType,
      mimeType: manifest.mimeType,
      originalSize: manifest.originalSize,
      filename: filename,
      caption: caption,
      thumbnailBytes: thumbnailBytes,
      width: manifest.width,
      height: manifest.height,
      duration: manifest.duration,
    );
  }

  /// Resolves session ID for a sender.
  static Future<_ResolvedSession?> _resolveSession({
    required String senderId,
  }) async {
    final sessions =
        await V2SessionRegistry.instance.findSessionsByPeer(senderId);

    for (final sessionId in sessions) {
      final state = await V2RatchetPersistence.instance.load(sessionId);
      if (state != null) {
        final x3dhSession = await E2eV2Service.instance.loadSession(sessionId);
        final remoteDeviceId = x3dhSession?.remoteDeviceId;
        if (remoteDeviceId != null) {
          return _ResolvedSession(
            sessionId: sessionId,
            remoteDeviceId: remoteDeviceId,
          );
        }
      }
    }

    return null;
  }

  /// Resolves sender device ID from session.
  static Future<String?> _resolveSenderDeviceId(String sessionId) async {
    final x3dhSession = await E2eV2Service.instance.loadSession(sessionId);
    return x3dhSession?.remoteDeviceId;
  }
}

/// Result of V2 media decryption.
class V2MediaDecryptResult {
  final List<int> plaintext;
  final int mediaType;
  final String mimeType;
  final int originalSize;
  final String? filename;
  final String? caption;
  final List<int>? thumbnailBytes;
  final int width;
  final int height;
  final int duration;

  const V2MediaDecryptResult({
    required this.plaintext,
    required this.mediaType,
    required this.mimeType,
    required this.originalSize,
    this.filename,
    this.caption,
    this.thumbnailBytes,
    this.width = 0,
    this.height = 0,
    this.duration = 0,
  });
}

class _ResolvedSession {
  final String sessionId;
  final String remoteDeviceId;
  const _ResolvedSession({required this.sessionId, required this.remoteDeviceId});
}
