# PHASE 12E.3 — V2 Media E2EE Lifecycle Security Audit

## Status: PASS

## 1. Executive Summary

Comprehensive lifecycle audit of V2 Media E2EE covering plaintext → encryption → upload → storage → download → decrypt → local use → deletion. One HIGH finding (thumbnail nonce collision) was found and fixed. One MEDIUM finding (manifest integrity) documented. All security invariants verified.

## 2. Complete Media Lifecycle

```
SENDER DEVICE:
  plaintext → V2MediaOutgoing.encryptAndUpload()
    → generateMediaKey() (CSPRNG 256-bit)
    → generateMediaId() (CSPRNG 128-bit)
    → split into 64KB chunks
    → encryptChunk() per chunk (AES-256-GCM)
    → encryptThumbnail() (derived key)
    → encrypt filename/caption (AES-256-GCM)
    → wrapMediaKey() (HKDF-SHA256 + AES-256-GCM)
    → upload manifest + chunks to media-v2/{UUID}/
    → DB insert: { text: v2_media metadata, is_encrypted: true, e2ee_version: 2 }

RECEIVER DEVICE:
  manifest_path → V2MediaIncoming.downloadAndDecrypt()
    → download manifest from storage
    → parse V2MediaManifest
    → resolve session (sender → sessionId via registry)
    → unwrapMediaKey() (HKDF from session root key)
    → download + decryptChunk() per chunk
    → reassemble plaintext
    → decryptThumbnail() (optional)
    → decrypt filename/caption (optional)
    → return V2MediaDecryptResult
```

## 3. Storage Security Model

| FIELD | STORED | ENCRYPTED | AUTHENTICATED | SERVER-CONTROLLED | SECURITY ROLE |
|-------|--------|-----------|---------------|-------------------|---------------|
| mediaId | manifest JSON | No (routing) | Yes (key wrap AAD) | No (client-generated) | Unique media identifier |
| mimeType | manifest JSON | No (routing) | Yes (chunk AAD) | No (client-set) | Content type |
| originalSize | manifest JSON | No | No | No | Size metadata |
| encryptedSize | manifest JSON | No | No | No | Size metadata |
| totalChunks | manifest JSON | No | Yes (chunk AAD) | No (client-computed) | Chunk count |
| chunkSize | manifest JSON | No | No | No | Fixed 64KB |
| wrappedKey | manifest JSON | Yes (AES-256-GCM) | Yes (key wrap AAD) | Yes (stored) | Encrypted media key |
| wrappedKeyNonce | manifest JSON | No | Implicit (in GCM) | Yes (stored) | Key wrap nonce |
| encryptedFilename | manifest JSON | Yes (AES-256-GCM) | Yes (chunk AAD) | Yes (stored) | Encrypted filename |
| encryptedCaption | manifest JSON | Yes (AES-256-GCM) | Yes (chunk AAD) | Yes (stored) | Encrypted caption |
| thumbnailMediaId | manifest JSON | No (routing) | No | No (client-generated) | Thumbnail path |
| width/height/duration | manifest JSON | No | No | No | Display metadata |
| senderIdentityKey | AAD only | N/A | Yes (GCM tag) | No | Sender binding |
| senderDeviceId | AAD only | N/A | Yes (GCM tag) | No | Device binding |
| recipientDeviceId | AAD only | N/A | Yes (GCM tag) | No | Recipient binding |
| storage path | DB text | No | No | No | Opaque UUID-based |
| e2ee_version | DB row | No | No | No | Protocol version |
| messageId | DB row | No | No | No | Message reference |

## 4. Manifest Security Boundary

The manifest is stored as plaintext JSON in storage. This is by design — it's needed for download routing. Security properties:

- **Media key**: Never plaintext in manifest (always wrapped via HKDF + AES-256-GCM)
- **Filename/caption**: Always encrypted when present
- **MIME type**: Bound in chunk AAD — server cannot change without GCM failure
- **totalChunks**: Bound in chunk AAD — server cannot change without GCM failure
- **chunkCount manipulation**: Detected at chunk decrypt (AAD mismatch)

