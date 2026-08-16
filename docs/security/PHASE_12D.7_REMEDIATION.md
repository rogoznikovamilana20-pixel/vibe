# Phase 12D.7 Remediation — Identity & Key Lifecycle Security Fixes

**Date**: 2026-08-16
**Status**: **PASS**
**Tests**: 54/54 PASS
**Base**: 1649 tests (1649 + 54 new)
**Audit scope**: Fixes for all validated findings from Phase 12D.7

## Production Changes

### `e2e_v2_identity_verification.dart`
- Added `getAllPeerIds()` — enumerates all peers with stored trust state
- Added `transitionAllVerifiedAfterRotation()` — transitions VERIFIED → CHANGED for all peers

### `e2e_v2_service.dart`
- Added `dart:async` import for `Completer`
- **F-037**: `rotateIdentity()` now calls `transitionAllVerifiedAfterRotation()` after rotation
- **F-038**: `rotateIdentity()` uses PREPARING → PUBLISHED → COMMITTED state machine:
  - Saves new seed as `e2e_v2_identity_seed_pending` before overwriting main seed
  - Only overwrites main seed after successful server publication
  - Added `resumeIdentityRotationIfNeeded()` for crash recovery
- **F-039/F-040**: `rotateSignedPrekey()` now:
  - Archives old SPK with expiry timestamp (`e2e_v2_signed_prekey_old_*`)
  - Does NOT immediately deactivate old SPK on server
  - Added `isSignedPrekeyValid()` with 24h expiry enforcement
  - Added `loadSignedPrekeyPrivate()` for current/old SPK access
  - Added `_cleanupExpiredOldSpk()` for expired key cleanup
- **F-041**: `_updateOtkCount()` now uses mutex (`_acquireOtkMutex`/`_releaseOtkMutex`)
- **F-043**: `consumeOneTimePrekey()` now:
  - Uses mutex for atomicity
  - Order: read → delete → mark consumed (best-effort) → decrement count
  - Idempotent: second call returns null
- **F-043**: `respondToX3dh()` now decrements OTK count after consumption
- **F-043**: `replenishOneTimePrekeysIfNeeded()` now uses mutex

## Security Findings — Independent Audit

### F-037: FIXED
- **Code path**: `rotateIdentity()` → `transitionAllVerifiedAfterRotation()` → iterates all peers → VERIFIED → CHANGED
- **Invariant**: After rotation, no peer remains VERIFIED without explicit re-verification
- **Adversarial test**: VERIFIED → rotation → CHANGED → server attempts VERIFIED → remains CHANGED → explicit verify → VERIFIED
- **Residual risk**: LOW — peers not yet contacted remain UNKNOWN (correct behavior)

### F-038: FIXED
- **Code path**: `rotateIdentity()` saves pending seed → publishes to server → overwrites main seed → cleanup
- **Invariant**: Old seed is never destroyed before server publication succeeds
- **Adversarial test**: Crash at every stage is recoverable via `resumeIdentityRotationIfNeeded()`
- **Residual risk**: LOW — server publication failure leaves pending seed for retry/rollback

### F-039/F-040: FIXED
- **Code path**: `rotateSignedPrekey()` archives old SPK with expiry → publishes new SPK → cleanup expired
- **Invariant**: Old SPK remains valid for 24h, new SPK active immediately
- **Adversarial test**: `isSignedPrekeyValid()` checks expiry; `loadSignedPrekeyPrivate()` returns null for expired
- **Residual risk**: LOW — server may have multiple active SPKs (by design during transition)

### F-041: FIXED
- **Code path**: `_updateOtkCount()` acquires mutex → read → modify → write → release
- **Invariant**: Concurrent updates are serialized, no lost increments
- **Adversarial test**: 100 concurrent increments = correct count (100)
- **Residual risk**: LOW — mutex is in-process only (acceptable for single-device)

### F-043: FIXED
- **Code path**: `consumeOneTimePrekey()` acquires mutex → read → delete → mark (best-effort) → decrement → release
- **Invariant**: OTK cannot be consumed twice (idempotent); count stays consistent
- **Adversarial test**: Duplicate consume returns null; server failure is recoverable
- **Residual risk**: LOW — server may have stale unconsumed entry (acceptable)

### F-045: DOCUMENTED
- **Policy**: Old sessions remain valid for in-flight messages after identity rotation
- **Rationale**: Preserves forward secrecy; old sessions use old root key, not identity key
- **Test**: Old session can still wrap/unwrap media keys; new session uses different root key

### F-046: ACCEPTED
- **Property**: Session ID is routing/storage identifier only, never cryptographic key material
- **Rationale**: FNV-1a collision causes reliability issue, not authentication bypass
- **Test**: Session ID not used in DH/HKDF/AES operations

## Crash-Safety Analysis

| Crash Stage | State | Recovery |
|---|---|---|
| Before key generation | No change | Safe — no state modified |
| After key generation, before pending save | No change | Safe — keys in memory only |
| After pending save, before server publish | pending saved, main old | Resume: retry or rollback |
| During server publish | pending saved, main old | Resume: retry publish |
| After server publish, before main overwrite | pending saved, main old | Resume: commit pending |
| After main overwrite, before cleanup | pending saved, main new | Resume: cleanup |
| After cleanup | committed | No pending — nothing to do |

## Test Coverage

54 tests across 10 groups:
1. F-037: Trust State After Identity Rotation (8)
2. F-038: Crash-Safe Rotation Transaction (6)
3. F-039/F-040: SPK Rotation (10)
4. F-041: OTK Count Atomicity (3)
5. F-043: OTK Consumption (5)
6. F-045: Old Session Policy (4)
7. F-046: Session ID (3)
8. Restart / Crash Recovery (3)
9. Server Failure (3)
10. Rollback / Downgrade Resistance (3)
11. Adversarial Concurrency (3)
12. Downgrade Resistance (3)

## Regression

- Full suite: 1649 + 54 = 1703 tests
- Analyzer: 0 errors, 0 warnings on modified files
- No existing tests broken

## Protocol Migration

No protocol migration required. All fixes are implementation-level.

## Remaining Limitations

1. **OTK mutex is in-process only** — not cross-process (acceptable for single-device)
2. **Server SPK cleanup** — old SPKs remain on server during transition (by design)
3. **Session invalidation** — old sessions not automatically revoked (by design, documented)

## FINAL VERDICT

**PASS** — All HIGH and MEDIUM findings from 12D.7 are fixed and verified with adversarial tests.

## READY FOR NEXT PHASE

**YES**
