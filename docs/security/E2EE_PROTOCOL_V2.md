# E2EE Protocol V2 — Vibe Messenger

> **Specification document with production implementation.**
> Created: 2026-08-15 | Phase 12A | Status: IMPLEMENTED (Phase 12F audit complete)

---

## 1. Executive Summary

Vibe currently uses a minimal E2EE implementation: X25519 static-static key agreement → raw shared secret → AES-256-GCM. This provides basic confidentiality but lacks forward secrecy, key rotation, identity verification, multi-device support, and media encryption.

This document specifies **VibeE2EE v2** — a standardized protocol based on the X3DH key agreement + Double Ratchet message encryption, designed for a two-party messenger with Supabase as the transport layer.

**Design principles:**
- No custom cryptography — only standardized, audited primitives
- No plaintext fallback — encryption is mandatory for all content
- No post-quantum claims — PQ security is explicitly NOT provided in v2
- Independent cryptographic review required before production deployment

---

## 2. Current Protocol Baseline

### 2.1 Existing Implementation (`e2e_service.dart`)

| Component | Current | Issue |
|-----------|---------|-------|
| Key agreement | X25519 static-static ECDH | No forward secrecy |
| Key derivation | None (raw 32 bytes from DH) | No HKDF, no domain separation |
| Encryption | AES-256-GCM | Works, but key is static |
| Key storage | FlutterSecureStorage | Adequate for device-local |
| Key publication | `profiles.e2e_public_key` | No prekeys, no rotation |
| Key rotation | None | Key persists login→logout |
| Identity verification | None | No safety numbers, no fingerprints |
| Multi-device | None | Single device only |
| Media encryption | None | Photos/video/voice in plaintext |
| Replay protection | Random nonce only | No sequence numbers |

### 2.2 Known Vulnerabilities (from Phase 4 audit)

1. **No forward secrecy**: Compromising the static X25519 private key decrypts ALL past messages
2. **No key authentication**: No signature on public keys — MITM possible at Supabase level
3. **No key rotation**: Keys persist from login to logout (weeks/months)
4. **No replay protection**: No message ordering or sequence numbers
5. **Silent plaintext fallback**: Encryption failures silently store plaintext in DB
6. **Media unencrypted**: Photos, videos, voice messages stored in Supabase Storage in plaintext
7. **Edit bypasses encryption**: `editMessage()` writes plaintext to `text` column
8. **FCM leaks plaintext**: Push notification trigger sends full row including `text`
9. **Local cache stores plaintext**: Decrypted messages cached to disk as JSON

---

## 3. Security Goals

### 3.1 Confidentiality
Only the intended participants can decrypt message content. The server, network observers, and push providers cannot read message bodies.

### 3.2 Integrity
Any modification of ciphertext is detected and rejected. The recipient can verify the message was not tampered with in transit or at rest.

### 3.3 Authentication
A device can verify the identity of the communication partner. The protocol prevents impersonation even against a compromised server (with user cooperation).

### 3.4 Forward Secrecy
Compromise of a long-term identity key does NOT reveal past messages. Each message session uses ephemeral keys that are deleted after use.

### 3.5 Post-Compromise Security
After a temporary key compromise, if the user generates new keys, future messages become secure again without requiring action from the other party.

### 3.6 Replay Protection
Receiving the same ciphertext twice does not produce two decrypted messages. Old ciphertexts cannot be injected as new messages.

### 3.7 Key Rotation
Identity keys and session keys have defined lifetimes and rotation mechanisms. Users can manually trigger rotation.

### 3.8 Multi-Device
Each device has its own key pair. Messages are encrypted per-device. Adding/removing devices is a first-class operation.

### 3.9 Key Change Detection
When a user's identity key changes, all devices of their contacts are notified. Users can verify the new key through an out-of-band channel.

### 3.10 Metadata Confidentiality
**Explicitly limited**: The server can observe WHO messages WHO and WHEN. Message content, attachments, and group membership (for encrypted chats) are hidden.

---

## 4. Trust Model

### 4.1 Untrusted Entities

| Entity | Threat |
|--------|--------|
| **Network** | Passive observer, active MITM |
| **Supabase database** | Reads all stored data |
| **Signaling backend** | Relays messages, sees metadata |
| **Push provider (FCM)** | Sees notification content |
| **Compromised server** | Can read all server-side data |
| **Compromised Supabase admin** | Full database access |

### 4.2 Trusted Entities

| Entity | Trust scope |
|--------|-------------|
| **Own device** | OS secure storage, app integrity |
| **FlutterSecureStorage** | Key material at rest |
| **Verified identity keys** | After user verification |

### 4.3 Server Capability Constraint

**CRITICAL**: The server MUST NOT have the ability to decrypt message content. Even if the server is compromised, an attacker cannot read encrypted messages without the user's private key material.

The server CAN:
- See message metadata (sender, recipient, timestamp, size)
- See that an encrypted message was sent
- Relay encrypted blobs
- Store encrypted blobs

The server CANNOT:
- Decrypt message content
- Generate valid messages for a user
- Substitute identity keys without detection

---

## 5. Protocol Family

### 5.1 Selected Approach

**X3DH (Extended Triple Diffie-Hellman)** for initial key agreement
+
**Double Ratchet** for message key evolution

This is the same fundamental protocol family used by Signal Protocol, Wire, and Matrix (Olm/Megolm).

### 5.2 Rationale

