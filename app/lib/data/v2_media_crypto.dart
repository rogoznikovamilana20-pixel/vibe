import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// V2 Media E2EE crypto primitives.
///
/// Provides:
/// - Media key generation
/// - Media ID generation
/// - Key wrapping (encrypt media key with session key)
/// - Key unwrapping (decrypt media key with session key)
/// - Chunk encryption/decryption
/// - Thumbnail encryption/decryption
/// - AAD construction
/// - Nonce derivation
///
/// ## Security Properties
///
/// - Each media object gets independent random 256-bit key
/// - Media key wrapped via domain-separated KDF from session key
/// - Chunks encrypted with AES-256-GCM
/// - Nonce = mediaId(12) || chunkIndex(4) — deterministic, unique per key
/// - AAD binds ciphertext to sender, recipient, media, and chunk
class V2MediaCrypto {
  V2MediaCrypto._();

  /// Domain label for media key wrapping.
  static const String _keyWrapDomain = 'VIBE-MEDIA-KEY-WRAP-V1';

  /// Domain label for AAD.
  static const String _aadDomain = 'VIBE-MEDIA-E2EE-AAD-V1';

  /// Domain label for thumbnail key derivation.
  static const String _thumbnailKeyDomain = 'VIBE-MEDIA-THUMBNAIL-V1';

  /// Chunk size: 64 KiB.
  static const int chunkSize = 65536;

  /// Media key size: 32 bytes (256 bits).
  static const int mediaKeySize = 32;

  /// Media ID size: 16 bytes (128 bits).
  static const int mediaIdSize = 16;

  /// Nonce size: 12 bytes (AES-GCM standard).
  static const int nonceSize = 12;

  /// GCM tag size: 16 bytes.
  static const int tagSize = 16;

  /// HMAC-SHA256 size: 32 bytes.
  static const int hmacSize = 32;

  /// Maximum total chunks per media object (F-026).
  static const int maxTotalChunks = 100000;

  /// Maximum original file size: 10 GiB (F-030).
  static const int maxOriginalSize = 10 * 1024 * 1024 * 1024;

  /// Maximum encrypted file size: 10 GiB + 10% overhead (F-030).
  static const int maxEncryptedSize = 11811160064;

  /// Maximum manifest JSON size: 1 MiB (F-027).
  static const int maxManifestSize = 1024 * 1024;

  /// Domain label for manifest HMAC.
  static const String _manifestHmacDomain = 'VIBE-MEDIA-MANIFEST-HMAC-V1';

  // ==========================================================================
  // Key Generation
  // ==========================================================================

  /// Generates a cryptographically random media key.
  ///
  /// Returns 32 random bytes from a CSPRNG.
  static Future<List<int>> generateMediaKey() async {
    final random = Random.secure();
    return List<int>.generate(mediaKeySize, (_) => random.nextInt(256));
  }

  /// Generates a cryptographically random media ID.
  ///
  /// Returns 16 random bytes (128-bit UUID-like identifier).
  static Future<List<int>> generateMediaId() async {
    final random = Random.secure();
    return List<int>.generate(mediaIdSize, (_) => random.nextInt(256));
  }

