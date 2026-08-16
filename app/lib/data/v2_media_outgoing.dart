import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vibe_app/data/e2e_v2_service.dart';
import 'package:vibe_app/data/v2_media_crypto.dart';
import 'package:vibe_app/data/v2_media_storage.dart';
import 'package:vibe_app/data/v2_outgoing.dart';

/// V2 media outgoing handler — encrypts media and uploads to storage.
///
/// ## Architecture
///
/// 1. Generate random media key + media ID
/// 2. Split plaintext into 64KB chunks
/// 3. Encrypt each chunk with AES-256-GCM
/// 4. Optionally encrypt thumbnail
/// 5. Encrypt filename + caption (if provided)
/// 6. Build manifest with wrapped media key
/// 7. Upload chunks + manifest to storage (UUID-based paths)
/// 8. Return storage payload for DB insert
///
/// ## Security properties
///
/// - Media key is random 256-bit, unique per object
/// - Media key wrapped via HKDF-derived key from session root key
/// - Each chunk encrypted with unique nonce (mediaId || chunkIndex)
/// - AAD binds ciphertext to sender, recipient, media, chunk position
/// - No fallback to plaintext on encryption failure
/// - Storage paths are opaque UUID-based (no predictable names)
class V2MediaOutgoing {
  V2MediaOutgoing._();
  static final instance = V2MediaOutgoing._();

  /// Encrypts media and uploads to storage.
  ///
  /// [bytes] — plaintext file content.
  /// [chatId] — chat for upload path.
  /// [peerId] — peer user ID for session resolution.
  /// [mediaType] — type constant (V2MediaType.photo, etc).
  /// [mimeType] — MIME type string.
  /// [filename] — optional original filename (encrypted).
  /// [caption] — optional caption (encrypted).
  /// [thumbnailBytes] — optional thumbnail image (encrypted with derived key).
  /// [width] — optional image width.
  /// [height] — optional image height.
  ///
  /// Returns [V2MediaEncryptResult] with storage paths and manifest.
  ///
  /// Throws [V2MediaException] on:
  /// - Session not found
  /// - Encryption failure
  /// - Storage upload failure
  static Future<V2MediaEncryptResult> encryptAndUpload({
    required List<int> bytes,
    required String chatId,
    required String peerId,
    required int mediaType,
    required String mimeType,
    String? filename,
    String? caption,
    List<int>? thumbnailBytes,
    int width = 0,
    int height = 0,
    int duration = 0,
  }) async {
    final e2e = E2eV2Service.instance;
    if (!e2e.isReady) {
      throw const V2MediaException('V2 E2E service not ready');
    }

    // 1. Resolve recipient device ID
    final recipientDeviceId = await _resolveDeviceId(peerId);
    if (recipientDeviceId == null) {
      throw const V2MediaException('Recipient V2 device not found');
    }

    // 2. Bootstrap session
    final sessionId = await V2Outgoing.instance.bootstrapSession(
      peerId: peerId,
      recipientDeviceId: recipientDeviceId,
    );

    // 3. Load ratchet state to get root key for key wrapping
    final ratchetState = await V2Outgoing.instance.loadRatchetState(sessionId);
    if (ratchetState == null) {
      throw V2MediaException('Ratchet state not found: $sessionId');
    }

    // 4. Generate media key and media ID
    final mediaKey = await V2MediaCrypto.generateMediaKey();
    final mediaId = await V2MediaCrypto.generateMediaId();

    // 5. Get identity keys and device IDs
    final identityKeyPublic = await e2e.getIdentityKeyPublicBytes();
    if (identityKeyPublic == null) {
      throw const V2MediaException('Identity key not available');
    }
    final senderDeviceId = await e2e.getDeviceId();
    if (senderDeviceId == null) {
      throw const V2MediaException('Device ID not available');
    }

    // 6. Compute total chunks
    final totalChunks =
        (bytes.length / V2MediaCrypto.chunkSize).ceil().clamp(1, 10000);

    // 7. Encrypt chunks
    final encryptedChunks = <V2MediaChunk>[];
    for (var i = 0; i < totalChunks; i++) {
      final start = i * V2MediaCrypto.chunkSize;
      final end = (start + V2MediaCrypto.chunkSize).clamp(0, bytes.length);
      final chunkData = bytes.sublist(start, end);

      final aad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: identityKeyPublic,
        senderDeviceId: senderDeviceId,
        recipientDeviceId: recipientDeviceId,
        mediaId: mediaId,
        chunkIndex: i,
        totalChunks: totalChunks,
        mediaType: mediaType,
        mimeType: mimeType,
      );

      final nonce = V2MediaCrypto.deriveChunkNonce(mediaId, i);
      final result = await V2MediaCrypto.encryptChunk(
        plaintext: chunkData,
        mediaKey: mediaKey,
        aad: aad,
        nonce: nonce,
      );

      encryptedChunks.add(V2MediaChunk(
        index: i,
        nonce: nonce,
        ciphertext: result.ciphertext,
      ));
    }

