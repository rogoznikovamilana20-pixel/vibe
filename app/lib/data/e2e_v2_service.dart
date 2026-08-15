import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Инфраструктурный сервис E2EE V2 (Phase 12B.1).
/// Управляет ключами идентичности, подписанными пре-ключами,
/// одноразовыми пре-ключами и ключевыми бандлами.
/// НЕ реализует Double Ratchet и шифрование сообщений.
class E2eV2Service {
  E2eV2Service._();
  static final instance = E2eV2Service._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SupabaseClient get _client => Supabase.instance.client;

  SimpleKeyPair? _edIdentityKeyPair;
  SimpleKeyPair? _xdhIdentityKeyPair;

  /// Размер пакета для генерации одноразовых пре-ключей.
  static const int otkBatchSize = 100;

  /// Порог пополнения — когда генерировать новые OTK.
  static const int otkReplenishThreshold = 20;

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
  // Signed Prekey Generation
  // ---------------------------------------------------------------------------

  /// Генерирует подписанный пре-ключ и подписывает его ключом идентичности.
  Future<SignedPrekeyBundle> generateSignedPrekey() async {
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

    return entries;
  }

  /// Потребляет одноразовый пре-ключ (помечает как использованный,
  /// возвращает приватный ключ).
  Future<String?> consumeOneTimePrekey(String prekeyId) async {
    final privKey = await _secureStorage.read(key: 'e2e_v2_otk_$prekeyId');
    if (privKey == null) return null;

    await _secureStorage.delete(key: 'e2e_v2_otk_$prekeyId');
    await _markPrekeyConsumed(prekeyId);

    return privKey;
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

    await _client
        .from('signed_prekeys')
        .update({'is_active': false})
        .eq('device_id', deviceId)
        .eq('is_active', true);

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
  // Helpers
  // ---------------------------------------------------------------------------

  String _generateUuid() {
    final rng = Random.secure();
    final values = List<int>.generate(16, (_) => rng.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40;
    values[8] = (values[8] & 0x3f) | 0x80;
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
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