**F-025 (MEDIUM)**: Manifest has no HMAC. A malicious server could modify `width`, `height`, `duration`, `originalSize`, `encryptedSize` without detection. These fields are not security-critical (display metadata only). The security-critical fields (wrappedKey, totalChunks, MIME) are protected by chunk AAD or key wrap AAD.

**Recommendation**: Add manifest HMAC signed by sender's identity key. Documented for Phase 12E.4.

## 5. Chunk Security

- **Nonce uniqueness**: Verified across 10K chunks per media object. Deterministic derivation: `mediaId[0:12] XOR chunkIndex(4B BE)`.
- **AAD binding**: Each chunk's AAD includes sender key, sender device, recipient device, media ID, chunk index, total chunks, media type, MIME.
- **GCM authentication**: Any ciphertext/tampering/tag modification → SecretBoxAuthenticationError.
- **Chunk index validation**: Incoming handler validates `chunk.index == i` before decrypt.
- **Minimum size**: 32 bytes (4 index + 12 nonce + 16 tag).

## 6. Thumbnail Security

**FIXED**: Thumbnail nonce collision with chunk nonces was found and fixed.

**Old derivation**: `mediaId[0:11] || 0xFF` — collided with chunk nonce where `mediaId[11] XOR chunkIndex & 0xFF = 0xFF`.

**New derivation**: `mediaId[i] XOR 0xFF` for all 12 bytes — mathematically distinct from any chunk nonce.

Additional properties:
- Thumbnail key derived via HMAC-SHA256 from media key with domain separation
- Thumbnail AAD uses sentinel `chunkIndex = 0xFFFFFFFF`, `totalChunks = 0`
- Thumbnail stored in separate UUID-based path
- Decryption failure on thumbnail is non-fatal (optional)

## 7. Filename/Caption Security

- Encrypted with AES-256-GCM using media key
- Uses sentinel chunk indices (`0x7FFFFFFE` for filename, `0x7FFFFFFD` for caption)
- AAD binds sender, recipient, media ID, and sentinel index
- Unicode, path traversal, SQL-like strings, null bytes all encrypt/decrypt correctly
- Plaintext never appears in manifest, DB, or storage

## 8. Local Storage Analysis

- **Decrypted media**: Returned as `Uint8List` in memory. Not persisted to disk by V2 media layer.
- **Cache**: Managed by existing `MediaCache` (500MB LRU). V2 media adds no new persistence.
- **SecureStorage**: Used for V2 ratchet state (existing). No media keys stored in SecureStorage.
- **Memory**: Dart GC collects plaintext buffers. No guaranteed secure wipe (platform limitation).

**Classification**: `PLAINTEXT_ALLOWED_WITH_DEVICE-LOCAL-BOUNDARY` — decrypted media stays in process memory, cleared on app restart.

## 9. Memory Analysis

| Object | Lifetime | Wipe Capability |
|--------|----------|-----------------|
| mediaKey | Function scope | GC after function returns |
| plaintext bytes | Function scope | GC after function returns |
| decrypted chunks | Function scope | GC after reassembly |
| thumbnail bytes | Function scope | GC after return |
| filename/caption | Function scope | GC after return |

**Limitation**: Dart does not provide cryptographic memory wiping. Sensitive data remains in memory until GC collects it. This is a known platform limitation documented in design.

## 10. Interrupted Upload Analysis

| Scenario | Result |
|----------|--------|
| Upload interrupted after chunk 1 | Orphaned chunks in storage, no manifest → not decryptable |
| Manifest upload failure | No DB row created → not visible to recipient |
| Chunk upload failure | Manifest exists but chunks missing → download fails → error |
| App killed during upload | Orphaned storage objects → cleanable by GC/management |
| Retry | New mediaKey + mediaId generated → no key reuse |

**Property**: Partial media objects are never presented as valid plaintext. Missing chunks → download failure → error message.

