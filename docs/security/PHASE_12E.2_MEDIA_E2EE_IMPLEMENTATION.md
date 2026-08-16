# PHASE 12E.2 — V2 Media E2EE Implementation

## Status: COMPLETE

## Summary

Implemented end-to-end encryption for all media types (photo, voice, video, file) using the V2 E2EE infrastructure. Media is encrypted client-side with AES-256-GCM before upload, and decrypted only on the recipient's device.

## Files Created

| File | Purpose | Lines |
|------|---------|-------|
| `lib/data/v2_media_crypto.dart` | Crypto primitives (key gen, AAD, encrypt/decrypt, key wrapping) | ~497 |
| `lib/data/v2_media_storage.dart` | Manifest/chunk serialization format | ~243 |
| `lib/data/v2_media_outgoing.dart` | Encrypt + upload pipeline | ~348 |
| `lib/data/v2_media_incoming.dart` | Download + decrypt pipeline | ~292 |
| `test/v2_media_e2ee_test.dart` | 43 security tests | ~890 |

## Files Modified

| File | Change |
|------|--------|
| `lib/data/backend.dart` | Added V2 media path to `sendPhoto`, `sendFile`, `sendVoice`, `sendVideo` |

## Crypto Design

### Key Hierarchy

```
Session Root Key (from X3DH/Double Ratchet)
  └─ HKDF-SHA256(sessionRootKey, mediaId, "VIBE-MEDIA-KEY-WRAP-V1")
       └─ Wrapping Key (32 bytes)
            └─ AES-256-GCM wrap → Wrapped Media Key

Random Media Key (32 bytes, unique per file)
  ├─ Chunk encryption (AES-256-GCM)
  ├─ HMAC-SHA256 → Thumbnail Key
  ├─ Filename encryption (AES-256-GCM)
  └─ Caption encryption (AES-256-GCM)
```

### Nonce Derivation

- **Chunk nonce**: `mediaId[0:12] XOR chunkIndex(4B BE)` — deterministic, unique per (key, chunk)
- **Thumbnail nonce**: `mediaId[0:12]` with last byte = `0xFF` — distinct from all chunk nonces
- **Key wrap nonce**: `mediaId[0:12]` — used once per media object
- **Filename/caption nonces**: `mediaId[0:12] XOR sentinel` — sentinel values `0x7FFFFFFE`/`0x7FFFFFFD`

### AAD Structure

```
AAD = "VIBE-MEDIA-E2EE-AAD-V1" (22 bytes)
    || senderIdentityKey (32 bytes)
    || senderDeviceId (length-prefixed UTF-8)
    || recipientDeviceId (length-prefixed UTF-8)
    || mediaId (16 bytes)
    || chunkIndex (4 bytes BE)
    || totalChunks (4 bytes BE)
    || mediaType (1 byte)
    || mimeType (length-prefixed UTF-8)
```

### Storage Format

```
media-v2/{mediaIdHex}/
  ├── manifest.json          (encrypted metadata, wrapped key)
  ├── chunk_0                (encrypted 64KB chunk)
  ├── chunk_1                (encrypted 64KB chunk)
  └── ...
```

### Manifest Schema

```json
{
  "v": 2,
  "id": "hex(mediaId)",
  "type": 0,
  "mime": "image/jpeg",
  "size": 1024000,
  "encSize": 1024032,
  "chunks": 16,
  "chunkSize": 65536,
  "wk": "base64(wrappedKey)",
  "wkn": "base64(wrappedKeyNonce)",
  "fn": "base64(encryptedFilename)",
  "fnn": "base64(filenameNonce)",
  "cap": "base64(encryptedCaption)",
  "capn": "base64(captionNonce)",
  "thumb": "hex(thumbnailMediaId)",
  "w": 1920,
  "h": 1080,
  "dur": 30
}
```

## Integration

### Backend Changes (sendPhoto/sendFile/sendVoice/sendVideo)

Each method now has a V2 path at the top:

```dart
if (V2Outgoing.instance.enabled) {
  final peerId = await _chatPeerId(chatId);
  if (peerId != null) {
    // Encrypt and upload via V2MediaOutgoing
    // Store manifest path in text column as JSON metadata
    // Fail-closed: no fallback to plaintext
  }
}
// Plaintext path (V1 or no E2E) — unchanged
```

### Message Format

V2 media messages store metadata in `text` column:

```json
{
  "v2_media": true,
  "manifest_path": "media-v2/{hex}/manifest.json",
  "chunks": 16,
  "kind": "photo",
  "name": "photo.jpg",
  "size": 1024000,
  "mime": "image/jpeg"
}
```

## Security Properties

| Property | Status |
|----------|--------|
| Per-file random 256-bit key | PASS |
| Key wrapped via session root key | PASS |
| Each chunk has unique nonce | PASS (verified 10K chunks) |
| AAD binds sender/recipient/media/chunk | PASS |
| Fail-closed on encryption failure | PASS |
| Opaque UUID storage paths | PASS |
| No plaintext fallback | PASS |
| Thumbnail encrypted with derived key | PASS |
| Filename/caption encrypted | PASS |
| Cross-media key isolation | PASS |

## Test Results

- **43/43 media E2EE tests PASS**
- **1383/1383 total tests PASS** (baseline 1340 + 43 new)
- **0 analyzer errors** on new files
- **0 analyzer warnings** on new files

## Test Coverage

| Category | Tests | Focus |
|----------|-------|-------|
| Key Generation | 6 | Randomness, size, hex encoding |
| Nonce Derivation | 5 | Uniqueness, 10K chunk validation |
| AAD Construction | 5 | Domain label, identity binding, tamper detection |
| Chunk Encryption | 8 | Round-trip, wrong key/AAD/nonce, tampering |
| Thumbnail | 3 | Round-trip, key derivation |
| Key Wrapping | 4 | Round-trip, wrong key/mediaId |
| Manifest | 3 | JSON round-trip, encode/decode |
| Adversarial | 5 | Cross-sender, index manipulation, MIME tampering |
| Serialization | 3 | Chunk round-trip, size validation |
| Media Types | 1 | Name mapping |