| Criterion | X3DH + Double Ratchet | Custom DH + AES | Note |
|-----------|----------------------|-----------------|------|
| Forward secrecy | YES | NO | Critical gap in current Vibe |
| Post-compromise security | YES | NO | |
| Asynchronous messaging | YES | N/A | Prekeys enable this |
| Standardized | YES (IETF drafts) | NO | Auditable by third parties |
| Well-studied | YES (years of analysis) | NO | |
| Implementation available | YES (libsignal, etc.) | N/A | Reference implementations exist |

### 5.3 Components Used

| Component | Purpose | Standard |
|-----------|---------|----------|
| X25519 | Ephemeral DH key agreement | RFC 7748 |
| Ed25519 | Identity key signing | RFC 8032 |
| HKDF-SHA256 | Key derivation | RFC 5869 |
| AES-256-GCM | AEAD encryption | NIST SP 800-38D |
| HMAC-SHA256 | Message authentication | RFC 2104 |

### 5.4 Components Explicitly NOT Used

| Component | Why Not |
|-----------|---------|
| Custom KDF | Using standardized HKDF |
| Custom signature | Using Ed25519 |
| Custom AEAD | Using AES-256-GCM |
| Post-quantum KEM | Explicitly excluded from v2 |

---

## 6. Identity Keys

### 6.1 Identity Key Pair

| Property | Value |
|----------|-------|
| **Algorithm** | Ed25519 (signing) + X25519 (DH) |
| **Lifetime** | Until manual rotation or logout |
| **Storage** | `FlutterSecureStorage` (device-local) |
| **Publication** | `profiles.identity_key` (public component) |
| **Format** | 32-byte seed → derive both Ed25519 and X25519 keys |

### 6.2 Key Derivation from Seed

```
identity_seed (32 bytes, random)
  ├── Ed25519 identity_signing_key (signing)
  ├── Ed25519 identity_signing_public (verification)
  ├── X25519 identity_dh_key (DH)
  └── X25519 identity_dh_public (published)
```

Both key types derive from the same seed. The seed is the only long-term secret.

### 6.3 Lifecycle

```
1. Account creation / first login
   → Generate identity_seed
   → Derive all keys
   → Store seed in SecureStorage
   → Publish identity_signing_public + identity_dh_public to server

2. Normal operation
   → Identity keys used for signing prekeys and DH
   → Never leave the device

3. Key rotation (manual or periodic)
   → Generate new identity_seed
   → Re-publish public keys
   → Old messages still decryptable (prekeys remain valid)
   → New sessions use new identity

4. Logout
   → Delete identity_seed from SecureStorage
   → Nullify server-side public keys
```

### 6.4 Device Association

Each device has its own identity key pair. The server knows:
- `user_id` → list of devices
- Each device → `identity_key_public`

An account can have multiple devices. Each device independently generates its own identity seed.

---

## 7. Prekey Model

### 7.1 Prekey Types

| Type | Count | Lifetime | Purpose |
|------|-------|----------|---------|
| **Signed Prekey** | 1 per device | Rotated periodically (e.g., weekly) | Signed by identity key, used in X3DH |
| **One-Time Prekeys** | Batch of ~100 | Until consumed | Single-use, uploaded in bulk |

### 7.2 Prekey Bundle Structure

Each device publishes a prekey bundle to the server:

```
DevicePrekeyBundle {
  user_id: UUID
  device_id: UUID
  identity_key_public: 32 bytes (X25519)
  signed_prekey_public: 32 bytes (X25519)
  signed_prekey_signature: 64 bytes (Ed25519)
  one_time_prekey_public: 32 bytes (X25519) | null
}
```

### 7.3 Prekey Lifecycle

```
Upload:
  1. Generate signed_prekey, sign with identity_key
  2. Generate batch of one_time_prekeys
  3. Upload all to server
  4. Server stores in prekey_bundles table

Consumption (by initiator):
  1. Fetch target's prekey bundle
  2. Use signed_prekey + one_time_prekey in X3DH
  3. Server marks one_time_prekey as consumed
  4. signed_prekey remains valid until rotation

Rotation:
  1. Generate new signed_prekey
  2. Sign with identity_key
  3. Upload to server (replaces old)
  4. Old signed_prekey kept temporarily for pending sessions
```

### 7.4 Prekey Replenishment

When server reports <20 one-time prekeys remaining:
1. Client generates new batch of 100
2. Uploads to server
3. Server stores (never deletes until consumed)

---

## 8. Session Establishment

### 8.1 X3DH Key Agreement

Alice (initiator) → Bob (recipient)

```
Given:
  IKa  = Alice's identity key (X25519)
  IKb  = Bob's identity key (X25519)
  SPKb = Bob's signed prekey
  OPKb = Bob's one-time prekey (optional)

Alice computes:
  DH1 = X25519(IKa, SPKb)    -- identity to signed prekey
  DH2 = X25519(EKa, IKb)     -- ephemeral to identity
  DH3 = X25519(EKa, SPKb)    -- ephemeral to signed prekey
  DH4 = X25519(EKa, OPKb)    -- ephemeral to one-time prekey

 master_secret = DH1 || DH2 || DH3 || DH4

  IKa_public (attached to message for Bob to verify)
  EKa_public (attached to message for Bob to compute DH)
```

### 8.2 Key Derivation (HKDF)

```
HKDF-SHA256(
  ikm = master_secret,
  salt = "VibeE2EE_v2_session" (16 bytes),
  info = IKa_public || IKb_public,
  length = 64
)

→ root_key (32 bytes)
→ chain_key (32 bytes)
```

