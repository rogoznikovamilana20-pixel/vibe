# Phase 12F — Independent Adversarial Audit: FINDINGS

**Date**: 2026-08-17
**Scope**: Full E2EE system (X3DH, Double Ratchet, identity lifecycle, media E2EE, plaintext leakage)
**Files Audited**: 25 production files, ~12,000 lines
**Previous Findings Re-verified**: F-003, F-004, F-037–F-046 (all FIXED in ae27cde)

---

## Summary

| Severity | New | Open (from prior) | Total |
|----------|-----|-------------------|-------|
| CRITICAL | 0   | 0                 | 0     |
| HIGH     | 2   | 0                 | 2     |
| MEDIUM   | 3   | 0                 | 3     |
| LOW      | 2   | 2 (F-003, F-004)  | 4     |
| INFO     | 2   | 0                 | 2     |

---

## HIGH Findings

### F-048: FCM Push Sends Plaintext Message Content to Supabase Edge Function

**Severity**: HIGH
**File**: `app/lib/data/backend.dart:3207, 3212–3232`
**Type**: Plaintext Leakage

**Description**:
`_sendFcmPush()` sends `row['text']` (the raw message text) as the `text` field in the Edge Function payload. For V1 messages, this is the actual message content. For V2 messages, `row['text']` is `null` (V2StoredMessage.buildInsertPayload sets `'text': null`), so V2 is NOT affected.

However, the call site at line 3207 uses `row['text']` from the **broadcast row**, which for V1 messages contains the plaintext. The plaintext traverses the Supabase Edge Function (`send-push`) in cleartext. A malicious server (or compromised Edge Function) can log this content.

**Attack Scenario**:
1. User sends V1 message "secret plan"
2. Backend calls `_sendFcmPush(..., "secret plan", ...)`
3. Edge Function receives plaintext in `body['text']`
4. Malicious server logs the plaintext before forwarding to FCM

**Recommendation**:
- For V2 messages: send only `null` or a placeholder (already done by V2 path).
- For V1 messages: encrypt the push payload end-to-end, or send only metadata (`sender_name`, `chat_id`, `message_id`) and let the client decrypt locally.
- The client already decrypts messages from the DB after receiving FCM — the push notification should never contain content.

**Status**: OPEN (V1 only — V2 is safe)

---

### F-049: Proxy Credentials Stored in Plaintext SharedPreferences

**Severity**: HIGH
**File**: `app/lib/data/settings_service.dart:599, 606, 613`
**Type**: Plaintext Credential Storage

**Description**:
Proxy username and password are stored in `SharedPreferences` (unencrypted JSON file on disk):
```dart
static const _keyProxyPassword = 'vibe_proxy_password';
String get proxyPassword => _prefs.getString(_keyProxyPassword) ?? '';
Future<void> setProxyPassword(String v) async => _prefs.setString(_keyProxyPassword, v);
```

On Android, `SharedPreferences` is stored as an XML file in app-private storage. On a rooted device or with backup extraction, the proxy password is readable in plaintext. If the proxy password is reused across services, this is a credential leak.

**Attack Scenario**:
1. User configures proxy with username/password
2. Password stored in `SharedPreferences` as plaintext XML
3. Attacker with device access (root, backup extraction, ADB) reads `shared_prefs/vibe_app.prefs.xml`
4. Attacker obtains proxy credentials

**Recommendation**:
- Move proxy credentials to `FlutterSecureStorage` (already used for E2E keys).
- Alternatively, if the proxy is local-only (SOCKS5 on localhost), document that credential is not sensitive.

**Status**: OPEN

---

## MEDIUM Findings

### F-050: E2E PIN Logged in Plaintext

**Severity**: MEDIUM
**File**: `app/lib/main.dart:49`
**Type**: Plaintext Secret Logging

**Description**:
```dart
debugPrint('[e2e] PIN установлен: $e2ePin');
```

The E2E PIN (environment variable `E2E_PIN`) is logged via `debugPrint` after being set. In release builds, `debugPrint` is typically stripped, but in profile/debug builds or if logging is forwarded to a crash reporter, the PIN is exposed.

**Recommendation**:
- Remove the PIN value from the log message. Log only `'[e2e] PIN установлен'`.
- Ensure `debugPrint` is tree-shaken in release builds (verify via `flutter build --release` inspection).

**Status**: OPEN

---

### F-051: V2 Message Envelope Missing chatId/recipientUserId/timestamp in AAD

**Severity**: MEDIUM
**File**: `app/lib/data/v2_ratchet.dart:826–843`
**Type**: Insufficient AAD Binding

