# Phase 12D.6 — Identity & Key Lifecycle Hardening

**Date**: 2026-08-16
**Status**: PASS
**Tests**: 55/55 PASS
**Base**: 1552 tests passing (12E.5 regression)
**Commit**: bf82104 (12E.5 base)

## Objective

Harden V2 identity key lifecycle: rotation, trust transitions, SPK/OTK management, fingerprint change detection, server substitution resistance, post-compromise recovery.

## Key Design Decisions

### Identity Rotation
- **New seed via CSPRNG** — old private key is NOT sent to server
- Trust becomes `CHANGED` — explicit re-verification required
- Old sessions remain functional with old root key
- New SPK + OTKs generated after rotation

### SPK Rotation
- Old SPK remains valid for 24h transition period (`spkSafeTransitionHours`)
- Prevents in-flight messages from failing during rotation
- After transition, old SPK is discarded

### OTK Replenishment
- Low-watermark model: threshold=20, batch=100
- Local count tracking via `e2e_v2_otk_count` in SecureStorage
- `replenishOneTimePrekeysIfNeeded()` checks count before accepting new X3DH sessions

### Trust State Machine
```
UNKNOWN → VERIFIED (explicit verification)
VERIFIED → CHANGED (on key change)
CHANGED → VERIFIED (explicit re-verification required)
```

## Security Properties Verified

| ID | Property | Status |
|---|---|---|
| IG1-5 | Identity key generation determinism, size, uniqueness | PASS |
| TS1-7 | Trust state transitions, no auto-escalation, re-verification required | PASS |
| FP1-4 | Fingerprint determinism, uniqueness, format (60 digits), rotation detection | PASS |
| KD1-4 | Key change detection, first contact, unchanged/changed paths | PASS |
| SS1-3 | Server cannot force trust, forge signatures, replay old bundles | PASS |
| OR1-2 | Old identity cannot decrypt new messages or accept old fingerprints | PASS |
| IR1-2 | Rollback detected via fingerprint change, trust not auto-restored | PASS |
| SPK1-5 | SPK signature validity, wrong identity rejection, tamper detection, sizes | PASS |
| OTK1-4 | OTK randomness, uniqueness, shared secret computation, single-use | PASS |
| KB1-4 | Key bundle size validation, signature consistency detection | PASS |
| PCR1-3 | Post-compromise recovery via rotation, new session requirement, re-verification | PASS |
| MI1-3 | Media remains decryptable after rotation, AAD binds new identity | PASS |
| DR1-3 | No downgrade path, rotation preserves security | PASS |
| FC1-4 | Fail-closed on missing keys, invalid bundles, signature failures, key changes | PASS |
| C1-2 | Concurrent fingerprint/trust operations are consistent | PASS |

## Implementation Changes

### `e2e_v2_service.dart`
- Added `rotateIdentity()` — generates new Ed25519 + X25519 key pairs, rotates SPK, generates new OTKs
- Added `IdentityRotationResult` class (newIdentityKey, newFingerprint, oldTrustState, newTrustState)
- Added `rotateSignedPrekey()` — generates new SPK with 24h safe transition
- Added `replenishOneTimePrekeysIfNeeded()` — checks local count, generates batch if below threshold
- Added `_countLocalOtks()` — counts OTKs in SecureStorage
- Added `_updateOtkCount()` — persists OTK count to `e2e_v2_otk_count`
- Added `getCurrentFingerprint()` — returns current identity fingerprint
- Added `spkSafeTransitionHours = 24` constant
- Import added for `e2e_v2_identity_verification.dart`

## Test Coverage

55 tests across 15 groups:
1. Identity Generation (5)
2. Trust State Transitions (7)
3. Fingerprint Changes (4)
4. Key Change Detection (4)
5. Server Substitution Resistance (3)
6. Old Identity Replay (2)
7. Identity Rollback (2)
8. SPK Security (5)
9. OTK Security (4)
10. Key Bundle Consistency (4)
11. Post-Compromise Recovery (3)
12. Media Interaction (3)
13. Downgrade Resistance (3)
14. Fail-Closed Behavior (4)
15. Concurrency (2)

## Regression

- Full suite: 1552 + 55 = 1607 tests
- Analyzer: 0 errors, 0 warnings
- No V2 text E2EE, X3DH, Double Ratchet, or V1 breakage

## Known Limitations

1. **FNV-1a hash** (F-003, LOW) — not collision-resistant; adequate for integrity but not proof-of-work
2. **chatId not in media AAD** (F-004, DEFENSE-IN-DEPTH) — cross-chat media forgery possible if storage is compromised
3. **No identity/SPK rotation scheduling** (F-005, LOW) — rotation is manual; no automatic periodic rotation

## Verdict

**PASS** — Identity rotation, trust transitions, SPK/OTK lifecycle, and post-compromise recovery all work correctly. Trust state machine enforces explicit re-verification. Server substitution and identity replay are cryptographically prevented.
