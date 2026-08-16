# Phase 12D.7 — Identity & Key Lifecycle Deep Verification

**Date**: 2026-08-16
**Status**: **FAIL — CRITICAL FINDINGS REQUIRING PRODUCTION FIXES**
**Tests**: 42/42 PASS
**Base**: 1607 tests (1607 + 42 new)
**Audit scope**: Independent deep verification of Phase 12D.6 production code

## Executive Summary

Deep audit of Phase 12D.6 implementation revealed **7 findings** (2 HIGH, 3 MEDIUM, 1 LOW, 1 INFO). Two HIGH findings require production code fixes before the system can be considered secure for identity rotation.

The 12D.6 test suite (55 tests) verified **happy paths** and **crypto primitives** but missed **atomicity failures**, **trust state gaps**, and **documentation-vs-reality mismatches**.

---

## Findings

### F-037: rotateIdentity() does NOT update trust state to CHANGED

| Field | Value |
|---|---|
| **Severity** | HIGH |
| **Confidence** | CONFIRMED |
| **Affected** | `e2e_v2_service.dart:90-144` |
| **Code** | `rotateIdentity()` |

**Description**: The function generates new identity, updates local state, saves seed, publishes to server, generates new SPK/OTKs. It NEVER calls `handleKeyChange()` or `setTrustState()` for any peer. Documentation at line 82 states "existing trust state becomes CHANGED" but the code does not implement this.

**Impact**: After identity rotation, old peers who were VERIFIED remain VERIFIED even though the identity has changed. The attacker who compromised the old identity can continue to be trusted by peers who haven't manually re-verified.

**Why 12D.6 tests missed it**: Tests verify that trust state transitions work correctly when `handleKeyChange()` is called directly, but never verify that `rotateIdentity()` calls it.

**Recommended fix**: Add a loop in `rotateIdentity()` that calls `handleKeyChange()` for all known peers after rotation.

---

### F-038: rotateIdentity() has no atomicity guarantee

| Field | Value |
|---|---|
| **Severity** | HIGH |
| **Confidence** | CONFIRMED |
| **Affected** | `e2e_v2_service.dart:90-144` |
| **Code** | `rotateIdentity()` |

**Description**: The function performs 5 sequential steps with no transaction or rollback:
1. Generate new keys (in-memory)
2. Update in-memory state
3. Save new seed to SecureStorage (old seed overwritten)
4. Publish new identity to server
5. Generate new SPK/OTKs

If step 4 (server publish) fails, the old seed is permanently overwritten in SecureStorage. On restart, `loadKeys()` reads the new seed, but the server still has the old identity. The new SPK is signed with the new identity, creating a signature mismatch with the old server identity. This is an **unrecoverable state**.

**Crash window analysis**:
- Crash after step 2: SAFE (in-memory only, SecureStorage has old seed)
- Crash after step 3: INCONSISTENT (new seed saved, server has old identity)
- Crash after step 4: INCOMPLETE (identity rotated, no SPK)
- Crash after step 5: OK (fully rotated)

**Why 12D.6 tests missed it**: Tests use mock/stub storage that doesn't simulate failures.

**Recommended fix**: Implement two-phase commit or at minimum save new seed AFTER server publish succeeds.

---

### F-039: _publishSignedPrekey immediately deactivates old SPK (no 24h transition)

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **Confidence** | CONFIRMED |
| **Affected** | `e2e_v2_service.dart:466-470` |
| **Code** | `_publishSignedPrekey()` |

**Description**: The documentation claims "24h safe transition period" but the code at lines 466-470 immediately deactivates ALL active SPKs:

```dart
await _client
    .from('signed_prekeys')
    .update({'is_active': false})
    .eq('device_id', deviceId)
    .eq('is_active', true);
```

This contradicts the documentation at lines 157-166. In-flight X3DH handshakes using the old SPK will fail immediately after rotation.

**Impact**: Any X3DH handshake in progress during SPK rotation will fail. This breaks the "safe transition" guarantee.

**Why 12D.6 tests missed it**: Tests verify `rotateSignedPrekey()` returns a valid bundle, but never verify server-side behavior (old SPK remains active).

**Recommended fix**: Either implement actual 24h transition (store old SPK with expiry) or update documentation to reflect immediate deactivation.