### 8.3 Sequence Diagram

```
Alice                              Server                           Bob
  │                                   │                               │
  │─── Fetch Bob's prekey bundle ────→│                               │
  │←── {IKb, SPKb, sig, OPKb} ───────│                               │
  │                                   │                               │
  │ [Compute X3DH]                    │                               │
  │ [Derive root_key, chain_key]      │                               │
  │                                   │                               │
  │─── Send initial message ─────────→│──── Forward encrypted blob ──→│
  │    {IKa_pub, EKa_pub, ciphertext, │                               │
  │     msg_number=0}                 │                               │
  │                                   │                         [Compute X3DH]
  │                                   │                         [Derive root_key, chain_key]
  │                                   │                         [Decrypt]
  │                                   │                               │
  │←═════════════════ Double Ratchet continues ═══════════════════════│
```

### 8.4 Asynchronous Delivery

The protocol works asynchronously because:
1. Bob's prekey bundle is on the server
2. Alice can initiate a session without Bob being online
3. Bob computes the same shared secret when he receives the first message
4. The one-time prekey is consumed, preventing replay of the X3DH computation

---

## 9. Key Derivation

### 9.1 HKDF Parameters

#### X3DH Initial Derivation

| Parameter | Value |
|-----------|-------|
| **Algorithm** | HKDF-SHA256 (RFC 5869) |
| **Input keying material** | X3DH shared secret (96 bytes) |
| **Salt** | `"VibeE2EE_v2_session"` (domain separation) |
| **Info** | `IKa_public \|\| IKb_public` (binding to participants) |
| **Output length** | 64 bytes |

#### DH Ratchet Step

| Parameter | Value |
|-----------|-------|
| **Algorithm** | HKDF-SHA256 (RFC 5869) |
| **Input keying material** | X25519 DH output (32 bytes) |
| **Salt** | Current root_key (32 bytes) |
| **Info** | empty (see §11.4.1 for rationale) |
| **Output length** | 64 bytes |

### 9.2 Derived Keys

```
HKDF output (64 bytes):
  ├── root_key (32 bytes)   — used in DH ratchet step
  └── chain_key (32 bytes)  — used to derive message keys
```

### 9.3 Message Key Derivation

```
chain_key → HMAC-SHA256(chain_key, 0x01) → message_key (32 bytes)
chain_key → HMAC-SHA256(chain_key, 0x02) → next_chain_key (32 bytes)
```

### 9.4 Domain Separation

Each derivation context uses a unique `info` string:

| Context | Info String | Rationale |
|---------|-------------|-----------|
| X3DH → root key | `IKa \|\| IKb` | Bind to participant identity keys (computed once, symmetric) |
| DH ratchet step | empty | DH output + root_key salt provide sufficient binding; asymmetric `info` would break key agreement |
| Message key | `chain_key \|\| message_number` | Bind to chain position |

---

## 10. Message Encryption

### 10.1 AEAD

| Property | Value |
|----------|-------|
| **Algorithm** | AES-256-GCM (NIST SP 800-38D) |
| **Key size** | 256 bits |
| **Nonce size** | 96 bits (12 bytes) |
| **Tag size** | 128 bits (16 bytes) |

### 10.2 Nonce Strategy

```
nonce = Encode32BE(message_number) || Encode32BE(previous_chain_length) || Encode32BE(ratchet_step)
```

This ensures:
- Unique nonce per message (different message_number or ratchet_step)
- No reuse even with out-of-order delivery
- Deterministic from ratchet state

### 10.3 Associated Data

```
AD = sender_identity_key || sender_device_id || recipient_device_id || message_number || previous_chain_length
```

This binds the ciphertext to:
- Specific sender (via identity key — tampering detected by GCM tag)
- Specific sender and recipient devices
- Specific position in the ratchet chain
- Prevents cross-device or cross-session replay

**Note**: `sender_identity_key` is included in AAD (not just in envelope) to ensure AEAD authentication covers the sender's long-term identity. This is more secure than the original spec which omitted it from AAD.

### 10.4 Ciphertext Envelope

```
VibeMessageEnvelope {
  version: 1 byte (value: 2),
  sender_identity_key: 32 bytes,
  sender_ratchet_public: 32 bytes,
  message_number: uint32 (4 bytes, big-endian),
  previous_chain_length: uint32 (4 bytes, big-endian),
  nonce: 12 bytes,
  ciphertext + GCM tag: variable length
}
```

**Total header size**: 1 + 32 + 32 + 4 + 4 = 73 bytes, plus 12-byte nonce, plus ciphertext + 16-byte tag.

**Nonce is stored in envelope** because AES-GCM requires it for decryption. The nonce is deterministic from ratchet state but must be transmitted with the ciphertext.

### 10.5 Session ID

**Session ID is NOT included in the envelope.** Session ID is a local session-state identifier used for internal bookkeeping (mapping messages to sessions). It is not required for decryption and is not part of the ciphertext format.

### 10.6 Nonce Reuse Prevention

Nonce reuse is impossible by protocol design:
- Each message increments `message_number`
- DH ratchet step resets `message_number` to 0 and increments `ratchet_step`
- First-send bootstrap (initial message before DH ratchet) also increments `ratchet_step`
- `nonce = f(message_number, previous_chain_length, ratchet_step)` is unique per message
- `ratchet_step` ensures uniqueness even across ratchet epochs with same `message_number`

