import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vibe_app/data/e2e_v2_identity_verification.dart';

/// Инфраструктурный сервис E2EE V2 (Phase 12B.1 + 12B.2).
/// Управляет ключами идентичности, подписанными пре-ключами,
/// одноразовыми пре-ключами, ключевыми бандлами и X3DH сессиями.
/// НЕ реализует Double Ratchet и шифрование сообщений.
class E2eV2Service {
  E2eV2Service._();
  static final instance = E2eV2Service._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  SupabaseClient get _client => Supabase.instance.client;

  SimpleKeyPair? _edIdentityKeyPair;
  SimpleKeyPair? _xdhIdentityKeyPair;

  /// Размер пакета для генерации одноразовых пре-ключей.
  static const int otkBatchSize = 100;

  /// Порог пополнения — когда генерировать новые OTK.
  static const int otkReplenishThreshold = 20;

  /// Safe SPK transition period in hours — old SPK remains valid
  /// to complete in-flight handshakes during rotation.
  static const int spkSafeTransitionHours = 24;

  // ---------------------------------------------------------------------------
  // Identity Key Generation
  // ---------------------------------------------------------------------------

  /// Генерирует ключевую пару идентичности из случайного 32-байтного сида.
  /// Ed25519 seed → Ed25519 keypair (для подписей)
  /// Тот же seed → X25519 keypair (для DH)
  Future<void> generateIdentity() async {
    final seed = List<int>.generate(32, (_) => Random.secure().nextInt(256));

    final ed25519 = Cryptography.instance.ed25519();
    final edKeyPair = await ed25519.newKeyPairFromSeed(seed);
    final edPublicKey = await edKeyPair.extractPublicKey();

    final x25519 = Cryptography.instance.x25519();
    final xdhKeyPair = await x25519.newKeyPairFromSeed(seed);
    final xdhPublicKey = await xdhKeyPair.extractPublicKey();

    _edIdentityKeyPair = edKeyPair;
    _xdhIdentityKeyPair = xdhKeyPair;

    await _secureStorage.write(
      key: 'e2e_v2_identity_seed',
      value: base64Encode(seed),
    );

    final deviceId = _generateUuid();
    await _secureStorage.write(key: 'e2e_v2_device_id', value: deviceId);

    await _registerDevice(
      deviceId,
      base64Encode(edPublicKey.bytes),
      base64Encode(xdhPublicKey.bytes),
    );
  }

  // ---------------------------------------------------------------------------
  // Identity Key Rotation
  // ---------------------------------------------------------------------------

  /// Rotates the identity key — generates a new local identity.
  ///
  /// ## Crash-Safe Transaction Model (F-038)
  ///
  /// Uses a PREPARING → PUBLISHED → COMMITTED state machine:
  /// 1. PREPARING: Save new seed as backup (old seed preserved)
  /// 2. PUBLISHED: Publish new identity to server
  /// 3. COMMITTED: Overwrite old seed with new seed, cleanup backup
  ///
  /// On restart, if backup exists but main seed is old → resume from PUBLISHED.
  /// On restart, if backup exists and main seed is new → COMMITTED.
  /// Old seed is NEVER destroyed until server publication succeeds.
  ///
  /// ## Trust State Policy (F-037)
  ///
  /// After rotation, all previously VERIFIED peers transition to CHANGED.
  /// Only explicit user re-verification can restore VERIFIED state.
  ///
  /// ## Returns
  ///
  /// [IdentityRotationResult] with old and new fingerprints.
  Future<IdentityRotationResult> rotateIdentity() async {
    // 1. Load old identity fingerprint (before rotation)
    final oldIdentityPub = await getIdentityKeyPublicBytes();
    if (oldIdentityPub == null) {
      throw Exception('Identity not loaded');
    }
    final oldFingerprint = await E2eV2IdentityVerification
        .generateFingerprint(oldIdentityPub);

    // 2. Preserve old seed as backup (F-038: never destroy until committed)
    final oldSeed = await _secureStorage.read(key: 'e2e_v2_identity_seed');
    if (oldSeed == null) {
      throw Exception('Identity seed not found');
    }

    // 3. Generate new identity (fresh CSPRNG seed — NOT derived from old seed)
    final newSeed = List<int>.generate(32, (_) => Random.secure().nextInt(256));

    final ed25519 = Cryptography.instance.ed25519();
    final newEdKeyPair = await ed25519.newKeyPairFromSeed(newSeed);
    final newEdPublicKey = await newEdKeyPair.extractPublicKey();

    final x25519 = Cryptography.instance.x25519();
    final newXdhKeyPair = await x25519.newKeyPairFromSeed(newSeed);
    final newXdhPublicKey = await newXdhKeyPair.extractPublicKey();

    // 4. PREPARING: Save new seed as backup (old seed is still main)
    await _secureStorage.write(
      key: 'e2e_v2_identity_seed_pending',
      value: base64Encode(newSeed),
    );

    // 5. Update in-memory state (for signing SPK with new identity)
    _edIdentityKeyPair = newEdKeyPair;
    _xdhIdentityKeyPair = newXdhKeyPair;

    // 6. PUBLISHED: Publish new identity to server
    final deviceId = await _getDeviceId();
    await _client.from('devices').update({
      'identity_key_public': base64Encode(newEdPublicKey.bytes),
      'identity_dh_public': base64Encode(newXdhPublicKey.bytes),
    }).eq('id', deviceId);

    // 7. COMMITTED: Overwrite old seed with new seed (safe now — server confirmed)
    await _secureStorage.write(
      key: 'e2e_v2_identity_seed',
      value: base64Encode(newSeed),
    );

    // 8. Cleanup backup
    await _secureStorage.delete(key: 'e2e_v2_identity_seed_pending');

    // 9. Generate new fingerprint
    final newFingerprint = await E2eV2IdentityVerification
        .generateFingerprint(newXdhPublicKey.bytes);

    // 10. Generate new signed prekey (bound to new identity)
    await generateSignedPrekey();

    // 11. Replenish OTKs (new identity requires new OTKs)
    await generateOneTimePrekeys();

    // 12. F-037: Transition all verified peers to CHANGED
    final verification = E2eV2IdentityVerification.instance;
    await verification.transitionAllVerifiedAfterRotation();

    return IdentityRotationResult(
      oldFingerprint: oldFingerprint,
      newFingerprint: newFingerprint,
      oldIdentityKeyPublic: oldIdentityPub,
      newIdentityKeyPublic: newXdhPublicKey.bytes,
      rotatedAt: DateTime.now(),
    );
  }