---

### F-040: rotateSignedPrekey() is a no-op wrapper — no transition logic

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **Confidence** | CONFIRMED |
| **Affected** | `e2e_v2_service.dart:167-170` |
| **Code** | `rotateSignedPrekey()` |

**Description**: The function is:
```dart
Future<SignedPrekeyBundle> rotateSignedPrekey() async {
  return generateSignedPrekey();
}
```

It simply calls `generateSignedPrekey()` — no transition logic, no old SPK storage, no timestamp/expiry. The `spkSafeTransitionHours = 24` constant at line 32 is defined but NEVER referenced in any enforcement logic.

**Impact**: Documentation is misleading. Developers may rely on non-existent safe transition behavior.

**Why 12D.6 tests missed it**: Tests verify the function returns a valid bundle, but never verify the transition mechanism exists.

**Recommended fix**: Either implement the transition logic or remove the misleading documentation.

---

### F-041: _updateOtkCount() has read-modify-write race condition

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **Confidence** | CONFIRMED |
| **Affected** | `e2e_v2_service.dart:279-286` |
| **Code** | `_updateOtkCount()` |

**Description**: The function performs read-modify-write without atomicity:
```dart
Future<void> _updateOtkCount(int delta) async {
  final current = await _countLocalOtks();
  final newCount = (current + delta).clamp(0, 999999);
  await _secureStorage.write(key: 'e2e_v2_otk_count', value: newCount.toString());
}
```

**Race scenario**:
- T1 reads count=19
- T2 reads count=19
- T1 writes count=119 (19+100)
- T2 writes count=119 (19+100)
- Result: 119 instead of 219 — one batch of OTKs is lost

**Impact**: OTK pool can underflow or overflow, causing either no OTKs available for handshakes or unnecessary generation.

**Why 12D.6 tests missed it**: Tests run sequentially, never testing concurrent calls.

**Recommended fix**: Use atomic increment/decrement or a mutex.

---

### F-043: consumeOneTimePrekey() and respondToX3dh() non-atomic

| Field | Value |
|---|---|
| **Severity** | MEDIUM |
| **Confidence** | CONFIRMED |
| **Affected** | `e2e_v2_service.dart:290-301, 672-676` |
| **Code** | `consumeOneTimePrekey()`, `respondToX3dh()` |

**Description**:
- `consumeOneTimePrekey()`: read → delete → mark consumed → update count (4 non-atomic steps)
- `respondToX3dh()`: delete → mark consumed (2 non-atomic steps, NO count update)

**Failure scenarios for consumeOneTimePrekey**:
- A) read OK → delete OK → markConsumed FAIL → count FAIL: key deleted locally, not marked consumed
- B) read OK → delete FAIL: key still exists, can be consumed again (duplicate use)
- C) read OK → delete OK → markConsumed OK → count FAIL: key consumed on server, count not decremented

**Impact**: One-time prekey can be used twice, or key can be lost. Count can diverge from actual stored keys.

**Why 12D.6 tests missed it**: Tests verify happy path only, never simulate partial failures.

**Recommended fix**: Implement transactional semantics or at minimum update count only after successful server consumption.

---

### F-045: Old sessions not invalidated after identity rotation

| Field | Value |
|---|---|
| **Severity** | LOW |
| **Confidence** | CONFIRMED |
| **Affected** | `e2e_v2_service.dart:90-144` |
| **Code** | `rotateIdentity()` |

**Description**: After identity rotation, old X3DH sessions remain functional. Messages continue through old sessions with old root keys. This is correct for forward secrecy but should be explicitly documented.

**Impact**: If old session material was compromised, attacker can still decrypt old-session messages after rotation.

**Why 12D.6 tests missed it**: This is by-design behavior, but the documentation doesn't explicitly state it.

**Recommended fix**: Add documentation clarifying that old sessions remain functional and new sessions require new X3DH.

---

### F-046: _generateSessionId uses non-cryptographic hash (FNV-1a)

| Field | Value |
|---|---|
| **Severity** | INFO |
| **Confidence** | CONFIRMED |
| **Affected** | `e2e_v2_service.dart:848-867` |
| **Code** | `_generateSessionId()` |

**Description**: Session ID is generated using FNV-1a, a non-cryptographic hash. Collision probability is low given input size, but this is a deviation from best practice.