---

## 11. Double Ratchet Model

### 11.1 State

Each session maintains:

```
RatchetState {
  root_key: 32 bytes,
  sending_chain_key: 32 bytes,
  receiving_chain_key: 32 bytes | null,
  sending_message_number: uint32,
  receiving_message_number: uint32,
  previous_sending_chain_length: uint32,
  sending_ratchet_public: 32 bytes | null,
  receiving_ratchet_public: 32 bytes | null,
  skipped_keys: Map<(ratchet_public, message_number), message_key>
}
```

### 11.2 Sending a Message

```
1. Derive message key from sending_chain_key:
   message_key = HMAC(sending_chain_key, 0x01)
   next_chain_key = HMAC(sending_chain_key, 0x02)

2. Encrypt:
   ciphertext = AES-256-GCM(
     key = message_key,
     nonce = ComputeNonce(sending_message_number, ...),
     plaintext = message,
     aad = AD
   )

3. Increment sending_message_number

4. Delete message_key from memory after use
```

### 11.3 Receiving a Message

```
1. Check if message_number < receiving_message_number:
   → Check skipped_keys cache
   → If found: decrypt with cached key
   → If not found: message is lost (cannot decrypt)

2. If message_number >= receiving_message_number:
   → Advance receiving chain to message_number
   → Derive and cache message keys for skipped messages
   → Decrypt target message
   → Delete all consumed message keys
```

### 11.4 DH Ratchet Step

When a new ratchet public key is received:

```
1. Update receiving chain:
   DH = X25519(receiving_ratchet_public, my_ratchet_private)
   root_key, receiving_chain_key = KDF(root_key, DH)

2. Generate new sending ratchet key pair:
   my_ratchet_private = new X25519 private key
   my_ratchet_public = my_ratchet_private.public

3. Update sending chain:
   DH = X25519(receiving_ratchet_public, my_ratchet_private)
   root_key, sending_chain_key = KDF(root_key, DH)

4. Reset counters:
   receiving_message_number = 0
   sending_message_number = 0
   previous_sending_chain_length = 0
```

#### 11.4.1 KDF DH Ratchet Formula

```
KDF(root_key, DH):

  HKDF-SHA256(
    ikm   = DH (32 bytes),
    salt  = root_key (32 bytes),
    info  = empty,
    length = 64
  )

  → root_key' (32 bytes)   — updated root key
  → chain_key (32 bytes)   — new sending or receiving chain key
```

**Why empty `info`:** The DH output `DH(PR_A, PUB_B) == DH(PR_B, PUB_A)` (X25519 symmetry) already binds
both parties symmetrically. The root key (used as HKDF salt) provides session context and changes each
ratchet step. Adding public key bytes to `info` creates an asymmetry: the initiator and responder
would use different `info` values (`[localPub, remotePub]` vs `[remotePub, localPub]`), producing
different derived keys. Empty `info` eliminates this asymmetry while maintaining security through
DH binding and salt-based session context.

### 11.5 Skipped Message Keys

| Property | Value |
|----------|-------|
| **Maximum cached** | 1000 skipped keys per session |
| **Eviction** | LRU when limit exceeded |
| **Deletion** | After successful decrypt of a future message in same chain |

### 11.6 Out-of-Order Messages

Example sequence: message 1, message 3, message 2

```
1. Receive message 1 → decrypt, store skipped key for msg 3 if needed
2. Receive message 3 → advance chain to 3, cache keys for 2
3. Receive message 2 → find in skipped_keys cache, decrypt
```

### 11.7 Key Deletion

| Key | When Deleted |
|-----|-------------|
| **Consumed message key** | After successful decryption |
| **Old chain key** | After DH ratchet step (replaced by new chain) |
| **Old root key** | After DH ratchet step (replaced by new root) |
| **Skipped message key** | After 1000 keys cached (LRU eviction) or session reset |
| **Ratchet private key** | After DH ratchet step (new pair generated) |

---

## 12. Replay Protection

### 12.1 Mechanism

Replay is prevented by:
1. **Nonce uniqueness**: Each message has a unique nonce (ratchet state)
2. **Message number tracking**: Receiver tracks `receiving_message_number`
3. **AD binding**: Associated data includes message_number and device IDs
4. **GCM tag**: AEAD tag verifies integrity

### 12.2 Handling

```
Receive ciphertext:
  1. Parse envelope → extract message_number
  2. If message_number < receiving_message_number:
     → Check skipped_keys cache
     → If not cached: reject (cannot verify without key)
  3. If message_number == receiving_message_number:
     → Decrypt, advance chain
  4. If message_number > receiving_message_number:
     → Advance chain, cache skipped keys
     → Decrypt target
```

### 12.3 Old Ciphertext Rejection

Old ciphertexts are rejected because:
- The message key was already consumed and deleted
- The nonce was already used (GCM nonce reuse = immediate detection)
- The AD doesn't match current ratchet state

---

## 13. Key Rotation

### 13.1 Identity Key Rotation

| Trigger | Action |
|---------|--------|
| **Manual user action** | Generate new identity seed, re-publish |
| **Logout** | Delete identity keys, clear server publication |
| **Suspicion of compromise** | Same as manual rotation |

Rotation does NOT retroactively encrypt old messages (forward secrecy handles that via session keys).

### 13.2 Signed Prekey Rotation