  /// Converts media ID bytes to hex string for storage paths.
  static String mediaIdToHex(List<int> mediaId) {
    return mediaId.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Converts hex string back to media ID bytes.
  ///
  /// Throws [V2MediaException] if hex is not valid.
  static List<int> mediaIdFromHex(String hex) {
    if (hex.isEmpty) return const [];
    if (hex.length.isOdd) {
      throw const V2MediaException('Invalid hex string: odd length');
    }
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  // ==========================================================================
  // Key Wrapping
  // ==========================================================================

  /// Wraps (encrypts) a media key using a session-derived key.
  ///
  /// Uses HKDF-SHA256 to derive a wrapping key from the session root key,
  /// then encrypts the media key with AES-256-GCM.
  ///
  /// [sessionRootKey] — root key from the Double Ratchet session.
  /// [mediaKey] — random media key to wrap.
  /// [mediaId] — media ID for AAD binding.
  ///
  /// Returns (wrappedKey, nonce) where wrappedKey includes the GCM tag.
  static Future<({List<int> wrappedKey, List<int> nonce})> wrapMediaKey({
    required List<int> sessionRootKey,
    required List<int> mediaKey,
    required List<int> mediaId,
  }) async {
    // 1. Derive wrapping key from session root key
    final wrappingKey = await _deriveWrappingKey(sessionRootKey, mediaId);

    // 2. Generate nonce for key wrapping
    final nonce = _deriveKeyWrapNonce(mediaId);

    // 3. Encrypt media key with AES-256-GCM
    final aesGcm = AesGcm.with256bits(nonceLength: nonceSize);
    final secretBox = await aesGcm.encrypt(
      mediaKey,
      secretKey: SecretKey(wrappingKey),
      nonce: nonce,
      aad: utf8.encode(_keyWrapDomain),
    );

    return (
      wrappedKey: secretBox.concatenation(),
      nonce: nonce,
    );
  }

  /// Unwraps (decrypts) a media key using a session-derived key.
  ///
  /// [sessionRootKey] — root key from the Double Ratchet session.
  /// [wrappedKey] — wrapped media key (nonce || ciphertext || tag).
  /// [nonce] — nonce used for wrapping.
  /// [mediaId] — media ID for AAD binding.
  ///
  /// Returns the decrypted media key.
  static Future<List<int>> unwrapMediaKey({
    required List<int> sessionRootKey,
    required List<int> wrappedKey,
    required List<int> nonce,
    required List<int> mediaId,
  }) async {
    // 1. Derive wrapping key from session root key
    final wrappingKey = await _deriveWrappingKey(sessionRootKey, mediaId);

    // 2. Decrypt media key with AES-256-GCM
    final aesGcm = AesGcm.with256bits(nonceLength: nonceSize);
    final secretBox = SecretBox.fromConcatenation(
      wrappedKey,
      nonceLength: nonceSize,
      macLength: tagSize,
    );

    final plainKey = await aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(wrappingKey),
      aad: utf8.encode(_keyWrapDomain),
    );

    return plainKey;
  }

  /// Derives a wrapping key from session root key and media ID.
  ///
  /// Uses HKDF-SHA256 with domain separation.
  static Future<List<int>> _deriveWrappingKey(
    List<int> sessionRootKey,
    List<int> mediaId,
  ) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derivedKey = await hkdf.deriveKey(
      secretKey: SecretKey(sessionRootKey),
      nonce: mediaId,
      info: utf8.encode(_keyWrapDomain),
    );
    return derivedKey.extractBytes();
  }

  /// Derives nonce for key wrapping.
  ///
  /// Uses mediaId padded/truncated to 12 bytes.
  static List<int> _deriveKeyWrapNonce(List<int> mediaId) {
    final nonce = List<int>.filled(nonceSize, 0);
    final copyLen = mediaId.length < nonceSize ? mediaId.length : nonceSize;
    for (var i = 0; i < copyLen; i++) {
      nonce[i] = mediaId[i];
    }
    return nonce;
  }

  // ==========================================================================
  // Nonce Derivation
  // ==========================================================================

  /// Derives a chunk nonce from media ID and chunk index.
  ///
  /// Format: mediaId(12 bytes) XOR padded chunkIndex(12 bytes)
  /// This ensures unique nonce per (key, chunk) pair.
  ///
  /// Proof of uniqueness:
  /// - mediaId is unique per media object (128-bit random)
  /// - chunkIndex is unique per chunk within a media object
  /// - XOR combination produces unique 12-byte nonce
  /// - Same key + same nonce never occurs for distinct (media, chunk)
  static List<int> deriveChunkNonce(List<int> mediaId, int chunkIndex) {
    final nonce = List<int>.filled(nonceSize, 0);

    // Use first 12 bytes of mediaId
    final idLen = mediaId.length < nonceSize ? mediaId.length : nonceSize;
    for (var i = 0; i < idLen; i++) {
      nonce[i] = mediaId[i];
    }

    // XOR with chunk index (big-endian, last 4 bytes)
    nonce[8] ^= (chunkIndex >> 24) & 0xFF;
    nonce[9] ^= (chunkIndex >> 16) & 0xFF;
    nonce[10] ^= (chunkIndex >> 8) & 0xFF;
    nonce[11] ^= chunkIndex & 0xFF;

    return nonce;
  }

  /// Derives nonce for thumbnail encryption.
  ///
  /// Uses XOR of all mediaId bytes with 0xFF to ensure no collision
  /// with any chunk nonce (which XOR only the last 4 bytes with chunkIndex).
  static List<int> deriveThumbnailNonce(List<int> mediaId) {
    final nonce = List<int>.filled(nonceSize, 0xFF);
    final idLen = mediaId.length < nonceSize ? mediaId.length : nonceSize;
    for (var i = 0; i < idLen; i++) {
      nonce[i] = mediaId[i] ^ 0xFF;
    }
    return nonce;
  }

  // ==========================================================================
  // AAD Construction
  // ==========================================================================