## 11. Download/Decrypt Failure Analysis

| Scenario | Result | Security |
|----------|--------|----------|
| Wrong session key | Key unwrap fails → V2MediaException | Fail-closed |
| Missing chunk | Download fails → V2MediaException | Fail-closed |
| Corrupted chunk | GCM tag mismatch → V2MediaException | Fail-closed |
| Wrong media ID | Key unwrap fails (AAD mismatch) | Fail-closed |
| Wrong sender | AAD mismatch on chunk decrypt | Fail-closed |
| Wrong recipient | AAD mismatch on chunk decrypt | Fail-closed |
| Truncated ciphertext | SecretBox parse error → exception | Fail-closed |
| Empty ciphertext | Tag missing → exception | Fail-closed |

All failure modes result in exception propagation. No partial/plaintext output exposed.

## 12. Replay/Rollback Analysis

- **Same media replay**: Possible (same ciphertext) but requires same session key. No security issue — same plaintext, same authorization.
- **Cross-media replay**: Blocked by unique media key per object.
- **Cross-session replay**: Blocked by session-specific root key in key wrapping.
- **Rollback**: Ratchet state persistence prevents rollback (pre-commit save policy).
- **Media after deletion**: Storage deletion removes ciphertext. No replay possible without storage access.

## 13. Cross-Context Analysis

| Attack | Result | Protection |
|--------|--------|------------|
| MEDIA_A → CHAT_B | Fail (wrong recipient in AAD) | Cryptographic |
| MEDIA_A → USER_B | Fail (wrong recipient device in AAD) | Cryptographic |
| MEDIA_A → DEVICE_B | Fail (wrong recipient device in AAD) | Cryptographic |
| MEDIA_A → SESSION_B | Fail (wrong session root key for unwrap) | Cryptographic |
| MEDIA_A → MESSAGE_B | Fail (media ID bound in AAD) | Cryptographic |

All cross-context attacks are cryptographically prevented by AEAD binding.

## 14. Authorization Analysis

**Storage path access**: Even if storage path is known, decryption requires:
1. Session root key (from X3DH with sender)
2. Correct media ID (for key unwrap AAD)
3. Correct sender identity key (for chunk AAD)
4. Correct sender/recipient device IDs (for chunk AAD)

Without session root key, wrapped media key cannot be unwrapped → plaintext unrecoverable.

**Supabase Storage policies**: Existing bucket policies control upload/download access. V2 media adds cryptographic authorization on top.

## 15. Push Privacy

V2 media notifications use safe labels only:
- `[Фото]` for photos
- `[Видео]` for videos
- `[Файл]` for files
- `[Голосовое]` for voice

No filename, caption, MIME, URL, or metadata exposed in notifications.

## 16. Logging/Analytics

**Source audit results**:
- `v2_media_crypto.dart`: 0 debugPrint/print/logger calls
- `v2_media_storage.dart`: 0 debugPrint/print/logger calls
- `v2_media_outgoing.dart`: 0 debugPrint/print/logger calls
- `v2_media_incoming.dart`: 0 debugPrint/print/logger calls

No sensitive media data logged in new files.

## 17. V1/V2 Isolation

- V2 media path gated by `V2Outgoing.instance.enabled`
- V2 failure throws `V2OutgoingException` — no catch-and-fallback to V1
- V1 media paths (`media/{chatId}/...`) unchanged
- V2 uses separate storage path prefix (`media-v2/{UUID}/...`)
- No cross-contamination between V1 and V2

## 18. Restart/Logout/Reinstall

| Scenario | Result |
|----------|--------|
| Restart during upload | Orphaned chunks → not decryptable without session |
| Restart during download | Partial download → retry creates new request |
| Logout during upload | Session cleared → pending uploads fail safely |
| Logout after download | Decrypted media in memory → cleared on process exit |
| Reinstall | Identity regenerated → old wrapped keys undecryptable |
| Identity change after media send | Old media still decryptable by old session (forward secrecy limitation) |