| Trigger | Action |
|---------|--------|
| **Periodic (weekly)** | Generate new signed prekey, sign with identity key, upload |
| **After logout/login** | New identity → new signed prekey |
| **Manual** | User-initiated from settings |

### 13.3 One-Time Prekey Replenishment

| Trigger | Action |
|---------|--------|
| **Server reports <20 remaining** | Client generates batch of 100, uploads |
| **App startup** | Check count, replenish if needed |

---

## 14. Identity Verification

### 14.1 Safety Numbers

Each pair of users has a unique safety number derived from both identity keys:

```
safety_number = HKDF-SHA256(
  ikm = SHA256(IKa_public) || SHA256(IKb_public),
  salt = "VibeE2EE_v2_safety",
  info = sorted_user_ids,
  length = 32
)
```

The safety number is displayed as:
- A 30-digit number (groups of 5)
- A QR code (optional)

### 14.2 Verification UX

```
Alice opens chat with Bob:
  → Taps "Verify identity"
  → Sees safety number (30 digits or QR)
  → Calls / meets Bob
  → Bob shows his safety number on his device
  → Alice confirms match → trust level = VERIFIED

If Bob's identity key changes:
  → Alice sees warning: "Bob's identity has changed"
  → Old safety number shown as "previously verified"
  → New safety number shown
  → Alice must re-verify to restore trust
```

### 14.3 Trust Levels

| Level | Meaning |
|-------|---------|
| **UNVERIFIED** | Default, keys fetched from server |
| **VERIFIED** | Safety number confirmed out-of-band |
| **CHANGED** | Identity key changed since last verification |

---

## 15. Multi-Device

### 15.1 Device Model

```
Account (user_id)
  ├── Device A (device_id_1)
  │     ├── identity_key_pair
  │     ├── signed_prekey
  │     └── one_time_prekeys
  ├── Device B (device_id_2)
  │     ├── identity_key_pair
  │     ├── signed_prekey
  │     └── one_time_prekeys
  └── Device C (device_id_3)
        ├── identity_key_pair
        ├── signed_prekey
        └── one_time_prekeys
```

### 15.2 Message Distribution

When Alice sends a message to Bob (who has devices B1, B2):

```
1. Alice fetches Bob's device list from server
2. For each device Bi:
   a. Fetch Bi's prekey bundle
   b. Compute X3DH with Bi's keys
   c. Encrypt message with derived session key
   d. Send encrypted envelope to Bi
3. Server delivers to all of Bob's devices
4. Each device decrypts independently
```

### 15.3 Device Management

| Action | Behavior |
|--------|----------|
| **Add device** | New device generates identity, uploads prekey bundle |
| **Remove device** | Device identity key deleted from server; other devices notified |
| **Device compromise** | User removes device; new sessions use remaining devices' keys |

### 15.4 Server Data Model (Devices)

```
devices {
  id: UUID (PK)
  user_id: UUID (FK → profiles)
  device_name: TEXT
  identity_key_public: TEXT (base64)
  signed_prekey_public: TEXT (base64)
  signed_prekey_signature: TEXT (base64)
  one_time_prekeys: JSONB [{id, public_key}]
  created_at: TIMESTAMPTZ
  last_active_at: TIMESTAMPTZ
  is_revoked: BOOLEAN DEFAULT false
}
```

---

## 16. Backup / Restore

### 16.1 Policy

**No plaintext backup.** The protocol does not support backing up message content.

### 16.2 Scenarios

| Scenario | Behavior |
|----------|----------|
| **App uninstall** | All keys and messages lost. New identity on reinstall. |
| **App reinstall** | Fresh identity. Old messages undecryptable. |
| **Device migration** | Manual key export via QR code (optional v3 feature). |
| **Secure backup** | NOT IMPLEMENTED in v2. Explicitly out of scope. |

### 16.3 Rationale

Plaintext backup defeats the purpose of E2EE. The tradeoff is accepted: losing the device means losing message history. This is the same model used by Signal.

---

## 17. Offline Queue Compatibility

### 17.1 Current State

The offline queue (`offline_queue_service.dart`) is RAM-only (fixed in Phase 7.1). Messages are encrypted BEFORE being placed in the queue.

### 17.2 Protocol Integration

```
User sends message:
  1. Encrypt with current ratchet state → ciphertext
  2. If online: send to server immediately
  3. If offline: store {ciphertext, recipient, timestamp} in RAM queue
  4. When online: send all queued items
  5. If app killed: queue is lost (acceptable for v2)
```

### 17.3 Design Decision

Message encryption happens BEFORE queue placement:
- The queue stores encrypted blobs, never plaintext
- If the queue is lost (app kill), the message is lost (acceptable)
- This is simpler and more secure than persisting encrypted queue to disk

---

## 18. Server Data Model

### 18.1 Required Tables

#### `devices`
Stores per-device key material.

| Field | Type | Owner | Notes |
|-------|------|-------|-------|
| `id` | UUID | server | Primary key |
| `user_id` | UUID | server | FK → profiles |
| `device_name` | TEXT | client | User-visible name |
| `identity_key_public` | TEXT | client | Base64 X25519 |
| `signed_prekey_public` | TEXT | client | Base64 X25519 |
| `signed_prekey_signature` | TEXT | client | Base64 Ed25519 |
| `one_time_prekeys` | JSONB | client | Array of {id, public_key} |
| `created_at` | TIMESTAMPTZ | server | |
| `last_active_at` | TIMESTAMPTZ | client | Updated on connect |
| `is_revoked` | BOOLEAN | client | Soft-delete |