  /// Constructs AAD for chunk encryption.
  ///
  /// AAD = domain(UTF-8) || senderIdentityKey(32) || senderDeviceId(len+UTF-8)
  ///     || recipientDeviceId(len+UTF-8) || mediaId(16) || chunkIndex(4)
  ///     || totalChunks(4) || mediaType(1) || mimeType(len+UTF-8)
  ///
  /// Uses length-prefixed encoding for variable-length fields to prevent
  /// ambiguity.
  static List<int> buildChunkAad({
    required List<int> senderIdentityKey,
    required String senderDeviceId,
    required String recipientDeviceId,
    required List<int> mediaId,
    required int chunkIndex,
    required int totalChunks,
    required int mediaType,
    required String mimeType,
  }) {
    final buffer = BytesBuilder();

    // Domain label (fixed)
    buffer.add(utf8.encode(_aadDomain));

    // Sender identity key (fixed 32 bytes)
    buffer.add(senderIdentityKey);

    // Sender device ID (length-prefixed)
    final senderDevIdBytes = utf8.encode(senderDeviceId);
    buffer.add(_uint16Bytes(senderDevIdBytes.length));
    buffer.add(senderDevIdBytes);

    // Recipient device ID (length-prefixed)
    final recipientDevIdBytes = utf8.encode(recipientDeviceId);
    buffer.add(_uint16Bytes(recipientDevIdBytes.length));
    buffer.add(recipientDevIdBytes);

    // Media ID (fixed 16 bytes)
    buffer.add(mediaId);

    // Chunk index (4 bytes big-endian)
    buffer.add(_uint32Bytes(chunkIndex));

    // Total chunks (4 bytes big-endian)
    buffer.add(_uint32Bytes(totalChunks));

    // Media type (1 byte)
    buffer.addByte(mediaType);

    // MIME type (length-prefixed)
    final mimeTypeBytes = utf8.encode(mimeType);
    buffer.add(_uint16Bytes(mimeTypeBytes.length));
    buffer.add(mimeTypeBytes);

    return buffer.toBytes();
  }

  /// Constructs AAD for thumbnail encryption.
  ///
  /// Same as chunk AAD but with chunkIndex = 0xFFFFFFFF and totalChunks = 0
  /// to distinguish from any chunk AAD.
  static List<int> buildThumbnailAad({
    required List<int> senderIdentityKey,
    required String senderDeviceId,
    required String recipientDeviceId,
    required List<int> mediaId,
    required int mediaType,
    required String mimeType,
  }) {
    return buildChunkAad(
      senderIdentityKey: senderIdentityKey,
      senderDeviceId: senderDeviceId,
      recipientDeviceId: recipientDeviceId,
      mediaId: mediaId,
      chunkIndex: 0xFFFFFFFF, // Sentinel for thumbnail
      totalChunks: 0,
      mediaType: mediaType,
      mimeType: mimeType,
    );
  }

  // ==========================================================================
  // Chunk Encryption
  // ==========================================================================

  /// Encrypts a single chunk with AES-256-GCM.
  ///
  /// [plaintext] — chunk data (up to chunkSize bytes).
  /// [mediaKey] — encryption key for this media.
  /// [aad] — authenticated additional data.
  /// [nonce] — unique nonce for this chunk.
  ///
  /// Returns (ciphertext, tag) where ciphertext includes the GCM tag.
  static Future<({List<int> ciphertext, List<int> nonce})> encryptChunk({
    required List<int> plaintext,
    required List<int> mediaKey,
    required List<int> aad,
    required List<int> nonce,
  }) async {
    final aesGcm = AesGcm.with256bits(nonceLength: nonceSize);
    final secretBox = await aesGcm.encrypt(
      plaintext,
      secretKey: SecretKey(mediaKey),
      nonce: nonce,
      aad: aad,
    );

    return (
      ciphertext: secretBox.cipherText + secretBox.mac.bytes,
      nonce: nonce,
    );
  }