**Impact**: Theoretical collision risk. Not cryptographically critical since session IDs are used for identification, not security.

**Recommended fix**: Use SHA-256 truncated to 16 bytes for session ID generation.

---

## False Assumptions Discovered

| # | Assumption | Reality |
|---|---|---|
| 1 | "Trust state becomes CHANGED after rotation" | rotateIdentity() never touches trust state |
| 2 | "Old SPK remains valid for 24h" | Old SPK is immediately deactivated |
| 3 | "24h transition is enforced" | Constant exists but is never used |
| 4 | "OTK count is accurate" | Race condition allows count divergence |
| 5 | "rotateIdentity() is atomic" | 5 sequential steps with no rollback |
| 6 | "Old fingerprint is marked invalid" | No explicit invalidation |

---

## Security Properties Verified

| Property | Status |
|---|---|
| New identity generates fresh CSPRNG keys | PASS |
| Old private key not sent to server | PASS |
| Old seed overwritten in SecureStorage | PASS (but premature) |
| New fingerprint different from old | PASS |
| Ed25519 signature prevents server substitution | PASS |
| X3DH uses identity key in DH | PASS |
| New session has independent root key | PASS |
| Media AAD binds sender identity key | PASS |
| Key bundle validation rejects invalid signatures | PASS |
| Trust state is local-only (server cannot modify) | PASS |
| CHANGED → VERIFIED requires explicit re-verification | PASS |
| Identity rotation produces different fingerprints | PASS |

---

## Test Coverage

42 tests across 12 groups:
1. Identity Rotation — Trust State (4)
2. SPK Rotation — Actual Behavior (4)
3. OTK Count Tracking (4)
4. Post-Compromise Recovery (3)
5. Failure Injection (5)
6. Session Consistency (2)
7. Downgrade / Rollback (3)
8. Key Bundle Consistency (3)
9. Media Interaction (2)
10. Concurrency (2)
11. Failure Policy (7)
12. Restart / Logout / Reinstall (3)

---

## Regression

- Full suite: 1607 + 42 = 1649 tests
- Analyzer: 0 errors, 0 warnings on new file
- No existing tests broken

---

## Production Fixes Required

### Fix 1: rotateIdentity() must update trust state (F-037)

After rotation, iterate all peers and call `handleKeyChange()`:

```dart
// After step 8 (OTK replenishment)
final verification = E2eV2IdentityVerification.instance;
// Note: requires access to all known peer IDs
// Implementation depends on peer storage backend
```

### Fix 2: rotateIdentity() must not overwrite seed before server publish (F-038)

Reorder steps: publish to server first, THEN save new seed:

```dart
// Step 4: Publish first
await _client.from('devices').update({...}).eq('id', deviceId);
// Step 5: Save seed only after successful publish
await _secureStorage.write(key: 'e2e_v2_identity_seed', value: base64Encode(newSeed));
```

### Fix 3: Implement or document actual SPK transition (F-039, F-040)

Either:
- A) Implement 24h transition with old SPK storage and expiry, OR
- B) Update documentation to state SPK rotation is immediate

### Fix 4: Use atomic OTK count update (F-041)

Replace read-modify-write with atomic operation:
```dart
Future<void> _updateOtkCount(int delta) async {
  // Use a mutex or compute delta locally then write
  final current = await _countLocalOtks();
  final newCount = (current + delta).clamp(0, 999999);
  await _secureStorage.write(key: 'e2e_v2_otk_count', value: newCount.toString());
}
// Note: FlutterSecureStorage doesn't support atomic increment
// Consider using a mutex library or single-writer pattern
```

### Fix 5: Update OTK count on responder consumption (F-043)

In `respondToX3dh()`, add count decrement after OTK consumption.

---

## Protocol Migration

No protocol migration required. All fixes are implementation-level changes to existing code.

---

## FINAL VERDICT

**FAIL** — Two HIGH findings (F-037: trust state not updated, F-038: no atomicity) require production code fixes before identity rotation can be considered secure. Three MEDIUM findings (SPK transition, OTK races) also require fixes.

---

## READY FOR NEXT PHASE

**NO** — Production fixes for F-037, F-038, F-039/F-040, F-041, F-043 must be implemented and verified before proceeding.