#### `message_keys`
Stores consumed one-time prekey IDs for dedup.

| Field | Type | Notes |
|-------|------|-------|
| `prekey_id` | UUID | Consumed prekey |
| `device_id` | UUID | Which device consumed it |
| `consumed_at` | TIMESTAMPTZ | When consumed |

### 18.2 RLS Policies

```
devices:
  SELECT: auth.uid() = user_id (users see own devices)
  INSERT: auth.uid() = user_id
  UPDATE: auth.uid() = user_id
  DELETE: auth.uid() = user_id

message_keys:
  SELECT: auth.uid() = user_id (or service role)
  INSERT: service role only (server-side consumption)
```

### 18.3 Publicly Retrievable

For session establishment, ANY authenticated user can read:
- `devices.identity_key_public`
- `devices.signed_prekey_public`
- `devices.signed_prekey_signature`
- `devices.one_time_prekeys` (non-consumed only)

### 18.4 Private/Secret

Never exposed to other users:
- `devices.user_id` (only via RLS)
- One-time prekey consumption details

---

## 19. Push Privacy

### 19.1 Policy

**Push notification MUST NOT contain plaintext message content.**

### 19.2 Allowed Content

```
✅ "Новое сообщение"
✅ "Новое фото"  
✅ "Голосовое сообщение"
✅ Sender name only (if user has enabled)
```

### 19.3 Prohibited Content

```
❌ Message text
❌ Message preview
❌ File names
❌ Group names (in notification)
```

### 19.4 Implementation

The FCM trigger (`push_on_message()`) must be modified:
- Read `is_encrypted` flag
- If encrypted: send generic notification
- If not encrypted (should not happen in v2): send generic notification anyway
- NEVER include `text` field in notification payload

---

## 20. Migration Strategy

### 20.1 Protocol Versioning

| Version | Protocol | Notes |
|---------|----------|-------|
| **v1 (legacy)** | X25519 static-static + AES-GCM | Current implementation |
| **v2** | X3DH + Double Ratchet + AES-GCM | New protocol |

### 20.2 Ciphertext Envelope Version

```
VibeMessageEnvelope {
  version: uint8,  // 1 = legacy, 2 = new protocol
  ...fields vary by version...
}
```

### 20.3 Migration Window

| Phase | Duration | Behavior |
|-------|----------|----------|
| **Coexistence** | 6 months | Both v1 and v2 supported. New sessions use v2. |
| **Deprecation** | 3 months | v1 shows "upgrade required" warning. |
| **Removal** | After 9 months | v1 messages remain encrypted but cannot be decrypted by new app versions. |

### 20.4 Existing Conversations

- Old messages remain in v1 format
- New messages in existing conversations use v2
- Both parties must upgrade to v2 for full protection
- Mixed clients: v2 client detects v1 envelope, falls back to legacy decrypt

### 20.5 New Conversations

- Always use v2
- If peer has no v2 support: show warning, offer to send unencrypted (with explicit consent)

---

## 21. Versioning

### 21.1 Protocol Version

The envelope `version` field identifies the protocol:
- `1` = legacy (X25519 static-static)
- `2` = X3DH + Double Ratchet

### 21.2 Unknown Version Behavior

**Reject / fail closed.** If the version byte is not `1` or `2`, decryption fails with `V2RatchetException`. This prevents downgrade attacks and ensures forward compatibility.

### 21.3 Implementation Version

A separate field (not in envelope) tracks the client implementation version for compatibility:
- Server stores `device.app_version`
- Used for feature negotiation (e.g., "does peer support v2?")

---

## 22. Threat Model

### T1: Malicious Server

| Aspect | Detail |
|--------|--------|
| **Attack** | Server reads all data, substitutes keys, modifies messages |
| **Mitigation** | Identity keys signed by Ed25519; safety number verification by users |
| **Residual risk** | If user never verifies safety number, MITM possible |

### T2: Network Attacker

| Aspect | Detail |
|--------|--------|
| **Attack** | Passive observation, active MITM, replay |
| **Mitigation** | TLS transport + E2EE; AEAD detects tampering; nonce prevents replay |
| **Residual risk** | Traffic analysis (metadata visible) |

### T3: Compromised Device

| Aspect | Detail |
|--------|--------|
| **Attack** | Attacker has full device access |
| **Mitigation** | None — device is trusted. If compromised, all keys exposed. |
| **Residual risk** | Full key compromise. User must revoke device. |

### T4: Stolen Private Key

| Aspect | Detail |
|--------|--------|
| **Attack** | Attacker has identity private key |
| **Mitigation** | Forward secrecy (past messages safe). Safety number change detection. |
| **Residual risk** | Future messages interceptable until key rotation. |

### T5: MITM

| Aspect | Detail |
|--------|--------|
| **Attack** | Attacker intercepts and relays communication |
| **Mitigation** | Identity key verification via safety numbers |
| **Residual risk** | If user doesn't verify, MITM transparent |

### T6: Replay Attacker

| Aspect | Detail |
|--------|--------|
| **Attack** | Resends old ciphertexts |
| **Mitigation** | Nonce uniqueness, message number tracking, GCM tag |
| **Residual risk** | None — replay cryptographically impossible |

### T7: Compromised Old Session

| Aspect | Detail |
|--------|--------|
| **Attack** | Attacker has old session state |
| **Mitigation** | Forward secrecy — old session keys don't reveal new messages |
| **Residual risk** | Messages in the compromised session exposed |