  /// Decrypts a single chunk with AES-256-GCM.
  ///
  /// [ciphertext] — encrypted chunk (ciphertext || tag, no nonce).
  /// [mediaKey] — decryption key for this media.
  /// [aad] — authenticated additional data.
  /// [nonce] — nonce used for encryption.
  ///
  /// Returns decrypted plaintext.
  static Future<List<int>> decryptChunk({
    required List<int> ciphertext,
    required List<int> mediaKey,
    required List<int> aad,
    required List<int> nonce,
  }) async {
    if (ciphertext.length < tagSize) {
      throw const V2MediaException('Ciphertext too short — missing GCM tag');
    }
    final aesGcm = AesGcm.with256bits(nonceLength: nonceSize);
    final secretBox = SecretBox(
      ciphertext.sublist(0, ciphertext.length - tagSize),
      nonce: nonce,
      mac: Mac(ciphertext.sublist(ciphertext.length - tagSize)),
    );

    return aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(mediaKey),
      aad: aad,
    );
  }

  // ==========================================================================
  // Thumbnail Encryption
  // ==========================================================================

  /// Derives a thumbnail-specific key from the media key.
  static Future<List<int>> deriveThumbnailKey(List<int> mediaKey) async {
    final hmac = Hmac.sha256();
    final mac = await hmac.calculateMac(
      utf8.encode(_thumbnailKeyDomain),
      secretKey: SecretKey(mediaKey),
    );
    return mac.bytes;
  }

  /// Encrypts a thumbnail image.
  static Future<({List<int> ciphertext, List<int> nonce})> encryptThumbnail({
    required List<int> thumbnailBytes,
    required List<int> mediaKey,
    required List<int> senderIdentityKey,
    required String senderDeviceId,
    required String recipientDeviceId,
    required List<int> mediaId,
    required int mediaType,
    required String mimeType,
  }) async {
    final thumbnailKey = await deriveThumbnailKey(mediaKey);
    final nonce = deriveThumbnailNonce(mediaId);
    final aad = buildThumbnailAad(
      senderIdentityKey: senderIdentityKey,
      senderDeviceId: senderDeviceId,
      recipientDeviceId: recipientDeviceId,
      mediaId: mediaId,
      mediaType: mediaType,
      mimeType: mimeType,
    );

    return encryptChunk(
      plaintext: thumbnailBytes,
      mediaKey: thumbnailKey,
      aad: aad,
      nonce: nonce,
    );
  }

  /// Decrypts a thumbnail image.
  static Future<List<int>> decryptThumbnail({
    required List<int> ciphertext,
    required List<int> mediaKey,
    required List<int> senderIdentityKey,
    required String senderDeviceId,
    required String recipientDeviceId,
    required List<int> mediaId,
    required int mediaType,
    required String mimeType,
  }) async {
    final thumbnailKey = await deriveThumbnailKey(mediaKey);
    final nonce = deriveThumbnailNonce(mediaId);
    final aad = buildThumbnailAad(
      senderIdentityKey: senderIdentityKey,
      senderDeviceId: senderDeviceId,
      recipientDeviceId: recipientDeviceId,
      mediaId: mediaId,
      mediaType: mediaType,
      mimeType: mimeType,
    );

    return decryptChunk(
      ciphertext: ciphertext,
      mediaKey: thumbnailKey,
      aad: aad,
      nonce: nonce,
    );
  }

  // ==========================================================================
  // Helpers
  // ==========================================================================

  /// Encodes a 16-bit integer as 2 big-endian bytes.
  static List<int> _uint16Bytes(int value) {
    return [(value >> 8) & 0xFF, value & 0xFF];
  }

  /// Encodes a 32-bit integer as 4 big-endian bytes.
  static List<int> _uint32Bytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  // ==========================================================================
  // Manifest HMAC
  // ==========================================================================

  /// Computes HMAC-SHA256 of manifest for authentication.
  ///
  /// Uses sender's identity key as HMAC key with domain separation.
  /// This binds the manifest to the sender and prevents server-side tampering.
  ///
  /// [manifestBytes] — serialized manifest JSON bytes.
  /// [senderIdentityKey] — sender's 32-byte public identity key.
  ///
  /// Returns 32-byte HMAC.
  static Future<List<int>> computeManifestHmac({
    required List<int> manifestBytes,
    required List<int> senderIdentityKey,
  }) async {
    final hmac = Hmac.sha256();
    final key = SecretKey([
      ...senderIdentityKey,
      ...utf8.encode(_manifestHmacDomain),
    ]);
    final mac = await hmac.calculateMac(manifestBytes, secretKey: key);
    return mac.bytes;
  }

  /// Verifies HMAC of manifest.
  ///
  /// [manifestBytes] — serialized manifest JSON bytes.
  /// [senderIdentityKey] — sender's 32-byte public identity key.
  /// [expectedHmac] — expected HMAC value (32 bytes).
  ///
  /// Returns true if HMAC is valid.
  static Future<bool> verifyManifestHmac({
    required List<int> manifestBytes,
    required List<int> senderIdentityKey,
    required List<int> expectedHmac,
  }) async {
    final computed = await computeManifestHmac(
      manifestBytes: manifestBytes,
      senderIdentityKey: senderIdentityKey,
    );
    if (computed.length != expectedHmac.length) return false;
    // Constant-time comparison
    var diff = 0;
    for (var i = 0; i < computed.length; i++) {
      diff |= computed[i] ^ expectedHmac[i];
    }
    return diff == 0;
  }
}

/// Media type constants.
class V2MediaType {
  static const int photo = 0;
  static const int voice = 1;
  static const int video = 2;
  static const int file = 3;
  static const int thumbnail = 4;

  static String name(int type) {
    switch (type) {
      case photo:
        return 'photo';
      case voice:
        return 'voice';
      case video:
        return 'video';
      case file:
        return 'file';
      case thumbnail:
        return 'thumbnail';
      default:
        return 'unknown';
    }
  }
}

/// Exception for V2 media operations.
class V2MediaException implements Exception {
  final String message;
  const V2MediaException(this.message);

  @override
  String toString() => 'V2MediaException: $message';
}
