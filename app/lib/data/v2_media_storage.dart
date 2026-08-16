import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:vibe_app/data/v2_media_crypto.dart';

/// V2 encrypted media manifest.
///
/// Contains all metadata needed to decrypt and assemble media.
/// The manifest itself is NOT encrypted (needed for download routing),
/// but sensitive fields (filename, caption) ARE encrypted within it.
///
/// Manifest is authenticated via HMAC-SHA256 stored in message metadata.
class V2MediaManifest {
  /// Protocol version.
  final int version;

  /// Media ID (16 bytes, stored as hex).
  final List<int> mediaId;

  /// Media type (photo/voice/video/file).
  final int mediaType;

  /// MIME type (e.g., "image/jpeg").
  final String mimeType;

  /// Original file size before encryption.
  final int originalSize;

  /// Encrypted file size (sum of encrypted chunks).
  final int encryptedSize;

  /// Number of chunks.
  final int totalChunks;

  /// Chunk size in bytes.
  final int chunkSize;

  /// Wrapped (encrypted) media key.
  final List<int> wrappedKey;

  /// Nonce used for key wrapping.
  final List<int> wrappedKeyNonce;

  /// Encrypted filename (empty if not provided).
  final List<int> encryptedFilename;

  /// Nonce used for filename encryption.
  final List<int> filenameNonce;

  /// Encrypted caption (empty if not provided).
  final List<int> encryptedCaption;

  /// Nonce used for caption encryption.
  final List<int> captionNonce;

  /// Thumbnail media ID (16 bytes, stored as hex). Empty if no thumbnail.
  final List<int> thumbnailMediaId;

  /// Image width (for photos/videos, 0 if unknown).
  final int width;

  /// Image height (for photos/videos, 0 if unknown).
  final int height;

  /// Duration in seconds (for audio/video, 0 if unknown).
  final int duration;

  /// HMAC-SHA256 of manifest (signed by sender's identity key).
  /// Empty if not yet computed.
  final List<int> manifestHmac;

  const V2MediaManifest({
    required this.version,
    required this.mediaId,
    required this.mediaType,
    required this.mimeType,
    required this.originalSize,
    required this.encryptedSize,
    required this.totalChunks,
    required this.chunkSize,
    required this.wrappedKey,
    required this.wrappedKeyNonce,
    this.encryptedFilename = const [],
    this.filenameNonce = const [],
    this.encryptedCaption = const [],
    this.captionNonce = const [],
    this.thumbnailMediaId = const [],
    this.width = 0,
    this.height = 0,
    this.duration = 0,
    this.manifestHmac = const [],
  });

  /// Serializes manifest to JSON.
  Map<String, dynamic> toJson() => {
        'v': version,
        'id': V2MediaCrypto.mediaIdToHex(mediaId),
        'type': mediaType,
        'mime': mimeType,
        'size': originalSize,
        'encSize': encryptedSize,
        'chunks': totalChunks,
        'chunkSize': chunkSize,
        'wk': base64Encode(wrappedKey),
        'wkn': base64Encode(wrappedKeyNonce),
        if (encryptedFilename.isNotEmpty) 'fn': base64Encode(encryptedFilename),
        if (filenameNonce.isNotEmpty) 'fnn': base64Encode(filenameNonce),
        if (encryptedCaption.isNotEmpty) 'cap': base64Encode(encryptedCaption),
        if (captionNonce.isNotEmpty) 'capn': base64Encode(captionNonce),
        if (thumbnailMediaId.isNotEmpty)
          'thumb': V2MediaCrypto.mediaIdToHex(thumbnailMediaId),
        if (width > 0) 'w': width,
        if (height > 0) 'h': height,
        if (duration > 0) 'dur': duration,
        if (manifestHmac.isNotEmpty) 'hmac': base64Encode(manifestHmac),
      };

