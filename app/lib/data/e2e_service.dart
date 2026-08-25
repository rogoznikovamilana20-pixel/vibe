import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// E2E шифрование для сообщений Vibe.
///
/// Алгоритмы:
/// - Обмен ключами: X25519 (ECDH)
/// - Шифрование: AES-256-GCM
/// - Хранение: приватный ключ в SecureStorage, публичный — на сервере.
class E2eService {
  E2eService._();
  static final instance = E2eService._();

  final _client = Supabase.instance.client;
  final _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  final _keyExchange = Cryptography.instance.x25519();
  final _aesGcm = Cryptography.instance.aesGcm();

  SimplePublicKey? _publicKey;
  SimpleKeyPair? _keyPair;

  SimplePublicKey? get publicKey => _publicKey;

  // ── Key Generation ──────────────────────────────────────────

  /// Генерирует пару ключей и сохраняет приватный в SecureStorage,
  /// публичный — в profiles.e2e_public_key.
  Future<void> generateAndStoreKeys() async {
    _keyPair = await _keyExchange.newKeyPair();
    final pubKey = await _keyPair!.extractPublicKey();
    _publicKey = pubKey;

    // Приватный ключ → SecureStorage
    final privKeyBytes = await _keyPair!.extractPrivateKeyBytes();
    await _secureStorage.write(
      key: 'e2e_private_key',
      value: base64Encode(privKeyBytes),
    );

    // Публичный ключ → SecureStorage (для offline загрузки)
    await _secureStorage.write(
      key: 'e2e_public_key',
      value: base64Encode(pubKey.bytes),
    );

    // Публичный ключ → Supabase
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      await _client.from('profiles').update({
        'e2e_public_key': base64Encode(pubKey.bytes),
      }).eq('id', userId);
    }
  }

  /// Загружает ключи из хранилища (при старте приложения).
  Future<bool> loadKeys() async {
    try {
      final privKeyB64 = await _secureStorage.read(key: 'e2e_private_key');
      final pubKeyB64 = await _secureStorage.read(key: 'e2e_public_key');
      if (privKeyB64 == null || pubKeyB64 == null) return false;

      final privKeyBytes = base64Decode(privKeyB64);
      final pubKeyBytes = base64Decode(pubKeyB64);
      _publicKey = SimplePublicKey(pubKeyBytes, type: KeyPairType.x25519);
      _keyPair = SimpleKeyPairData(
        privKeyBytes,
        publicKey: _publicKey!,
        type: KeyPairType.x25519,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Есть ли сгенерированные ключи.
  bool get hasKeys => _keyPair != null;

  // ── Key Exchange ────────────────────────────────────────────

  /// Вычисляет общий секрет с другим пользователем (X25519 ECDH).
  Future<SecretKey> _sharedSecret(String peerPublicKeyB64) async {
    final peerPubBytes = base64Decode(peerPublicKeyB64);
    final peerPub = SimplePublicKey(peerPubBytes, type: KeyPairType.x25519);
    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: peerPub,
    );
    return sharedSecret;
  }

  /// Получает публичный ключ собеседника из БД.
  Future<String?> _peerPublicKey(String peerId) async {
    try {
      final row = await _client
          .from('profiles')
          .select('e2e_public_key')
          .eq('id', peerId)
          .maybeSingle();
      return row?['e2e_public_key'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Encrypt / Decrypt ───────────────────────────────────────

  /// Шифрует текст сообщения для отправки.
  /// Возвращает JSON: { iv, ciphertext, ephemeral_pub }.
  Future<Map<String, String>> encryptMessage({
    required String plaintext,
    required String peerId,
  }) async {
    final peerPubB64 = await _peerPublicKey(peerId);
    if (peerPubB64 == null) {
      throw Exception('Публичный ключ собеседника не найден');
    }

    final secret = await _sharedSecret(peerPubB64);
    final secretBytes = await secret.extractBytes();

    // Генерируем IV
    final nonce = _aesGcm.newNonce();

    // Шифруем
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(secretBytes.sublist(0, 32)),
      nonce: nonce,
    );

    return {
      'ciphertext': base64Encode(secretBox.cipherText),
      'iv': base64Encode(nonce),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  /// Расшифровывает сообщение от собеседника.
  Future<String> decryptMessage({
    required String ciphertextB64,
    required String ivB64,
    required String macB64,
    required String peerId,
  }) async {
    final peerPubB64 = await _peerPublicKey(peerId);
    if (peerPubB64 == null) throw Exception('Peer public key not found');

    final secret = await _sharedSecret(peerPubB64);
    final secretBytes = await secret.extractBytes();

    final ciphertext = base64Decode(ciphertextB64);
    final nonce = base64Decode(ivB64);
    final mac = base64Decode(macB64);

    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(mac),
    );

    final clearBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(secretBytes.sublist(0, 32)),
    );

    return utf8.decode(clearBytes);
  }

  // ── Helpers ─────────────────────────────────────────────────

  /// Шифрует и кодирует в JSON строку для storage в БД.
  Future<String> encryptToString({
    required String plaintext,
    required String peerId,
  }) async {
    final enc = await encryptMessage(plaintext: plaintext, peerId: peerId);
    return jsonEncode(enc);
  }

  /// Расшифровывает из JSON строки.
  Future<String> decryptFromString({
    required String encryptedJson,
    required String peerId,
  }) async {
    final data = jsonDecode(encryptedJson) as Map<String, dynamic>;
    return decryptMessage(
      ciphertextB64: data['ciphertext'] as String,
      ivB64: data['iv'] as String,
      macB64: data['mac'] as String,
      peerId: peerId,
    );
  }

  /// Удаляет ключи (при выходе из аккаунта).
  Future<void> deleteKeys() async {
    await _secureStorage.delete(key: 'e2e_private_key');
    await _secureStorage.delete(key: 'e2e_public_key');
    _keyPair = null;
    _publicKey = null;

    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _client.from('profiles').update({
          'e2e_public_key': null,
        }).eq('id', userId);
      } catch (_) {}
    }
  }
}