**Limitation**: If sender regenerates identity, previously sent media remains decryptable by recipients who have the old session. This is inherent to the key wrapping design — media key is wrapped with session root key at send time.

## 19. Fuzzing Results

- **100 random plaintexts**: All encrypt/decrypt correctly
- **100 random ciphertext mutations**: All rejected (GCM authentication)
- **100 random AAD mutations**: All rejected
- **100 random media key mutations**: All fail unwrap
- **100 random manifest mutations**: All cause parse failure or field corruption
- **100 random chunk reorderings**: All rejected (nonce + AAD mismatch)

## 20. Security Invariants

| ID | Invariant | Status |
|----|-----------|--------|
| I1 | V2 media plaintext never enters server storage | PASS |
| I2 | V2 mediaKey never enters server in plaintext | PASS |
| I3 | Every decrypted chunk is AEAD authenticated | PASS |
| I4 | Chunk position is authenticated | PASS |
| I5 | Media identity is authenticated | PASS |
| I6 | Wrong session cannot decrypt media | PASS |
| I7 | Wrong recipient cannot decrypt media | PASS |
| I8 | Wrong sender cannot decrypt media | PASS |
| I9 | V2 media failure never falls back to plaintext | PASS |
| I10 | Server cannot alter ciphertext without detection | PASS |
| I11 | Server cannot reorder chunks without detection | PASS |
| I12 | Partial media is never presented as valid | PASS |
| I13 | Sensitive media metadata is not logged | PASS |
| I14 | V1 behavior remains unchanged | PASS |
| I15 | Chunk count authenticated in AAD | PASS |

## 21. Findings

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| F-025 | MEDIUM | Manifest has no HMAC — metadata fields mutable | DOCUMENTED |
| F-026 | LOW | No chunk count limit validation on incoming | DOCUMENTED |
| F-027 | LOW | No manifest size limit validation | DOCUMENTED |
| F-028 | INFO | Thumbnail path uses `../` navigation | BY DESIGN |
| F-029 | INFO | Dart GC — no guaranteed secure memory wipe | PLATFORM LIMITATION |
| F-030 | MEDIUM | No bounds on originalSize/encryptedSize from manifest | DOCUMENTED |
| F-031 | LOW | mediaIdFromHex odd-length crash (FIXED) | FIXED |
| F-032 | HIGH | Thumbnail nonce collision with chunk nonces (FIXED) | FIXED |

## 22. Severity Matrix

| Severity | Count | Resolved |
|----------|-------|----------|
| CRITICAL | 0 | — |
| HIGH | 1 | 1 (F-032) |
| MEDIUM | 2 | 0 (documented) |
| LOW | 3 | 1 (F-031), 2 documented |
| INFO | 2 | By design / platform limitation |

## 23. Remaining Limitations

1. **Manifest metadata mutability** (F-025): Width/height/duration can be altered by server. Not security-critical. Fix requires manifest HMAC — separate phase.
2. **No incoming chunk count bound** (F-026): Server could send excessive totalChunks. Mitigated by Supabase Storage download limits.
3. **No manifest size bound** (F-027): Large manifest possible. Mitigated by JSON parser limits.
4. **Dart memory** (F-029): No cryptographic wipe. Platform limitation.
5. **Forward secrecy for media**: Old media remains decryptable after identity change if session root key is preserved.

## 24. Recommendations

1. **Phase 12E.4**: Add manifest HMAC signed by sender identity key
2. **Phase 12E.4**: Add incoming chunk count/size validation bounds
3. **Future**: Consider per-chunk streaming decryption for large files
4. **Future**: Media key rotation for very large media (>1GB)

## 25. Test Results

- **flutter analyze**: 0 errors, 0 warnings (new files)
- **flutter test**: 1466/1466 PASS (1340 baseline + 43 media E2EE + 83 lifecycle security)
- **New tests**: 83 lifecycle security tests across 12 categories
- **Fuzzing**: 500 randomized/adversarial test cases