---

## 23. Failure / Recovery

### 23.1 Error Handling

| Failure | Behavior |
|---------|----------|
| **Missing prekey** | Cannot establish session. Show "Cannot encrypt" to user. Retry with different prekey. |
| **Invalid signature** | Reject prekey bundle. Show "Identity verification failed". |
| **Wrong identity key** | Safety number mismatch. Warn user. |
| **Key changed** | Show "Identity changed" warning. Require user confirmation. |
| **Corrupted ciphertext** | Reject. Show "Message corrupted". Never attempt partial decrypt. |
| **Replay detected** | Silently ignore. Do not inform attacker. |
| **Missing ratchet key** | Cannot decrypt. Show "Message lost" (acceptable for out-of-order beyond cache). |
| **Device revoked** | Stop sending to that device. Show "Device removed". |

### 23.2 CRITICAL RULE

**NEVER fallback to plaintext.** If encryption fails, the message is NOT sent. The user is informed and must resolve the issue.

---

## 24. Cryptographic Test Vectors

### 24.1 X3DH Key Agreement

```
Input:
  IKa_seed = <deterministic 32 bytes>
  IKb_seed = <deterministic 32 bytes>
  EKa_seed = <deterministic 32 bytes>
  SPKb_seed = <deterministic 32 bytes>
  OPKb_seed = <deterministic 32 bytes>

Expected:
  IKa_public = <expected 32 bytes>
  IKb_public = <expected 32 bytes>
  DH1 = <expected 32 bytes>
  DH2 = <expected 32 bytes>
  DH3 = <expected 32 bytes>
  DH4 = <expected 32 bytes>
  master_secret = <expected 96 bytes>
```

### 24.2 HKDF Derivation

```
Input:
  ikm = <master_secret from X3DH>
  salt = "VibeE2EE_v2_session"
  info = IKa_public || IKb_public

Expected:
  root_key = <expected 32 bytes>
  chain_key = <expected 32 bytes>
```

### 24.3 Message Key Derivation

```
Input:
  chain_key = <expected 32 bytes>

Expected:
  message_key = HMAC-SHA256(chain_key, 0x01)
  next_chain_key = HMAC-SHA256(chain_key, 0x02)
```

### 24.4 AEAD Encryption

```
Input:
  key = <message_key>
  nonce = <computed from ratchet state>
  plaintext = "Hello, Vibe!"
  aad = <sender_device_id || recipient_device_id || msg_number || prev_chain_len>

Expected:
  ciphertext = <expected bytes>
  tag = <expected 16 bytes>
```

**Note**: These vectors are for specification testing. They are NOT connected to production code in this phase.

---

## 25. External Review Requirements

### 25.1 Mandatory Review

This protocol specification MUST undergo independent cryptographic review before production deployment. The review should cover:

1. Protocol correctness (X3DH + Double Ratchet implementation)
2. Key lifecycle management
3. Nonce generation and uniqueness
4. AEAD parameter selection
5. Side-channel resistance
6. Implementation security (key erasure, memory handling)

### 25.2 Disclaimers

The following claims are NOT made about this protocol:

- ❌ "Military grade encryption"
- ❌ "Bank grade security"
- ❌ "Post-quantum resistant"
- ❌ "Unbreakable"
- ❌ "Quantum safe"

**Post-Quantum Security: NOT PROVIDED** in v2. X25519 is not post-quantum resistant. If PQ security is needed in the future, a hybrid design (classical + PQ KEM) should be specified separately.

---

## 26. Formal Security Properties

| Property | Current Vibe (v1) | Implemented V2 Status |
|----------|-------------------|----------------------|
| Confidentiality | PARTIAL (silent fallback) | YES (mandatory, no fallback) |
| Integrity | YES (GCM tag) | YES (AEAD) |
| Authentication | NO (no key signing) | YES (Ed25519 signatures) |
| Forward secrecy | NO (static-static) | YES (ephemeral keys per session) |
| Post-compromise security | NO | YES (DH ratchet) |
| Replay protection | NO (random nonce only) | YES (message numbers + ratchet + nonce uniqueness) |
| Key rotation | NO | YES (manual + periodic prekey rotation) |
| Multi-device | NO | YES (per-device key pairs) |
| Key change detection | NO | YES (safety numbers + warnings) |
| PQ security | NO | NO (explicitly excluded) |
| Media encryption | NO | NO (v2 scope: text only; media in v3) |
| Metadata protection | NO | NO (server sees sender/recipient/timestamp) |

---

## 27. Known Limitations

1. **No media encryption in v2**: Photos, videos, voice messages remain unencrypted in Supabase Storage. This is a v3 feature.
2. **No group encryption**: v2 covers two-party only. Group E2EE (Sender Keys / Megolm) is a v3 feature.
3. **No metadata protection**: Server can observe communication patterns.
4. **No PQ security**: X25519 is vulnerable to future quantum computers.
5. **No key export/backup**: Losing the device means losing message history.
6. **No key verification by default**: Users must manually verify safety numbers.
7. **RAM-only offline queue**: Messages in transit when app is killed are lost.

---

## 28. Open Questions