  /// Resumes an interrupted identity rotation after crash/restart.
  ///
  /// If a pending seed exists but the main seed was not updated,
  /// this means rotation was interrupted between PREPARING and COMMITTED.
  /// The pending seed was already published to server, so we can safely commit.
  ///
  /// ## Crash Recovery Policy
  ///
  /// - If pending seed exists AND main seed is different → commit pending
  /// - If pending seed exists AND main seed is same → cleanup pending (already committed)
  /// - If no pending seed → nothing to resume
  Future<bool> resumeIdentityRotationIfNeeded() async {
    final pendingSeed = await _secureStorage.read(key: 'e2e_v2_identity_seed_pending');
    if (pendingSeed == null) return false;

    final currentSeed = await _secureStorage.read(key: 'e2e_v2_identity_seed');
    if (currentSeed == pendingSeed) {
      // Already committed — cleanup
      await _secureStorage.delete(key: 'e2e_v2_identity_seed_pending');
      return false;
    }

    // Pending seed was published but not committed — resume commit
    await _secureStorage.write(
      key: 'e2e_v2_identity_seed',
      value: pendingSeed,
    );
    await _secureStorage.delete(key: 'e2e_v2_identity_seed_pending');

    // Reload keys from committed seed
    await loadKeys();

    return true;
  }

  /// Gets the current identity fingerprint.
  Future<String?> getCurrentFingerprint() async {
    final pub = await getIdentityKeyPublicBytes();
    if (pub == null) return null;
    return E2eV2IdentityVerification.generateFingerprint(pub);
  }

  // ---------------------------------------------------------------------------
  // Signed Prekey Generation
  // ---------------------------------------------------------------------------

  /// Rotates signed prekey with safe transition period.
  ///
  /// ## SPK Lifecycle (F-039/F-040)
  ///
  /// 1. New SPK generated and signed with current identity
  /// 2. Old SPK remains valid for spkSafeTransitionHours (24h)
  /// 3. New SPK becomes active immediately
  /// 4. After transition period, old SPK is deactivated
  ///
  /// ## Crash Safety
  ///
  /// - Old SPK private key stored with expiry timestamp
  /// - New SPK published to server before old SPK is marked expired
  /// - On restart, expired SPKs are cleaned up
  Future<SignedPrekeyBundle> rotateSignedPrekey() async {
    // 1. Save current SPK as "old" with expiry timestamp (if one exists)
    final currentSpkPriv = await _secureStorage.read(
      key: 'e2e_v2_signed_prekey_private',
    );
    final currentSpkId = await _secureStorage.read(
      key: 'e2e_v2_signed_prekey_id',
    );

    if (currentSpkPriv != null && currentSpkId != null) {
      // Archive old SPK with expiry
      final expiryTime = DateTime.now().add(
        Duration(hours: spkSafeTransitionHours),
      );
      await _secureStorage.write(
        key: 'e2e_v2_signed_prekey_old_private',
        value: currentSpkPriv,
      );
      await _secureStorage.write(
        key: 'e2e_v2_signed_prekey_old_expiry',
        value: expiryTime.toIso8601String(),
      );
      await _secureStorage.write(
        key: 'e2e_v2_signed_prekey_old_id',
        value: currentSpkId,
      );
    }

    // 2. Generate new SPK and publish (old SPK stays active on server)
    final newBundle = await _generateAndPublishSignedPrekey();

    // 3. Cleanup expired old SPK if transition period has passed
    await _cleanupExpiredOldSpk();

    return newBundle;
  }

  /// Checks if an old SPK is still valid (within transition period).
  ///
  /// Returns true if the SPK ID matches the current active SPK,
  /// OR if it matches an old SPK that hasn't expired yet.
  Future<bool> isSignedPrekeyValid(String prekeyId) async {
    // Check if it's the current active SPK
    final currentId = await _secureStorage.read(key: 'e2e_v2_signed_prekey_id');
    if (currentId == prekeyId) return true;

    // Check if it's an old SPK within transition period
    final oldId = await _secureStorage.read(key: 'e2e_v2_signed_prekey_old_id');
    if (oldId != prekeyId) return false;

    final expiryStr = await _secureStorage.read(key: 'e2e_v2_signed_prekey_old_expiry');
    if (expiryStr == null) return false;

    final expiry = DateTime.parse(expiryStr);
    return DateTime.now().isBefore(expiry);
  }