**Description**:
The V2 message AAD is computed as:
```
AAD = senderIdentityKey(32) || senderDeviceId || recipientDeviceId || msgNum(4) || prevChainLen(4)
```

Missing fields:
- **chatId**: Not bound to AAD. A ciphertext from Chat A could theoretically be moved to Chat B by a malicious server (cross-chat message forgery).
- **recipientUserId**: Only `recipientDeviceId` is bound. If a user has multiple devices, a message intended for Device B could be replayed to Device C within the same session.
- **timestamp**: Not bound. A malicious server could delay or reorder messages without detection (within the ratchet's out-of-order tolerance).

**Cross-Chat Forgery Attack**:
1. Alice sends encrypted message to Bob in "Work Chat"
2. Malicious server copies the V2 envelope to "Personal Chat"
3. Bob decrypts successfully — message appears in wrong chat
4. Bob sees a message from Alice in "Personal Chat" that was actually from "Work Chat"

**Mitigating Factors**:
- The `recipientDeviceId` in AAD prevents replay to a different device.
- The session is per-device, not per-chat, so the same session could theoretically serve multiple chats.
- The attack requires a malicious server (threat model includes this).

**Recommendation**:
- Add `chatId` to the AAD in `encrypt()` / `_computeAad()`.
- Add `recipientUserId` to the AAD if multi-device support is planned.
- This is a protocol-level change requiring re-encryption of existing messages.

**Status**: OPEN (design limitation)

---

### F-052: Non-Constant-Time Key Comparison in `_listEquals()`

**Severity**: MEDIUM
**Files**: `app/lib/data/v2_ratchet.dart:846–852`, `app/lib/data/e2e_v2_identity_verification.dart:280–286`
**Type**: Timing Side-Channel

**Description**:
```dart
static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;  // Early return on first mismatch
    }
    return true;
  }
```

This comparison returns `false` on the first byte mismatch, which leaks the position of the first differing byte via timing. In the ratchet, this is used to compare `senderRatchetPublicKey` values (v2_ratchet.dart:592). In identity verification, it compares stored vs. received identity keys.

**Practical Impact**:
- The timing difference per byte is nanoseconds (Dart array access). Over a network, this is unmeasurable.
- The comparison is on public keys (not secrets) — the attacker already knows the public key.
- Local comparison (same process) — no network timing observable.

**Recommendation**:
- Use constant-time comparison for defense-in-depth. Dart's `crypto` package or a manual XOR-accumulation pattern (like `verifyManifestHmac` in v2_media_crypto.dart:541–546) would be appropriate.
- Mark as accepted risk if timing side-channel is not in threat model for local comparisons.

**Status**: OPEN (accepted risk for local comparison)

---

### F-053: V1 Plaintext Fallback on Generic Exception

**Severity**: MEDIUM
**File**: `app/lib/data/backend.dart:~1793–1804`
**Type**: Fail-Open Behavior

**Description**:
When V2 encryption fails, the code has explicit `catch (e)` blocks that throw or log. However, the V1 path (legacy) has a pattern where `catch (_)` silently falls through to the V1 encryption path. If V2 fails with an unexpected exception type, the message could be sent via V1 (less secure).

Looking at the V2 paths in backend.dart (lines 1758, 2074, 2208, 2308), the comments state:
```
// V2 encryption failed — fail-closed, no fallback to plaintext
```

This is correct — V2 failures do NOT fall through to V1. The V1 path is only reached if V2 is not enabled.

**Re-assessment**: After careful review, the V2 path correctly fails closed. The V1 path is only for non-V2 messages. **This finding is a FALSE POSITIVE** — the code correctly prevents V1 fallback for V2 messages.

**Status**: FALSE POSITIVE — Retained for documentation

---

## LOW Findings

### F-054: Missing Private Key Auto-Regenerates Silently

**Severity**: LOW
**File**: `app/lib/data/v2_ratchet_persistence.dart:42–50` (via v2_ratchet.dart:414–416)
**Type**: Silent Session Break

**Description**:
In `V2Ratchet.dhRatchetStep()` (v2_ratchet.dart:413–416):
```dart
var currentKeyPair = state.sendingRatchetKeyPair;
if (currentKeyPair == null) {
  currentKeyPair = await x25519.newKeyPair();
}
```

If the sending ratchet key pair is null (e.g., legacy state with only public key saved, or corruption), a new key pair is generated silently. The new public key goes in the message header, triggering an unwanted DH ratchet step on the receiver side. The sender never performs the DH step, causing chains to diverge.

**Mitigating Factors**:
- Phase 12C.4 fix ensures private key IS serialized (v2_ratchet_persistence.dart:1496–1497).
- Legacy states without private key are detected during deserialization (line 1556: "Legacy state: only public key saved").
- New key generation only happens if `receivingRatchetPublicKey` is available (line 482–484), preventing the divergence scenario.

**Status**: OPEN (known limitation for legacy states)

---

### F-055: FNV-1a Session ID Collision Could Overwrite Session Registry Entry

**Severity**: LOW
**File**: `app/lib/data/e2e_v2_service.dart:1113–1119`, `app/lib/data/v2_session_registry.dart:52`
**Type**: Reliability / Hash Collision

**Description**:
Session IDs are generated using FNV-1a (32-bit hash):
```dart
var hash = 0x811c9dc5;
for (final byte in combined) {
  hash ^= byte;
  hash = (hash * 0x01000193) & 0xFFFFFFFF;
}
return hash.toRadixString(16).padLeft(8, '0');
```

FNV-1a has 2^32 possible outputs. With the birthday paradox, a collision probability of 50% occurs at ~65,536 sessions. For a user with many contacts, this is plausible.

A collision would cause the session registry to overwrite a session entry, potentially routing messages to the wrong session.

**Mitigating Factors**:
- The input includes `ephemeralPubBytes` (32 bytes of randomness), making collisions practically impossible even with FNV-1a's limited output space.
- The session ID is used for routing only — the actual session is identified by the ratchet state stored under the session ID key.
- In practice, a collision would only cause a lookup miss, not a security bypass.

**Recommendation**:
- Use SHA-256 or UUID v4 for session IDs instead of FNV-1a.
- Mark as low priority since collision is extremely unlikely with random input.

**Status**: OPEN

---

### F-003 (pre-existing): FNV-1a Hash for Session ID (same as F-055)

**Status**: OPEN (same root cause)

---

### F-004 (pre-existing): chatId Not in Media AAD

**Severity**: LOW
**File**: `app/lib/data/v2_media_crypto.dart:270–316`
**Type**: Cross-Chat Media Forgery

**Description**:
Media chunk AAD includes `senderIdentityKey`, `senderDeviceId`, `recipientDeviceId`, `mediaId`, `chunkIndex`, `totalChunks`, `mediaType`, `mimeType` — but NOT `chatId`. A malicious server could move an encrypted media chunk from one chat to another.

**Mitigating Factors**:
- The `mediaId` is unique and random, bound to the media key via HKDF.
- Moving chunks without the manifest (which is HMAC-signed) would fail integrity checks.
- The media key is wrapped with the session root key, which is per-device.

**Status**: OPEN (design limitation, same as F-051)

---

## INFO Findings

### F-056: Manifest HMAC Uses Identity Key as HMAC Key

**Severity**: INFO
**File**: `app/lib/data/v2_media_crypto.dart:511–522`
**Type**: Design Observation

**Description**:
```dart
final key = SecretKey([
  ...senderIdentityKey,
  ...utf8.encode(_manifestHmacDomain),
]);
```

The manifest HMAC key is derived by concatenating the sender's **public** identity key with a domain label. This is acceptable because:
- HMAC security does not require key secrecy for authentication — it requires key integrity.
- The public identity key is known to both sender and receiver.
- The domain label prevents cross-protocol attacks.

This is a correct and standard pattern for HMAC with public keys.

**Status**: ACCEPTED

---

### F-057: Session Registry Entry Key Collision via peerId Containing ':'

**Severity**: INFO
**File**: `app/lib/data/v2_session_registry.dart:20–21`
**Type**: Input Validation

**Description**:
```dart
String _entryKey(String peerId, String recipientDeviceId) =>
    '$peerId:$recipientDeviceId';
```

If `peerId` contains the `:` character, the `findSessionsByPeer()` method (line 71: `entry.key.split(':')`) could misparse the key. UUIDs (used as peerId) never contain `:`, so this is safe in practice.

**Recommendation**:
- Validate that peerId and recipientDeviceId do not contain `:`.

**Status**: OPEN (theoretical)

---

## Re-verified Prior Findings

| ID | Description | Status |
|----|-------------|--------|
| F-003 | FNV-1a session ID | OPEN (same as F-055) |
| F-004 | chatId not in media AAD | OPEN (same as F-051) |
| F-037 | Trust state rotation | FIXED (ae27cde) |
| F-038 | Crash-safe rotation | FIXED (ae27cde) |
| F-039/F-040 | SPK 24h transition | FIXED (ae27cde) |
| F-041 | OTK mutex | FIXED (ae27cde) |
| F-043 | Atomic OTK consumption | FIXED (ae27cde) |
| F-045 | Session policy documented | FIXED (ae27cde) |
| F-046 | Session ID routing-only | FIXED (ae27cde) |