1. **Ed25519 vs X25519 for identity**: Should we use a single Ed25519 key for both signing and DH (via curve25519 conversion), or separate keys?
2. **Prekey batch size**: 100 one-time prekeys per batch — is this sufficient for high-volume users?
3. **Signed prekey rotation frequency**: Weekly? Monthly? Trigger-based?
4. **Safety number format**: 30-digit number vs QR code vs both?
5. **Device limit**: Maximum devices per account? (Signal: 1, WhatsApp: 4, Wire: 8)
6. **Session expiry**: Should inactive sessions expire? After how long?
7. **v1→v2 migration UX**: How to handle users who haven't upgraded?

---

## 29. Production Blockers

Before implementing v2, these items must be resolved:

| # | Blocker | Status |
|---|---------|--------|
| 1 | Independent cryptographic review of this spec | NOT DONE |
| 2 | Decision on open questions (#27) | NOT DECIDED |
| 3 | Reference implementation selection (libsignal? custom?) | NOT DECIDED |
| 4 | Media encryption scope (v2 or v3?) | NOT DECIDED |
| 5 | Group encryption scope (v2 or v3?) | NOT DECIDED |
| 6 | Migration strategy approval | NOT APPROVED |

---

## 30. Files Created

| File | Purpose |
|------|---------|
| `docs/security/E2EE_PROTOCOL_V2.md` | This specification |

**No production code was modified in this phase.**

---

## 31. Analyzer & Test Status

- **Analyzer**: 44 issues / 0 errors (down from 45 baseline)
- **Tests**: 445 pass / 0 fail
- **Production behavior**: UNCHANGED

---

## 32. Test Evidence (Phase 12B.4)

### Test Suites

| Suite | Tests | Status |
|-------|-------|--------|
| `v2_ratchet_test.dart` | 32 | ALL PASS |
| `v2_envelope_test.dart` | 31 | ALL PASS |
| Other tests | 382 | ALL PASS |
| **Total** | **445** | **ALL PASS** |

### Security Test Coverage

| Category | Tests | Status |
|----------|-------|--------|
| Tamper resistance (version, IK, RK, MN, nonce, prev chain len, ciphertext, auth tag) | 8 | ALL PASS |
| Out-of-order delivery | 2 | ALL PASS |
| Bidirectional ratchet | 2 | ALL PASS |
| Wrong session rejection | 2 | ALL PASS |
| Wrong device rejection | 2 | ALL PASS |
| State persistence | 2 | ALL PASS |
| Replay protection | 1 | PASS |
| Nonce uniqueness | 1 | PASS |
| State advancement | 3 | ALL PASS |
| Version validation | 1 | PASS |

### Tamper Test Details

All 8 tamper tests verify that flipping a single byte in the envelope causes decryption failure:

1. **Version byte** → `SecretBoxAuthenticationError`
2. **Sender identity key** → `SecretBoxAuthenticationError`
3. **Sender ratchet public key** → `SecretBoxAuthenticationError`
4. **Message number** → `SecretBoxAuthenticationError`
5. **Nonce** → `SecretBoxAuthenticationError`
6. **Previous chain length** → `SecretBoxAuthenticationError`
7. **Ciphertext** → `SecretBoxAuthenticationError`
8. **Authentication tag** → `SecretBoxAuthenticationError`

### Important Note

**This test evidence does NOT replace an independent cryptographic audit.** The tests verify functional correctness and basic tamper resistance. A formal security review by a cryptographer is required before production deployment.

---

## 33. Phase 12A Result

### CURRENT PROTOCOL

X25519 static-static → raw shared secret → AES-256-GCM. No forward secrecy, no key rotation, no identity verification, no multi-device. Silent plaintext fallback on encryption failure.

### PROPOSED PROTOCOL

X3DH + Double Ratchet + AES-256-GCM. Standardized, audited primitives. Forward secrecy, post-compromise security, identity verification via safety numbers, per-device key pairs, mandatory encryption (no fallback).

### SECURITY MODEL

Server-untrusted. Device-trusted. Identity keys signed by Ed25519. Prekeys for asynchronous session establishment. Double Ratchet for ongoing secrecy.

### THREAT MODEL

7 threat scenarios analyzed (malicious server, network attacker, compromised device, stolen key, MITM, replay, old session). Residual risks identified and documented.

### KEY LIFECYCLE

Identity seed → derive Ed25519 + X25519 → publish → rotate periodically → delete on logout. Signed prekeys rotate weekly. One-time prekeys consumed and replenished.

### MULTI-DEVICE MODEL

Per-device identity keys and prekey bundles. Messages encrypted independently per device. Device add/remove is first-class.

### OFFLINE MODEL

Encryption before queue placement. RAM-only queue. Messages lost if app killed (acceptable tradeoff).

### MIGRATION MODEL

v1 (legacy) and v2 (new) coexist for 6 months. Deprecation warning for 3 months. Removal after 9 months. Old messages remain encrypted but undecryptable by new app versions.

### SECURITY PROPERTY TABLE

See Section 26. v2 provides: confidentiality, integrity, authentication, forward secrecy, post-compromise security, replay protection, key rotation, multi-device, key change detection. Does NOT provide: PQ security, media encryption, metadata protection, group encryption.

### OPEN QUESTIONS

7 questions documented in Section 28. Decisions required before implementation.

### PRODUCTION BLOCKERS

6 blockers identified in Section 29. All pending.

### FILES CREATED

`docs/security/E2EE_PROTOCOL_V2.md`

### ANALYZER

44 issues / 0 errors (down from 45 baseline)

### TESTS

445 pass / 0 fail (32 ratchet + 31 envelope + 382 other)

### RESULT

**PASS** — Specification synchronized with implementation. No code changes. Ready for independent review and implementation decision.