    // 8. Encrypt thumbnail if provided
    List<int>? encryptedThumbnail;
    List<int>? thumbnailMediaIdBytes;
    if (thumbnailBytes != null && thumbnailBytes.isNotEmpty) {
      final thumbResult = await V2MediaCrypto.encryptThumbnail(
        thumbnailBytes: thumbnailBytes,
        mediaKey: mediaKey,
        senderIdentityKey: identityKeyPublic,
        senderDeviceId: senderDeviceId,
        recipientDeviceId: recipientDeviceId,
        mediaId: mediaId,
        mediaType: mediaType,
        mimeType: mimeType,
      );
      encryptedThumbnail = thumbResult.ciphertext;
      thumbnailMediaIdBytes = await V2MediaCrypto.generateMediaId();
    }

    // 9. Encrypt filename if provided
    List<int> encryptedFilename = const [];
    List<int> filenameNonce = const [];
    if (filename != null && filename.isNotEmpty) {
      final fnNonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0x7FFFFFFE);
      final fnAad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: identityKeyPublic,
        senderDeviceId: senderDeviceId,
        recipientDeviceId: recipientDeviceId,
        mediaId: mediaId,
        chunkIndex: 0x7FFFFFFE,
        totalChunks: 0,
        mediaType: mediaType,
        mimeType: mimeType,
      );
      final fnResult = await V2MediaCrypto.encryptChunk(
        plaintext: filename.codeUnits,
        mediaKey: mediaKey,
        aad: fnAad,
        nonce: fnNonce,
      );
      encryptedFilename = fnResult.ciphertext;
      filenameNonce = fnNonce;
    }

    // 10. Encrypt caption if provided
    List<int> encryptedCaption = const [];
    List<int> captionNonce = const [];
    if (caption != null && caption.isNotEmpty) {
      final capNonce = V2MediaCrypto.deriveChunkNonce(mediaId, 0x7FFFFFFD);
      final capAad = V2MediaCrypto.buildChunkAad(
        senderIdentityKey: identityKeyPublic,
        senderDeviceId: senderDeviceId,
        recipientDeviceId: recipientDeviceId,
        mediaId: mediaId,
        chunkIndex: 0x7FFFFFFD,
        totalChunks: 0,
        mediaType: mediaType,
        mimeType: mimeType,
      );
      final capResult = await V2MediaCrypto.encryptChunk(
        plaintext: caption.codeUnits,
        mediaKey: mediaKey,
        aad: capAad,
        nonce: capNonce,
      );
      encryptedCaption = capResult.ciphertext;
      captionNonce = capNonce;
    }

    // 11. Wrap media key
    final keyWrapResult = await V2MediaCrypto.wrapMediaKey(
      sessionRootKey: ratchetState.rootKey,
      mediaKey: mediaKey,
      mediaId: mediaId,
    );

    // 12. Compute encrypted size
    final encryptedSize = encryptedChunks.fold(
        0, (sum, c) => sum + 4 + V2MediaCrypto.nonceSize + c.ciphertext.length);

    // 13. Build manifest
    final manifest = V2MediaManifest(
      version: 2,
      mediaId: mediaId,
      mediaType: mediaType,
      mimeType: mimeType,
      originalSize: bytes.length,
      encryptedSize: encryptedSize,
      totalChunks: totalChunks,
      chunkSize: V2MediaCrypto.chunkSize,
      wrappedKey: keyWrapResult.wrappedKey,
      wrappedKeyNonce: keyWrapResult.nonce,
      encryptedFilename: encryptedFilename,
      filenameNonce: filenameNonce,
      encryptedCaption: encryptedCaption,
      captionNonce: captionNonce,
      thumbnailMediaId: thumbnailMediaIdBytes ?? const [],
      width: width,
      height: height,
      duration: duration,
    );

    // 14. Upload manifest + chunks to storage
    final mediaIdHex = V2MediaCrypto.mediaIdToHex(mediaId);
    final basePath = 'media-v2/$mediaIdHex';
    final manifestPath = '$basePath/manifest.json';

    // Upload manifest
    final manifestJson = manifest.encode();
    final client = Supabase.instance.client;
    await client.storage.from('avatars').uploadBinary(
          manifestPath,
          Uint8List.fromList(manifestJson.codeUnits),
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'application/json',
          ),
        );

    // Upload chunks
    final chunkPaths = <String>[];
    for (final chunk in encryptedChunks) {
      final chunkPath = '$basePath/chunk_${chunk.index}';
      await client.storage.from('avatars').uploadBinary(
            chunkPath,
            Uint8List.fromList(chunk.toBytes()),
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'application/octet-stream',
            ),
          );
      chunkPaths.add(chunkPath);
    }

    // Upload thumbnail if encrypted
    String? thumbnailPath;
    if (encryptedThumbnail != null && thumbnailMediaIdBytes != null) {
      final thumbIdHex = V2MediaCrypto.mediaIdToHex(thumbnailMediaIdBytes);
      thumbnailPath = 'media-v2/$thumbIdHex/thumb';
      await client.storage.from('avatars').uploadBinary(
            thumbnailPath,
            Uint8List.fromList(encryptedThumbnail),
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'application/octet-stream',
            ),
          );
    }

    return V2MediaEncryptResult(
      manifest: manifest,
      manifestPath: manifestPath,
      chunkPaths: chunkPaths,
      thumbnailPath: thumbnailPath,
      mediaId: mediaId,
    );
  }

  /// Resolves device ID for a peer user.
  static Future<String?> _resolveDeviceId(String peerId) async {
    try {
      final client = Supabase.instance.client;
      final devices = await client
          .from('devices')
          .select('id')
          .eq('user_id', peerId)
          .limit(1);
      if (devices.isNotEmpty) {
        return devices[0]['id'] as String;
      }
    } catch (_) {}
    return null;
  }
}

/// Result of V2 media encryption and upload.
class V2MediaEncryptResult {
  final V2MediaManifest manifest;
  final String manifestPath;
  final List<String> chunkPaths;
  final String? thumbnailPath;
  final List<int> mediaId;

  const V2MediaEncryptResult({
    required this.manifest,
    required this.manifestPath,
    required this.chunkPaths,
    this.thumbnailPath,
    required this.mediaId,
  });

  /// Builds the message insert payload for Supabase.
  Map<String, dynamic> toMessagePayload({
    required String chatId,
    required String senderId,
  }) {
    return {
      'chat_id': chatId,
      'sender_id': senderId,
      'is_encrypted': true,
      'e2ee_version': 2,
      'media_url': manifestPath,
      'media_type': V2MediaType.name(manifest.mediaType),
      'media_manifest': manifest.encode(),
    };
  }
}