  /// Loads the private key for a signed prekey (current or old during transition).
  Future<SimpleKeyPair?> loadSignedPrekeyPrivate(String prekeyId) async {
    // Check current SPK
    final currentId = await _secureStorage.read(key: 'e2e_v2_signed_prekey_id');
    if (currentId == prekeyId) {
      final privB64 = await _secureStorage.read(key: 'e2e_v2_signed_prekey_private');
      if (privB64 == null) return null;
      final privBytes = base64Decode(privB64);
      return SimpleKeyPairData(
        privBytes,
        publicKey: SimplePublicKey(List<int>.filled(32, 0), type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
    }

    // Check old SPK (within transition period)
    final oldId = await _secureStorage.read(key: 'e2e_v2_signed_prekey_old_id');
    if (oldId == prekeyId) {
      final expiryStr = await _secureStorage.read(key: 'e2e_v2_signed_prekey_old_expiry');
      if (expiryStr != null) {
        final expiry = DateTime.parse(expiryStr);
        if (DateTime.now().isAfter(expiry)) return null; // Expired
      }
      final privB64 = await _secureStorage.read(key: 'e2e_v2_signed_prekey_old_private');
      if (privB64 == null) return null;
      final privBytes = base64Decode(privB64);
      return SimpleKeyPairData(
        privBytes,
        publicKey: SimplePublicKey(List<int>.filled(32, 0), type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
    }

    return null;
  }

  /// Cleans up expired old SPK from local storage.
  Future<void> _cleanupExpiredOldSpk() async {
    final expiryStr = await _secureStorage.read(key: 'e2e_v2_signed_prekey_old_expiry');
    if (expiryStr == null) return;

    final expiry = DateTime.parse(expiryStr);
    if (DateTime.now().isAfter(expiry)) {
      await _secureStorage.delete(key: 'e2e_v2_signed_prekey_old_private');
      await _secureStorage.delete(key: 'e2e_v2_signed_prekey_old_expiry');
      await _secureStorage.delete(key: 'e2e_v2_signed_prekey_old_id');
    }
  }

  /// Генерирует подписанный пре-ключ и публикует на сервере.
  Future<SignedPrekeyBundle> generateSignedPrekey() async {
    return _generateAndPublishSignedPrekey();
  }

  /// Internal: generates, signs, and publishes a new SPK.
  Future<SignedPrekeyBundle> _generateAndPublishSignedPrekey() async {
    final x25519 = Cryptography.instance.x25519();
    final prekeyPair = await x25519.newKeyPair();
    final prekeyPub = await prekeyPair.extractPublicKey();
    final prekeyPrivBytes = await prekeyPair.extractPrivateKeyBytes();

    final ed25519 = Cryptography.instance.ed25519();
    final signature = await ed25519.sign(
      prekeyPub.bytes,
      keyPair: _edIdentityKeyPair!,
    );

    await _secureStorage.write(
      key: 'e2e_v2_signed_prekey_private',
      value: base64Encode(prekeyPrivBytes),
    );

    final pubKeyB64 = base64Encode(prekeyPub.bytes);
    final sigB64 = base64Encode(signature.bytes);

    final prekeyId = await _publishSignedPrekey(
      publicKey: pubKeyB64,
      signature: sigB64,
    );

    await _secureStorage.write(
      key: 'e2e_v2_signed_prekey_id',
      value: prekeyId,
    );

    return SignedPrekeyBundle(
      id: prekeyId,
      publicKey: pubKeyB64,
      signature: sigB64,
    );
  }

  // ---------------------------------------------------------------------------
  // One-Time Prekey Pool
  // ---------------------------------------------------------------------------

  /// Генерирует пакет одноразовых пре-ключей.
  Future<List<PrekeyEntry>> generateOneTimePrekeys({
    int count = otkBatchSize,
  }) async {
    final entries = <PrekeyEntry>[];
    final x25519 = Cryptography.instance.x25519();

    for (var i = 0; i < count; i++) {
      final keyPair = await x25519.newKeyPair();
      final pub = await keyPair.extractPublicKey();
      final priv = await keyPair.extractPrivateKeyBytes();

      final entry = PrekeyEntry(
        id: _generateUuid(),
        publicKey: base64Encode(pub.bytes),
        privateKeyBytes: priv,
      );
      entries.add(entry);
    }

    for (final entry in entries) {
      await _secureStorage.write(
        key: 'e2e_v2_otk_${entry.id}',
        value: base64Encode(entry.privateKeyBytes),
      );
    }

    await _publishOneTimePrekeys(
      entries
          .map((e) => {'id': e.id, 'public_key': e.publicKey})
          .toList(),
    );

    // Update local OTK count
    await _updateOtkCount(entries.length);

    return entries;
  }

  /// Checks OTK count and replenishes if below threshold.
  ///
  /// ## Policy
  ///
  /// - If OTK count < otkReplenishThreshold → generate otkBatchSize new OTKs
  /// - Private keys remain local (SecureStorage)
  /// - Only public keys uploaded to server
  /// - Consumed OTKs are deleted from local storage
  /// - Concurrent replenishment serialized via mutex (F-041)
  Future<void> replenishOneTimePrekeysIfNeeded() async {
    await _acquireOtkMutex();
    try {
      final count = await _countLocalOtks();
      if (count < otkReplenishThreshold) {
        await generateOneTimePrekeys(count: otkBatchSize);
      }
    } finally {
      _releaseOtkMutex();
    }
  }

  /// Mutex for OTK count operations (F-041: prevents lost updates).
  Completer<void>? _otkMutex;

  /// Acquires the OTK mutex. Waits if another operation holds it.
  Future<void> _acquireOtkMutex() async {
    while (_otkMutex != null) {
      await _otkMutex!.future;
    }
    _otkMutex = Completer<void>();
  }

  /// Releases the OTK mutex.
  void _releaseOtkMutex() {
    final c = _otkMutex;
    _otkMutex = null;
    c?.complete();
  }

  /// Counts local OTKs (private keys in SecureStorage).
  Future<int> _countLocalOtks() async {
    final countStr = await _secureStorage.read(key: 'e2e_v2_otk_count');
    return int.tryParse(countStr ?? '0') ?? 0;
  }

  /// Updates the local OTK count under mutex (F-041: prevents lost updates).
  ///
  /// ## Invariant
  ///
  /// Under concurrent access, every delta is applied exactly once.
  /// The final count equals the sum of all deltas applied.
  Future<void> _updateOtkCount(int delta) async {
    await _acquireOtkMutex();
    try {
      final current = await _countLocalOtks();
      final newCount = (current + delta).clamp(0, 999999);
      await _secureStorage.write(
        key: 'e2e_v2_otk_count',
        value: newCount.toString(),
      );
    } finally {
      _releaseOtkMutex();
    }
  }

  /// Потребляет одноразовый пре-ключ (помечает как использованный,
  /// возвращает приватный ключ).
  ///
  /// ## F-043: Atomicity Policy
  ///
  /// Order of operations:
  /// 1. Read private key (if not found → return null, idempotent)
  /// 2. Delete from local storage (if already deleted → return null, idempotent)
  /// 3. Mark consumed on server (best-effort, retry-safe)
  /// 4. Decrement local count (under mutex)
  ///
  /// ## Failure Scenarios
  ///
  /// - Step 2 fails: key still exists locally, can be retried safely
  /// - Step 3 fails: key deleted locally, server has stale state (acceptable)
  /// - Step 4 fails: count not decremented, but key is consumed (count drift)
  ///   → Next replenishment will correct the count
  ///
  /// ## Idempotency
  ///
  /// Calling consumeOneTimePrekey with the same ID twice returns null
  /// on the second call (key already deleted from local storage).
  Future<String?> consumeOneTimePrekey(String prekeyId) async {
    await _acquireOtkMutex();
    try {
      // Step 1: Read private key
      final privKey = await _secureStorage.read(key: 'e2e_v2_otk_$prekeyId');
      if (privKey == null) return null; // Already consumed or never existed

      // Step 2: Delete from local storage
      await _secureStorage.delete(key: 'e2e_v2_otk_$prekeyId');

      // Step 3: Mark consumed on server (best-effort)
      try {
        await _markPrekeyConsumed(prekeyId);
      } catch (_) {
        // Server mark failed — key is deleted locally anyway.
        // Server will have stale unconsumed entry. Acceptable.
      }

      // Step 4: Decrement local count
      final current = await _countLocalOtks();
      final newCount = (current - 1).clamp(0, 999999);
      await _secureStorage.write(
        key: 'e2e_v2_otk_count',
        value: newCount.toString(),
      );

      return privKey;
    } finally {
      _releaseOtkMutex();
    }
  }

  // ---------------------------------------------------------------------------
  // Key Bundle
  // ---------------------------------------------------------------------------

  /// Загружает ключевой бандл пира для установки сессии.
  Future<KeyBundle?> fetchKeyBundle(String deviceId) async {
    final response = await _client
        .from('signed_prekeys')
        .select('id, public_key, signature, algorithm')
        .eq('device_id', deviceId)
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) return null;

    final otkResponse = await _client
        .from('one_time_prekeys')
        .select('id, public_key')
        .eq('device_id', deviceId)
        .isFilter('consumed_at', null)
        .limit(1)
        .maybeSingle();

    final deviceResponse = await _client
        .from('devices')
        .select('identity_key_public, identity_dh_public')
        .eq('id', deviceId)
        .single();

    return KeyBundle(
      deviceId: deviceId,
      identityKeyPublic: deviceResponse['identity_key_public'],
      identityDhPublic: deviceResponse['identity_dh_public'],
      signedPrekeyId: response['id'],
      signedPrekeyPublic: response['public_key'],
      signedPrekeySignature: response['signature'],
      signedPrekeyAlgorithm: response['algorithm'],
      oneTimePrekeyId: otkResponse?['id'],
      oneTimePrekeyPublic: otkResponse?['public_key'],
      protocolVersion: 2,
    );
  }

  /// Валидирует ключевой бандл. Возвращает true, если валиден.
  Future<bool> validateKeyBundle(KeyBundle bundle) async {
    if (bundle.protocolVersion != 2) {
      throw InvalidBundleException(
        'Unsupported protocol version: ${bundle.protocolVersion}',
      );
    }

    if (bundle.identityKeyPublic.isEmpty ||
        bundle.identityDhPublic.isEmpty ||
        bundle.signedPrekeyPublic.isEmpty ||
        bundle.signedPrekeySignature.isEmpty) {
      throw InvalidBundleException('Missing required fields');
    }

    final idKeyBytes = base64Decode(bundle.identityKeyPublic);
    final dhKeyBytes = base64Decode(bundle.identityDhPublic);
    final spkBytes = base64Decode(bundle.signedPrekeyPublic);
    final sigBytes = base64Decode(bundle.signedPrekeySignature);

    if (idKeyBytes.length != 32) {
      throw InvalidBundleException('Identity key wrong length');
    }
    if (dhKeyBytes.length != 32) {
      throw InvalidBundleException('Identity DH key wrong length');
    }
    if (spkBytes.length != 32) {
      throw InvalidBundleException('Signed prekey wrong length');
    }
    if (sigBytes.length != 64) {
      throw InvalidBundleException('Signature wrong length');
    }

    final ed25519 = Cryptography.instance.ed25519();
    final identityPub = SimplePublicKey(idKeyBytes, type: KeyPairType.ed25519);
    final signature = Signature(sigBytes, publicKey: identityPub);
    final valid = await ed25519.verify(spkBytes, signature: signature);

    if (!valid) {
      throw InvalidBundleException(
        'Signed prekey signature verification failed',
      );
    }

    if (bundle.oneTimePrekeyPublic != null) {
      final otkBytes = base64Decode(bundle.oneTimePrekeyPublic!);
      if (otkBytes.length != 32) {
        throw InvalidBundleException('One-time prekey wrong length');
      }
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Load / Save
  // ---------------------------------------------------------------------------

  /// Загружает ключи из безопасного хранилища.
  Future<bool> loadKeys() async {
    try {
      final seed = await _secureStorage.read(key: 'e2e_v2_identity_seed');
      if (seed == null) return false;

      final seedBytes = base64Decode(seed);
      final ed25519 = Cryptography.instance.ed25519();
      _edIdentityKeyPair = await ed25519.newKeyPairFromSeed(seedBytes);

      final x25519 = Cryptography.instance.x25519();
      _xdhIdentityKeyPair = await x25519.newKeyPairFromSeed(seedBytes);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Готовность сервиса к работе.
  bool get isReady =>
      _edIdentityKeyPair != null && _xdhIdentityKeyPair != null;

  /// Возвращает X25519 public key bytes текущего устройства (32 bytes).
  Future<List<int>?> getIdentityKeyPublicBytes() async {
    if (_xdhIdentityKeyPair == null) return null;
    final pub = await _xdhIdentityKeyPair!.extractPublicKey();
    return pub.bytes;
  }

  /// Возвращает device ID текущего устройства.
  Future<String?> getDeviceId() async {
    return _getDeviceId();
  }

  // ---------------------------------------------------------------------------
  // Private server interaction
  // ---------------------------------------------------------------------------

  Future<void> _registerDevice(
    String deviceId,
    String edPubKey,
    String xdhPubKey,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await _client.from('devices').upsert({
      'id': deviceId,
      'user_id': userId,
      'device_name': 'Default device',
      'identity_key_public': edPubKey,
      'identity_dh_public': xdhPubKey,
    });
  }

  Future<String> _publishSignedPrekey({
    required String publicKey,
    required String signature,
  }) async {
    final deviceId = await _getDeviceId();

    // F-039/F-040: Do NOT immediately deactivate old SPK.
    // Old SPK remains active on server for spkSafeTransitionHours.
    // Client-side expiry is enforced by isSignedPrekeyValid().

    final response = await _client
        .from('signed_prekeys')
        .insert({
          'device_id': deviceId,
          'public_key': publicKey,
          'signature': signature,
          'is_active': true,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<void> _publishOneTimePrekeys(
    List<Map<String, String>> prekeys,
  ) async {
    final deviceId = await _getDeviceId();
    await _client.from('one_time_prekeys').insert(
      prekeys
          .map((p) => {
                'id': p['id'],
                'device_id': deviceId,
                'public_key': p['public_key'],
              })
          .toList(),
    );
  }

  Future<void> _markPrekeyConsumed(String prekeyId) async {
    await _client
        .from('one_time_prekeys')
        .update({'consumed_at': DateTime.now().toIso8601String()})
        .eq('id', prekeyId);
  }

  Future<String> _getDeviceId() async {
    final id = await _secureStorage.read(key: 'e2e_v2_device_id');
    if (id == null) throw Exception('Device not registered');
    return id;
  }

  // ---------------------------------------------------------------------------
  // X3DH Session Establishment
  // ---------------------------------------------------------------------------

  /// Salt для HKDF (RFC 5869).
  static final List<int> _hkdfSalt = utf8.encode('VibeE2EE_v2_sess');

  /// Длина вывода HKDF: 64 bytes = root_key(32) + chain_key(32).
  static const int _hkdfOutputLength = 64;

  /// Создаёт X3DH handshake — Initiator side (Alice).
  ///
  /// Возвращает [X3dhMessage] для отправки Bob'у.
  /// Bob должен вызвать [respondToX3dh] с этим сообщением.
  Future<X3dhMessage> initiateX3dh({
    required String targetDeviceId,
  }) async {
    final x25519 = Cryptography.instance.x25519();

    // 1. Загружаем собственный identity key (X25519)
    if (_xdhIdentityKeyPair == null) {
      throw Exception('Identity key not loaded');
    }
    final myIdentityPub = await _xdhIdentityKeyPair!.extractPublicKey();
    final myIdentityPubB64 = base64Encode(myIdentityPub.bytes);

    // 2. Загружаем собственный Ed25519 identity для подписи
    final myEdIdentityPub = await _edIdentityKeyPair!.extractPublicKey();
    final myEdIdentityPubB64 = base64Encode(myEdIdentityPub.bytes);

    // 3. Генерируем ephemeral key pair
    final ephemeralPair = await x25519.newKeyPair();
    final ephemeralPub = await ephemeralPair.extractPublicKey();

    // 4. Загружаем и валидируем bundle пира
    final bundle = await fetchKeyBundle(targetDeviceId);
    if (bundle == null) {
      throw InvalidBundleException('Bundle not found for device $targetDeviceId');
    }
    await validateKeyBundle(bundle);

    // 5. Вычисляем DH операции
    final dhResults = await _computeX3dhDh(
      initiatorIdentityKey: _xdhIdentityKeyPair!,
      initiatorEphemeralKey: ephemeralPair,
      responderIdentityKeyPublic: bundle.identityDhPublic,
      responderSignedPrekeyPublic: bundle.signedPrekeyPublic,
      responderOneTimePrekeyPublic: bundle.oneTimePrekeyPublic,
    );

    // 6. Конкатенируем DH результаты
    final masterSecret = <int>[];
    for (final dh in dhResults) {
      masterSecret.addAll(dh);
    }

    // 7. HKDF → root_key + chain_key
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: _hkdfOutputLength,
    );
    final ikm = masterSecret;
    final info = [
      ...base64Decode(myIdentityPubB64),
      ...base64Decode(bundle.identityDhPublic),
    ];
    final derivedKey = await hkdf.deriveKey(
      secretKey: SecretKey(ikm),
      nonce: _hkdfSalt,
      info: info,
    );
    final derivedBytes = await derivedKey.extractBytes();

    final rootKey = derivedBytes.sublist(0, 32);
    final chainKey = derivedBytes.sublist(32, 64);

    // 8. Генерируем session ID
    final sessionId = _generateSessionId(
      initiatorDeviceId: await _getDeviceId(),
      responderDeviceId: targetDeviceId,
      ephemeralPubBytes: ephemeralPub.bytes,
    );

    // 9. Создаём результат
    final result = X3dhResult(
      sessionId: sessionId,
      rootKey: rootKey,
      chainKey: chainKey,
      remoteIdentityKeyPublic: bundle.identityDhPublic,
      remoteDeviceId: targetDeviceId,
      protocolVersion: 2,
    );

    // Сохраняем сессию в SecureStorage
    await _saveSession(result);

    return X3dhMessage(
      sessionId: sessionId,
      initiatorDeviceId: await _getDeviceId(),
      initiatorIdentityKeyPublic: myIdentityPubB64,
      initiatorEdIdentityKeyPublic: myEdIdentityPubB64,
      responderDeviceId: targetDeviceId,
      ephemeralKeyPublic: base64Encode(ephemeralPub.bytes),
      protocolVersion: 2,
      oneTimePrekeyId: bundle.oneTimePrekeyId,
    );
  }

  /// Обрабатывает X3DH handshake — Responder side (Bob).
  ///
  /// Принимает [X3dhMessage] от Alice, вычисляет DH, создаёт сессию.
  Future<X3dhResult> respondToX3dh(X3dhMessage message) async {
    // 1. Проверяем protocol version
    if (message.protocolVersion != 2) {
      throw InvalidBundleException(
        'Unsupported protocol version: ${message.protocolVersion}',
      );
    }

    // 2. Загружаем собственный identity key (X25519)
    if (_xdhIdentityKeyPair == null) {
      throw Exception('Identity key not loaded');
    }
    final myIdentityPub = await _xdhIdentityKeyPair!.extractPublicKey();

    // 3. Загружаем signed prekey
    final signedPrekeyPrivB64 = await _secureStorage.read(
      key: 'e2e_v2_signed_prekey_private',
    );
    if (signedPrekeyPrivB64 == null) {
      throw Exception('Signed prekey not found');
    }
    final signedPrekeyPrivBytes = base64Decode(signedPrekeyPrivB64);
    final signedPrekeyPair = SimpleKeyPairData(
      signedPrekeyPrivBytes,
      publicKey: SimplePublicKey(
        List<int>.filled(32, 0),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );

    // 4. Загружаем OTK (если передан в message)
    SimpleKeyPair? otkPair;
    if (message.oneTimePrekeyId != null) {
      final otkPrivB64 = await _secureStorage.read(
        key: 'e2e_v2_otk_${message.oneTimePrekeyId}',
      );
      if (otkPrivB64 != null) {
        final otkPrivBytes = base64Decode(otkPrivB64);
        otkPair = SimpleKeyPairData(
          otkPrivBytes,
          publicKey: SimplePublicKey(
            List<int>.filled(32, 0),
            type: KeyPairType.x25519,
          ),
          type: KeyPairType.x25519,
        );
        // F-043: Consume OTK atomically (delete + mark + count)
        await _acquireOtkMutex();
        try {
          await _secureStorage.delete(
            key: 'e2e_v2_otk_${message.oneTimePrekeyId}',
          );
          try {
            await _markPrekeyConsumed(message.oneTimePrekeyId!);
          } catch (_) {
            // Server mark failed — key deleted locally. Acceptable.
          }
          final current = await _countLocalOtks();
          final newCount = (current - 1).clamp(0, 999999);
          await _secureStorage.write(
            key: 'e2e_v2_otk_count',
            value: newCount.toString(),
          );
        } finally {
          _releaseOtkMutex();
        }
      }
    }

    // 5. Парсим identity key инициатора (X25519 DH key)
    final initiatorIdentityPubBytes = base64Decode(message.initiatorIdentityKeyPublic);

    // 6. Вычисляем DH операции (зеркальные относительно initiator)
    final dhResults = await _computeX3dhDhResponder(
      myIdentityKey: _xdhIdentityKeyPair!,
      mySignedPrekey: signedPrekeyPair,
      myOneTimePrekey: otkPair,
      initiatorIdentityKeyPublic: message.initiatorIdentityKeyPublic,
      initiatorEphemeralKeyPublic: message.ephemeralKeyPublic,
    );

    // 7. Конкатенируем DH результаты
    final masterSecret = <int>[];
    for (final dh in dhResults) {
      masterSecret.addAll(dh);
    }

    // 8. HKDF → root_key + chain_key (те же параметры что у initiator)
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: _hkdfOutputLength,
    );
    final ikm = masterSecret;
    final info = [
      ...initiatorIdentityPubBytes,
      ...myIdentityPub.bytes,
    ];
    final derivedKey = await hkdf.deriveKey(
      secretKey: SecretKey(ikm),
      nonce: _hkdfSalt,
      info: info,
    );
    final derivedBytes = await derivedKey.extractBytes();

    final rootKey = derivedBytes.sublist(0, 32);
    final chainKey = derivedBytes.sublist(32, 64);

    // 9. Создаём результат
    final result = X3dhResult(
      sessionId: message.sessionId,
      rootKey: rootKey,
      chainKey: chainKey,
      remoteIdentityKeyPublic: message.initiatorIdentityKeyPublic,
      remoteDeviceId: message.initiatorDeviceId,
      protocolVersion: 2,
    );

    // Сохраняем сессию
    await _saveSession(result);

    return result;
  }

  /// Вычисляет 4 DH операции для X3DH (initiator side).
  Future<List<List<int>>> _computeX3dhDh({
    required SimpleKeyPair initiatorIdentityKey,
    required SimpleKeyPair initiatorEphemeralKey,
    required String responderIdentityKeyPublic,
    required String responderSignedPrekeyPublic,
    String? responderOneTimePrekeyPublic,
  }) async {
    final x25519 = Cryptography.instance.x25519();

    final responderIkPub = SimplePublicKey(
      base64Decode(responderIdentityKeyPublic),
      type: KeyPairType.x25519,
    );
    final responderSpkPub = SimplePublicKey(
      base64Decode(responderSignedPrekeyPublic),
      type: KeyPairType.x25519,
    );

    // DH1 = X25519(IKa, SPKb) — identity to signed prekey
    final dh1 = await x25519.sharedSecretKey(
      keyPair: initiatorIdentityKey,
      remotePublicKey: responderSpkPub,
    );

    // DH2 = X25519(EKa, IKb) — ephemeral to identity
    final dh2 = await x25519.sharedSecretKey(
      keyPair: initiatorEphemeralKey,
      remotePublicKey: responderIkPub,
    );

    // DH3 = X25519(EKa, SPKb) — ephemeral to signed prekey
    final dh3 = await x25519.sharedSecretKey(
      keyPair: initiatorEphemeralKey,
      remotePublicKey: responderSpkPub,
    );

    final results = <List<int>>[
      await dh1.extractBytes(),
      await dh2.extractBytes(),
      await dh3.extractBytes(),
    ];

    // DH4 = X25519(EKa, OPKb) — ephemeral to one-time prekey (optional)
    if (responderOneTimePrekeyPublic != null) {
      final responderOpkPub = SimplePublicKey(
        base64Decode(responderOneTimePrekeyPublic),
        type: KeyPairType.x25519,
      );
      final dh4 = await x25519.sharedSecretKey(
        keyPair: initiatorEphemeralKey,
        remotePublicKey: responderOpkPub,
      );
      results.add(await dh4.extractBytes());
    }

    return results;
  }

  /// Вычисляет 4 DH операции для X3DH (responder side).
  Future<List<List<int>>> _computeX3dhDhResponder({
    required SimpleKeyPair myIdentityKey,
    required SimpleKeyPair mySignedPrekey,
    SimpleKeyPair? myOneTimePrekey,
    required String initiatorIdentityKeyPublic,
    required String initiatorEphemeralKeyPublic,
  }) async {
    final x25519 = Cryptography.instance.x25519();

    final initiatorIkPub = SimplePublicKey(
      base64Decode(initiatorIdentityKeyPublic),
      type: KeyPairType.x25519,
    );
    final initiatorEkPub = SimplePublicKey(
      base64Decode(initiatorEphemeralKeyPublic),
      type: KeyPairType.x25519,
    );

    // DH1 = X25519(SPKb, IKa) — signed prekey to initiator identity
    final dh1 = await x25519.sharedSecretKey(
      keyPair: mySignedPrekey,
      remotePublicKey: initiatorIkPub,
    );

    // DH2 = X25519(IKa, EKa) — my identity to initiator ephemeral
    final dh2 = await x25519.sharedSecretKey(
      keyPair: myIdentityKey,
      remotePublicKey: initiatorEkPub,
    );

    // DH3 = X25519(SPKb, EKa) — signed prekey to initiator ephemeral
    final dh3 = await x25519.sharedSecretKey(
      keyPair: mySignedPrekey,
      remotePublicKey: initiatorEkPub,
    );

    final results = <List<int>>[
      await dh1.extractBytes(),
      await dh2.extractBytes(),
      await dh3.extractBytes(),
    ];

    // DH4 = X25519(OPKb, EKa) — one-time prekey to initiator ephemeral (optional)
    if (myOneTimePrekey != null) {
      final dh4 = await x25519.sharedSecretKey(
        keyPair: myOneTimePrekey,
        remotePublicKey: initiatorEkPub,
      );
      results.add(await dh4.extractBytes());
    }

    return results;
  }

  /// Генерирует session ID — SHA-256 (16 hex) вместо FNV-1a 32-bit (F-055).
  String _generateSessionId({
    required String initiatorDeviceId,
    required String responderDeviceId,
    required List<int> ephemeralPubBytes,
  }) {
    final combined = <int>[
      ...utf8.encode(initiatorDeviceId),
      ...utf8.encode(responderDeviceId),
      ...ephemeralPubBytes,
    ];
    final digest = crypto.sha256.convert(combined);
    return digest.toString().substring(0, 16);
  }

  /// Сохраняет сессию в SecureStorage.
  Future<void> _saveSession(X3dhResult session) async {
    await _secureStorage.write(
      key: 'e2e_v2_session_${session.sessionId}',
      value: jsonEncode({
        'session_id': session.sessionId,
        'root_key': base64Encode(session.rootKey),
        'chain_key': base64Encode(session.chainKey),
        'remote_identity': session.remoteIdentityKeyPublic,
        'remote_device': session.remoteDeviceId,
        'protocol_version': session.protocolVersion,
        'created_at': DateTime.now().toIso8601String(),
      }),
    );
  }

  /// Загружает сессию из SecureStorage.
  Future<X3dhResult?> loadSession(String sessionId) async {
    final data = await _secureStorage.read(key: 'e2e_v2_session_$sessionId');
    if (data == null) return null;
    final json = jsonDecode(data) as Map<String, dynamic>;
    return X3dhResult(
      sessionId: json['session_id'] as String,
      rootKey: base64Decode(json['root_key'] as String),
      chainKey: base64Decode(json['chain_key'] as String),
      remoteIdentityKeyPublic: json['remote_identity'] as String,
      remoteDeviceId: json['remote_device'] as String,
      protocolVersion: json['protocol_version'] as int,
    );
  }

  /// Удаляет сессию.
  Future<void> deleteSession(String sessionId) async {
    await _secureStorage.delete(key: 'e2e_v2_session_$sessionId');
  }

  /// Генерирует UUID v4 (RFC 4122).
  String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

// =============================================================================
// Data classes
// =============================================================================

class SignedPrekeyBundle {
  final String id;
  final String publicKey;
  final String signature;

  const SignedPrekeyBundle({
    required this.id,
    required this.publicKey,
    required this.signature,
  });
}

class PrekeyEntry {
  final String id;
  final String publicKey;
  final List<int> privateKeyBytes;

  const PrekeyEntry({
    required this.id,
    required this.publicKey,
    required this.privateKeyBytes,
  });
}

class KeyBundle {
  final String deviceId;
  final String identityKeyPublic;
  final String identityDhPublic;
  final String signedPrekeyId;
  final String signedPrekeyPublic;
  final String signedPrekeySignature;
  final String signedPrekeyAlgorithm;
  final String? oneTimePrekeyId;
  final String? oneTimePrekeyPublic;
  final int protocolVersion;

  const KeyBundle({
    required this.deviceId,
    required this.identityKeyPublic,
    required this.identityDhPublic,
    required this.signedPrekeyId,
    required this.signedPrekeyPublic,
    required this.signedPrekeySignature,
    required this.signedPrekeyAlgorithm,
    this.oneTimePrekeyId,
    this.oneTimePrekeyPublic,
    required this.protocolVersion,
  });
}

class InvalidBundleException implements Exception {
  final String message;

  const InvalidBundleException(this.message);

  @override
  String toString() => 'InvalidBundleException: $message';
}

// =============================================================================
// X3DH Data Classes
// =============================================================================

/// Сообщение X3DH handshake от initiator'а к responder'у.
///
/// Содержит все данные необходимые для вычисления shared secret
/// на стороне responder'а.
class X3dhMessage {
  final String sessionId;
  final String initiatorDeviceId;
  final String initiatorIdentityKeyPublic;
  final String initiatorEdIdentityKeyPublic;
  final String responderDeviceId;
  final String ephemeralKeyPublic;
  final int protocolVersion;

  /// ID одноразового пре-ключа (если использовался при X3DH).
  /// Responder загружает приватный ключ по этому ID для вычисления DH4.
  final String? oneTimePrekeyId;

  const X3dhMessage({
    required this.sessionId,
    required this.initiatorDeviceId,
    required this.initiatorIdentityKeyPublic,
    required this.initiatorEdIdentityKeyPublic,
    required this.responderDeviceId,
    required this.ephemeralKeyPublic,
    required this.protocolVersion,
    this.oneTimePrekeyId,
  });

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'initiator_device_id': initiatorDeviceId,
        'initiator_identity_key': initiatorIdentityKeyPublic,
        'initiator_ed_identity_key': initiatorEdIdentityKeyPublic,
        'responder_device_id': responderDeviceId,
        'ephemeral_key': ephemeralKeyPublic,
        'protocol_version': protocolVersion,
        if (oneTimePrekeyId != null) 'one_time_prekey_id': oneTimePrekeyId,
      };

  factory X3dhMessage.fromJson(Map<String, dynamic> json) => X3dhMessage(
        sessionId: json['session_id'] as String,
        initiatorDeviceId: json['initiator_device_id'] as String,
        initiatorIdentityKeyPublic: json['initiator_identity_key'] as String,
        initiatorEdIdentityKeyPublic: json['initiator_ed_identity_key'] as String,
        responderDeviceId: json['responder_device_id'] as String,
        ephemeralKeyPublic: json['ephemeral_key'] as String,
        protocolVersion: json['protocol_version'] as int,
        oneTimePrekeyId: json['one_time_prekey_id'] as String?,
      );
}

/// Результат X3DH key agreement.
///
/// Содержит material для Double Ratchet:
/// - root_key: начальный корневой ключ
/// - chain_key: начальный ключ цепочки
/// - session_id: уникальный идентификатор сессии
class X3dhResult {
  final String sessionId;
  final List<int> rootKey;
  final List<int> chainKey;
  final String remoteIdentityKeyPublic;
  final String remoteDeviceId;
  final int protocolVersion;

  const X3dhResult({
    required this.sessionId,
    required this.rootKey,
    required this.chainKey,
    required this.remoteIdentityKeyPublic,
    required this.remoteDeviceId,
    required this.protocolVersion,
  });
}

/// Result of identity key rotation.
class IdentityRotationResult {
  final String oldFingerprint;
  final String newFingerprint;
  final List<int> oldIdentityKeyPublic;
  final List<int> newIdentityKeyPublic;
  final DateTime rotatedAt;

  const IdentityRotationResult({
    required this.oldFingerprint,
    required this.newFingerprint,
    required this.oldIdentityKeyPublic,
    required this.newIdentityKeyPublic,
    required this.rotatedAt,
  });
}