  /// Deserializes manifest from JSON.
  factory V2MediaManifest.fromJson(Map<String, dynamic> json) {
    return V2MediaManifest(
      version: json['v'] as int? ?? 2,
      mediaId: V2MediaCrypto.mediaIdFromHex(json['id'] as String),
      mediaType: json['type'] as int,
      mimeType: json['mime'] as String,
      originalSize: json['size'] as int,
      encryptedSize: json['encSize'] as int,
      totalChunks: json['chunks'] as int,
      chunkSize: json['chunkSize'] as int? ?? V2MediaCrypto.chunkSize,
      wrappedKey: base64Decode(json['wk'] as String),
      wrappedKeyNonce: base64Decode(json['wkn'] as String),
      encryptedFilename: json['fn'] != null
          ? base64Decode(json['fn'] as String)
          : const [],
      filenameNonce: json['fnn'] != null
          ? base64Decode(json['fnn'] as String)
          : const [],
      encryptedCaption: json['cap'] != null
          ? base64Decode(json['cap'] as String)
          : const [],
      captionNonce: json['capn'] != null
          ? base64Decode(json['capn'] as String)
          : const [],
      thumbnailMediaId: json['thumb'] != null
          ? V2MediaCrypto.mediaIdFromHex(json['thumb'] as String)
          : const [],
      width: json['w'] as int? ?? 0,
      height: json['h'] as int? ?? 0,
      duration: json['dur'] as int? ?? 0,
      manifestHmac: json['hmac'] != null
          ? base64Decode(json['hmac'] as String)
          : const [],
    );
  }

  /// Serializes manifest to bytes for hashing.
  List<int> toBytes() => utf8.encode(jsonEncode(toJson()));

  /// Computes HMAC-SHA256 of manifest for authentication.
  Future<List<int>> computeHash(List<int> authKey) async {
    final hmac = Hmac.sha256();
    final mac = await hmac.calculateMac(
      toBytes(),
      secretKey: SecretKey(authKey),
    );
    return mac.bytes;
  }

  /// Serializes manifest to JSON string for storage.
  String encode() => jsonEncode(toJson());

  /// Deserializes manifest from JSON string.
  factory V2MediaManifest.decode(String data) {
    return V2MediaManifest.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }
}

/// V2 encrypted media chunk.
///
/// Format: [chunkIndex:4][nonce:12][ciphertext][tag:16]
class V2MediaChunk {
  /// Chunk index (0-based).
  final int index;

  /// Nonce used for encryption.
  final List<int> nonce;

  /// Encrypted data (ciphertext || GCM tag).
  final List<int> ciphertext;

  const V2MediaChunk({
    required this.index,
    required this.nonce,
    required this.ciphertext,
  });

  /// Serializes chunk to bytes.
  List<int> toBytes() {
    final buffer = BytesBuilder();
    // Chunk index (4 bytes big-endian)
    buffer.add([
      (index >> 24) & 0xFF,
      (index >> 16) & 0xFF,
      (index >> 8) & 0xFF,
      index & 0xFF,
    ]);
    // Nonce (12 bytes)
    buffer.add(nonce);
    // Ciphertext + tag
    buffer.add(ciphertext);
    return buffer.toBytes();
  }

  /// Deserializes chunk from bytes.
  factory V2MediaChunk.fromBytes(List<int> bytes) {
    if (bytes.length < 4 + V2MediaCrypto.nonceSize + V2MediaCrypto.tagSize) {
      throw const V2MediaException('Chunk too short');
    }

    var offset = 0;

    // Chunk index
    final index = (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    offset += 4;

    // Nonce
    final nonce = bytes.sublist(offset, offset + V2MediaCrypto.nonceSize);
    offset += V2MediaCrypto.nonceSize;

    // Ciphertext + tag
    final ciphertext = bytes.sublist(offset);

    return V2MediaChunk(index: index, nonce: nonce, ciphertext: ciphertext);
  }

  /// Total serialized size.
  int get serializedSize =>
      4 + V2MediaCrypto.nonceSize + ciphertext.length;
}
