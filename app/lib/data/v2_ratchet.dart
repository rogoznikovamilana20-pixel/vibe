import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Максимальное количество пропущенных ключей в store.
const int v2MaxSkippedKeys = 1000;

/// Длина вывода HKDF для DH ratchet: 64 bytes = root_key(32) + chain_key(32).
const int _dhRatchetOutputLength = 64;

/// DoS protection: maximum allowed message number jump.
///
/// A malicious message with huge messageNumber must NOT trigger billions of
/// KDF iterations. This limit caps the number of chain steps in one decrypt.
/// Messages exceeding this are rejected with V2RatchetException.
const int v2MaxMessageNumberJump = 2000;

/// DoS protection: maximum allowed previousChainLength.
///
/// Prevents oversized previous chain claims from consuming excessive memory
/// in skippedKeys. Messages exceeding this are rejected.
const int v2MaxPreviousChainLength = 10000;

// =============================================================================
// Data Classes
// =============================================================================

/// Состояние Double Ratchet сессии.
///
/// Immutable — все операции возвращают новое состояние.
class V2RatchetState {
  final String sessionId;
  final List<int> rootKey;
  final List<int>? sendingChainKey;
  final List<int>? receivingChainKey;
  final SimpleKeyPair? sendingRatchetKeyPair;
  final List<int>? sendingRatchetPubBytes;
  final List<int>? receivingRatchetPublicKey;
  final int sendingMessageNumber;
  final int receivingMessageNumber;
  final int previousSendingChainLength;
  final Map<int, List<int>> skippedKeys;
  final int protocolVersion;
  final int ratchetStep;

  const V2RatchetState({
    required this.sessionId,
    required this.rootKey,
    this.sendingChainKey,
    this.receivingChainKey,
    this.sendingRatchetKeyPair,
    this.sendingRatchetPubBytes,
    this.receivingRatchetPublicKey,
    this.sendingMessageNumber = 0,
    this.receivingMessageNumber = 0,
    this.previousSendingChainLength = 0,
    this.skippedKeys = const {},
    this.protocolVersion = 2,
    this.ratchetStep = 0,
  });

  /// Копирует состояние с изменениями.
  V2RatchetState copyWith({
    String? sessionId,
    List<int>? rootKey,
    List<int>? sendingChainKey,
    List<int>? receivingChainKey,
    SimpleKeyPair? sendingRatchetKeyPair,
    List<int>? sendingRatchetPubBytes,
    List<int>? receivingRatchetPublicKey,
    int? sendingMessageNumber,
    int? receivingMessageNumber,
    int? previousSendingChainLength,
    Map<int, List<int>>? skippedKeys,
    int? protocolVersion,
    int? ratchetStep,
  }) {
    return V2RatchetState(
      sessionId: sessionId ?? this.sessionId,
      rootKey: rootKey ?? this.rootKey,
      sendingChainKey: sendingChainKey ?? this.sendingChainKey,
      receivingChainKey: receivingChainKey ?? this.receivingChainKey,
      sendingRatchetKeyPair: sendingRatchetKeyPair ?? this.sendingRatchetKeyPair,
      sendingRatchetPubBytes: sendingRatchetPubBytes ?? this.sendingRatchetPubBytes,
      receivingRatchetPublicKey: receivingRatchetPublicKey ?? this.receivingRatchetPublicKey,
      sendingMessageNumber: sendingMessageNumber ?? this.sendingMessageNumber,
      receivingMessageNumber: receivingMessageNumber ?? this.receivingMessageNumber,
      previousSendingChainLength: previousSendingChainLength ?? this.previousSendingChainLength,
      skippedKeys: skippedKeys ?? this.skippedKeys,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      ratchetStep: ratchetStep ?? this.ratchetStep,
    );
  }
}

/// Заголовок сообщения V2.
///
/// Содержит минимум полей для идентификации и декодирования.
class V2MessageHeader {
  final int protocolVersion;
  final List<int> senderIdentityKey;
  final List<int> senderRatchetPublicKey;
  final int messageNumber;
  final int previousChainLength;

  const V2MessageHeader({
    required this.protocolVersion,
    required this.senderIdentityKey,
    required this.senderRatchetPublicKey,
    required this.messageNumber,
    required this.previousChainLength,
  });

  /// Сериализует заголовок в JSON.
  Map<String, dynamic> toJson() => {
    'v': protocolVersion,
    'ik': base64Encode(senderIdentityKey),
    'rk': base64Encode(senderRatchetPublicKey),
    'mn': messageNumber,
    'pcl': previousChainLength,
  };

  /// Десериализует заголовок из JSON.
  factory V2MessageHeader.fromJson(Map<String, dynamic> json) => V2MessageHeader(
    protocolVersion: json['v'] as int,
    senderIdentityKey: base64Decode(json['ik'] as String),
    senderRatchetPublicKey: base64Decode(json['rk'] as String),
    messageNumber: json['mn'] as int,
    previousChainLength: json['pcl'] as int,
  );

  /// Сериализует заголовок в байты (固定 76 bytes: 4+32+32+4+4).
  List<int> toBytes() {
    final byteData = ByteData(76);
    byteData.setUint32(0, protocolVersion, Endian.big);
    for (var i = 0; i < 32; i++) {
      byteData.setUint8(4 + i, senderIdentityKey[i]);
      byteData.setUint8(36 + i, senderRatchetPublicKey[i]);
    }
    byteData.setUint32(68, messageNumber, Endian.big);
    byteData.setUint32(72, previousChainLength, Endian.big);
    return byteData.buffer.asUint8List();
  }

  /// Десериализует заголовок из байтов.
  factory V2MessageHeader.fromBytes(List<int> bytes) {
    final byteData = ByteData.view(Uint8List.fromList(bytes).buffer);
    final senderIk = List<int>.generate(32, (i) => byteData.getUint8(4 + i));
    final senderRk = List<int>.generate(32, (i) => byteData.getUint8(36 + i));
    return V2MessageHeader(
      protocolVersion: byteData.getUint32(0, Endian.big),
      senderIdentityKey: senderIk,
      senderRatchetPublicKey: senderRk,
      messageNumber: byteData.getUint32(68, Endian.big),
      previousChainLength: byteData.getUint32(72, Endian.big),
    );
  }
}

/// Envelope шифрованного сообщения V2.
///
/// Формат (spec §10.4):
///   [version:1][sender_ik:32][sender_rk:32][msg_num:4][prev_chain_len:4][nonce:12][ciphertext+tag]
///
/// Tag включён в ciphertext поле (SecretBox.concatenation() = nonce || ciphertext || tag).
/// При сериализации nonce вынесен отдельно, tag остаётся в конце ciphertext.
class V2MessageEnvelope {
  final int version;
  final List<int> senderIdentityKey;
  final List<int> senderRatchetPublicKey;
  final int messageNumber;
  final int previousChainLength;
  final List<int> nonce;
  final List<int> ciphertextWithMac;

  const V2MessageEnvelope({
    required this.version,
    required this.senderIdentityKey,
    required this.senderRatchetPublicKey,
    required this.messageNumber,
    required this.previousChainLength,
    required this.nonce,
    required this.ciphertextWithMac,
  });

  /// Вычисляет размер заголовка (без переменных полей).
  static const int headerSize = 1 + 32 + 32 + 4 + 4; // 73 bytes

  /// Создаёт envelope из компонентов encrypt().
  ///
  /// secretBoxConcat = nonce(12) || ciphertext || tag(16).
  factory V2MessageEnvelope.fromComponents({
    required V2MessageHeader header,
    required List<int> secretBoxConcat,
  }) {
    return V2MessageEnvelope(
      version: header.protocolVersion,
      senderIdentityKey: header.senderIdentityKey,
      senderRatchetPublicKey: header.senderRatchetPublicKey,
      messageNumber: header.messageNumber,
      previousChainLength: header.previousChainLength,
      nonce: secretBoxConcat.sublist(0, 12),
      ciphertextWithMac: secretBoxConcat.sublist(12),
    );
  }

  /// Сериализует envelope в bytes.
  ///
  /// Формат: [version:1][sender_ik:32][sender_rk:32][mn:4][pcl:4][nonce:12][ct_with_mac]
  List<int> toBytes() {
    final ctLen = ciphertextWithMac.length;
    final totalSize = headerSize + 12 + ctLen;
    final result = Uint8List(totalSize);
    final byteData = ByteData.view(result.buffer);

    var offset = 0;
    // version (1 byte)
    result[offset++] = version;
    // sender identity key (32 bytes)
    result.setRange(offset, offset + 32, senderIdentityKey);
    offset += 32;
    // sender ratchet public key (32 bytes)
    result.setRange(offset, offset + 32, senderRatchetPublicKey);
    offset += 32;
    // message number (4 bytes)
    byteData.setUint32(offset, messageNumber, Endian.big);
    offset += 4;
    // previous chain length (4 bytes)
    byteData.setUint32(offset, previousChainLength, Endian.big);
    offset += 4;
    // nonce (12 bytes)
    result.setRange(offset, offset + 12, nonce);
    offset += 12;
    // ciphertext + mac
    result.setRange(offset, offset + ctLen, ciphertextWithMac);

    return result;
  }

  /// Десериализует envelope из bytes.
  ///
  /// Throws [V2RatchetException] если формат невалиден.
  factory V2MessageEnvelope.fromBytes(List<int> bytes) {
    if (bytes.length < headerSize + 12) {
      throw V2RatchetException(
        'Envelope too short: ${bytes.length} < ${headerSize + 12}',
      );
    }

    var offset = 0;
    final version = bytes[offset++];

    final senderIk = List<int>.generate(32, (i) => bytes[offset + i]);
    offset += 32;

    final senderRk = List<int>.generate(32, (i) => bytes[offset + i]);
    offset += 32;

    final byteData = ByteData.view(Uint8List.fromList(bytes).buffer);
    final messageNumber = byteData.getUint32(offset, Endian.big);
    offset += 4;

    final previousChainLength = byteData.getUint32(offset, Endian.big);
    offset += 4;

    final nonce = List<int>.generate(12, (i) => bytes[offset + i]);
    offset += 12;

    final ciphertextWithMac = List<int>.from(bytes.sublist(offset));

    return V2MessageEnvelope(
      version: version,
      senderIdentityKey: senderIk,
      senderRatchetPublicKey: senderRk,
      messageNumber: messageNumber,
      previousChainLength: previousChainLength,
      nonce: nonce,
      ciphertextWithMac: ciphertextWithMac,
    );
  }

  /// Конвертирует в header + secretBox concatenation для decrypt().
  ({V2MessageHeader header, List<int> secretBoxConcat}) toDecryptComponents() {
    final header = V2MessageHeader(
      protocolVersion: version,
      senderIdentityKey: senderIdentityKey,
      senderRatchetPublicKey: senderRatchetPublicKey,
      messageNumber: messageNumber,
      previousChainLength: previousChainLength,
    );
    return (
      header: header,
      secretBoxConcat: [...nonce, ...ciphertextWithMac],
    );
  }
}

// =============================================================================
// Exception
// =============================================================================

/// Исключение V2 Ratchet.
class V2RatchetException implements Exception {
  final String message;
  const V2RatchetException(this.message);
  @override
  String toString() => 'V2RatchetException: $message';
}

// =============================================================================
// Ratchet Operations
// =============================================================================

/// Double Ratchet операции.
///
/// Все методы статические и чистые (pure functions) —
/// не имеют побочных эффектов, легко тестируются.
class V2Ratchet {
  /// Создаёт начальное состояние из X3DH вывода.
  ///
  /// initiator=true: имеет sendingChainKey (может отправлять первым).
  /// initiator=false: имеет sendingChainKey (но ждёт первый消息 от initiator).
  static V2RatchetState createInitialState({
    required String sessionId,
    required List<int> rootKey,
    required List<int> chainKey,
  }) {
    return V2RatchetState(
      sessionId: sessionId,
      rootKey: rootKey,
      sendingChainKey: chainKey,
    );
  }

  /// Создаёт начальное состояние для ПОЛУЧАТЕЛЯ (Bob).
  ///
  /// После X3DH обе стороны имеют chain_key.
  /// Отправитель хранит его как sendingChainKey,
  /// получатель — как receivingChainKey.
  static V2RatchetState createReceiverInitialState({
    required String sessionId,
    required List<int> rootKey,
    required List<int> chainKey,
  }) {
    return V2RatchetState(
      sessionId: sessionId,
      rootKey: rootKey,
      receivingChainKey: chainKey,
    );
  }

  /// KDF chain: chain_key → message_key + next_chain_key.
  ///
  /// spec: message_key = HMAC-SHA256(chain_key, 0x01)
  ///       next_chain_key = HMAC-SHA256(chain_key, 0x02)
  static Future<({List<int> messageKey, List<int> nextChainKey})> kdfChain(
    List<int> chainKey,
  ) async {
    final hmac = Hmac.sha256();

    final messageKeyMac = await hmac.calculateMac(
      [0x01],
      secretKey: SecretKey(chainKey),
    );
    final nextChainKeyMac = await hmac.calculateMac(
      [0x02],
      secretKey: SecretKey(chainKey),
    );

    return (
      messageKey: messageKeyMac.bytes,
      nextChainKey: nextChainKeyMac.bytes,
    );
  }

  /// KDF для DH ratchet step: rootKey + DH → newRootKey + newChainKey.
  ///
  /// spec: HKDF-SHA256(ikm=DH, salt=rootKey, info="", len=64)
  /// Both sides produce identical output because DH is symmetric and info is empty.
  static Future<({List<int> rootKey, List<int> chainKey})> kdfRatchet(
    List<int> rootKey,
    List<int> dhOutput,
  ) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: _dhRatchetOutputLength);

    final derivedKey = await hkdf.deriveKey(
      secretKey: SecretKey(dhOutput),
      nonce: rootKey,
    );
    final derivedBytes = await derivedKey.extractBytes();

    return (
      rootKey: derivedBytes.sublist(0, 32),
      chainKey: derivedBytes.sublist(32, 64),
    );
  }

  /// DH ratchet step — обновляет состояние при получении нового remote ratchet public key.
  ///
  /// spec §11.4:
  /// 1. Update receiving chain: DH + KDF
  /// 2. Generate new ratchet key pair
  /// 3. Update sending chain: DH + KDF
  /// 4. Reset counters
  static Future<V2RatchetState> dhRatchetStep(
    V2RatchetState state,
    List<int> remoteRatchetPub,
  ) async {
    final x25519 = Cryptography.instance.x25519();

    // If no ratchet key pair yet (first message), generate one
    var currentKeyPair = state.sendingRatchetKeyPair;
    currentKeyPair ??= await x25519.newKeyPair();

    // 1. Update receiving chain
    final dh1 = await x25519.sharedSecretKey(
      keyPair: currentKeyPair,
      remotePublicKey: SimplePublicKey(remoteRatchetPub, type: KeyPairType.x25519),
    );
    final dh1Bytes = await dh1.extractBytes();

    final ratchet1 = await kdfRatchet(
      state.rootKey,
      dh1Bytes,
    );

    // 2. Generate new ratchet key pair
    final newRatchetPair = await x25519.newKeyPair();
    final newRatchetPub = await newRatchetPair.extractPublicKey();

    // 3. Update sending chain
    final dh2 = await x25519.sharedSecretKey(
      keyPair: newRatchetPair,
      remotePublicKey: SimplePublicKey(remoteRatchetPub, type: KeyPairType.x25519),
    );
    final dh2Bytes = await dh2.extractBytes();

    final ratchet2 = await kdfRatchet(
      ratchet1.rootKey,
      dh2Bytes,
    );

    // 4. Reset counters, PRESERVE skipped keys from old chain, increment ratchet step
    // Signal Protocol spec §3.3: "Skipped message keys from the previous
    // receiving chain MUST be preserved to allow out-of-order delivery."
    return state.copyWith(
      rootKey: ratchet2.rootKey,
      sendingChainKey: ratchet2.chainKey,
      receivingChainKey: ratchet1.chainKey,
      sendingRatchetKeyPair: newRatchetPair,
      sendingRatchetPubBytes: newRatchetPub.bytes,
      receivingRatchetPublicKey: remoteRatchetPub,
      sendingMessageNumber: 0,
      receivingMessageNumber: 0,
      previousSendingChainLength: state.sendingMessageNumber,
      skippedKeys: state.skippedKeys,
      ratchetStep: state.ratchetStep + 1,
    );
  }

  /// Шифрует сообщение.
  ///
  /// Возвращает (header, ciphertext, newState).
  static Future<({V2MessageHeader header, List<int> ciphertext, V2RatchetState state})> encrypt({
    required V2RatchetState state,
    required String plaintext,
    required List<int> identityKeyPublic,
    required String senderDeviceId,
    required String recipientDeviceId,
  }) async {
    final x25519 = Cryptography.instance.x25519();

    var currentState = state;

    // If no sending chain key, derive one by generating a new ratchet key pair
    // and performing a single DH step. This does NOT touch the receiving chain.
    //
    // This happens when the responder (Bob) wants to send his first response:
    // he has receivingChainKey from X3DH but needs sendingChainKey.
    if (currentState.sendingChainKey == null) {
      if (currentState.receivingRatchetPublicKey == null) {
        throw const V2RatchetException('No sending chain key and no ratchet public key for DH step');
      }

      // Generate new ratchet key pair
      final newRatchetPair = await x25519.newKeyPair();
      final newRatchetPub = await newRatchetPair.extractPublicKey();

      // Single DH step: derive sending chain from current root key + remote ratchet pub
      final dh = await x25519.sharedSecretKey(
        keyPair: newRatchetPair,
        remotePublicKey: SimplePublicKey(currentState.receivingRatchetPublicKey!, type: KeyPairType.x25519),
      );
      final dhBytes = await dh.extractBytes();

      final ratchet = await kdfRatchet(
        currentState.rootKey,
        dhBytes,
      );

      // Update state: new root key, new sending chain, keep receiving chain intact
      currentState = currentState.copyWith(
        rootKey: ratchet.rootKey,
        sendingChainKey: ratchet.chainKey,
        sendingRatchetKeyPair: newRatchetPair,
        sendingRatchetPubBytes: newRatchetPub.bytes,
        sendingMessageNumber: 0,
        previousSendingChainLength: currentState.sendingMessageNumber,
        ratchetStep: currentState.ratchetStep + 1,
      );
    }

    // Ensure we have a ratchet key pair for the header
    var ratchetKeyPair = currentState.sendingRatchetKeyPair;
    List<int> ratchetPubBytes;
    if (ratchetKeyPair == null) {
      ratchetKeyPair = await x25519.newKeyPair();
      final pub = await ratchetKeyPair.extractPublicKey();
      ratchetPubBytes = pub.bytes;
    } else {
      ratchetPubBytes = currentState.sendingRatchetPubBytes!;
    }

    // 1. Derive message key
    final (messageKey: messageKey, nextChainKey: nextChainKey) = await kdfChain(
      currentState.sendingChainKey!,
    );

    // 2. Compute nonce (12 bytes)
    final nonce = _computeNonce(
      currentState.sendingMessageNumber,
      currentState.previousSendingChainLength,
      currentState.ratchetStep,
    );

    // 3. Compute AAD (includes ratchet pub key for step binding)
    final aad = _computeAad(
      senderIdentityKey: identityKeyPublic,
      senderRatchetPublicKey: ratchetPubBytes,
      senderDeviceId: senderDeviceId,
      recipientDeviceId: recipientDeviceId,
      messageNumber: currentState.sendingMessageNumber,
      previousChainLength: currentState.previousSendingChainLength,
    );

    // 4. Encrypt (AES-256-GCM)
    final aesGcm = AesGcm.with256bits(nonceLength: 12);
    final secretBox = await aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(messageKey),
      nonce: nonce,
      aad: aad,
    );

    // 5. Create header
    final header = V2MessageHeader(
      protocolVersion: currentState.protocolVersion,
      senderIdentityKey: identityKeyPublic,
      senderRatchetPublicKey: ratchetPubBytes,
      messageNumber: currentState.sendingMessageNumber,
      previousChainLength: currentState.previousSendingChainLength,
    );

    // 6. Update state
    final newState = currentState.copyWith(
      sendingChainKey: nextChainKey,
      sendingRatchetKeyPair: ratchetKeyPair,
      sendingRatchetPubBytes: ratchetPubBytes,
      sendingMessageNumber: currentState.sendingMessageNumber + 1,
    );

    return (
      header: header,
      ciphertext: secretBox.concatenation(),
      state: newState,
    );
  }

  /// Дешифрует сообщение.
  ///
  /// Возвращает (plaintext, newState).
  static Future<({String plaintext, V2RatchetState state})> decrypt({
    required V2RatchetState state,
    required V2MessageHeader header,
    required List<int> ciphertext,
    required String senderDeviceId,
    required String recipientDeviceId,
  }) async {
    // 1. Determine chain state
    V2RatchetState workingState;
    if (state.receivingRatchetPublicKey != null &&
        _listEquals(header.senderRatchetPublicKey, state.receivingRatchetPublicKey!)) {
      // Same chain: use existing receiving chain
      workingState = state;
    } else if (state.receivingChainKey != null &&
        state.receivingRatchetPublicKey == null) {
      // First message: have chain_key from X3DH but no ratchet pub stored yet.
      // Use existing receivingChainKey directly (no DH ratchet for first message).
      workingState = state.copyWith(
        receivingRatchetPublicKey: header.senderRatchetPublicKey,
      );
    } else {
      // New chain: perform DH ratchet step
      workingState = await dhRatchetStep(state, header.senderRatchetPublicKey);
    }

    // 2. Process message
    return _decryptFromCurrentChain(
      state: workingState,
      header: header,
      ciphertext: ciphertext,
      senderIdentityKey: header.senderIdentityKey,
      senderDeviceId: senderDeviceId,
      recipientDeviceId: recipientDeviceId,
    );
  }

  /// Дешифрует сообщение из текущей цепочки.
  static Future<({String plaintext, V2RatchetState state})> _decryptFromCurrentChain({
    required V2RatchetState state,
    required V2MessageHeader header,
    required List<int> ciphertext,
    required List<int> senderIdentityKey,
    required String senderDeviceId,
    required String recipientDeviceId,
  }) async {
    if (state.receivingChainKey == null) {
      throw const V2RatchetException('No receiving chain key');
    }

    // DoS protection: reject excessive message number jump
    final messageNumberJump = header.messageNumber - state.receivingMessageNumber;
    if (messageNumberJump > v2MaxMessageNumberJump) {
      throw V2RatchetException(
        'Message number jump too large: $messageNumberJump > $v2MaxMessageNumberJump',
      );
    }

    // DoS protection: reject excessive previousChainLength
    if (header.previousChainLength > v2MaxPreviousChainLength) {
      throw V2RatchetException(
        'Previous chain length too large: ${header.previousChainLength} > $v2MaxPreviousChainLength',
      );
    }

    // Case 1: Old message (messageNumber < receivingMessageNumber)
    if (header.messageNumber < state.receivingMessageNumber) {
      final messageKey = state.skippedKeys[header.messageNumber];
      if (messageKey == null) {
        throw const V2RatchetException('Message key not found in skipped keys');
      }

      final plaintext = await _decryptWithKey(
        messageKey: messageKey,
        ciphertext: ciphertext,
        header: header,
        senderIdentityKey: senderIdentityKey,
        senderDeviceId: senderDeviceId,
        recipientDeviceId: recipientDeviceId,
      );

      final newSkippedKeys = Map<int, List<int>>.from(state.skippedKeys);
      newSkippedKeys.remove(header.messageNumber);

      return (
        plaintext: plaintext,
        state: state.copyWith(skippedKeys: newSkippedKeys),
      );
    }

    // Case 2: Future message (messageNumber >= receivingMessageNumber)
    // Advance receiving chain to message number
    var currentChainKey = state.receivingChainKey!;
    var currentMessageNumber = state.receivingMessageNumber;
    final newSkippedKeys = Map<int, List<int>>.from(state.skippedKeys);

    while (currentMessageNumber < header.messageNumber) {
      final (messageKey: skippedKey, nextChainKey: nextChainKey) = await kdfChain(currentChainKey);
      // Bound check: don't exceed max skipped keys
      if (newSkippedKeys.length < v2MaxSkippedKeys) {
        newSkippedKeys[currentMessageNumber] = skippedKey;
      }
      currentChainKey = nextChainKey;
      currentMessageNumber++;
    }

    // Derive message key for target message
    final (messageKey: messageKey, nextChainKey: nextChainKey) = await kdfChain(currentChainKey);

    // Decrypt
    final plaintext = await _decryptWithKey(
      messageKey: messageKey,
      ciphertext: ciphertext,
      header: header,
      senderIdentityKey: senderIdentityKey,
      senderDeviceId: senderDeviceId,
      recipientDeviceId: recipientDeviceId,
    );

    // Remove only the consumed message key (keep other cached keys for out-of-order)
    newSkippedKeys.remove(header.messageNumber);

    return (
      plaintext: plaintext,
      state: state.copyWith(
        receivingChainKey: nextChainKey,
        receivingMessageNumber: header.messageNumber + 1,
        skippedKeys: newSkippedKeys,
      ),
    );
  }

  /// Дешифрует с использованием конкретного ключа.
  static Future<String> _decryptWithKey({
    required List<int> messageKey,
    required List<int> ciphertext,
    required V2MessageHeader header,
    required List<int> senderIdentityKey,
    required String senderDeviceId,
    required String recipientDeviceId,
  }) async {
    final aad = _computeAad(
      senderIdentityKey: senderIdentityKey,
      senderRatchetPublicKey: header.senderRatchetPublicKey,
      senderDeviceId: senderDeviceId,
      recipientDeviceId: recipientDeviceId,
      messageNumber: header.messageNumber,
      previousChainLength: header.previousChainLength,
    );

    final aesGcm = AesGcm.with256bits(nonceLength: 12);
    final secretBox = SecretBox.fromConcatenation(
      ciphertext,
      nonceLength: 12,
      macLength: 16,
    );
    final plaintext = await aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(messageKey),
      aad: aad,
    );

    return utf8.decode(plaintext);
  }

  // ===========================================================================
  // Envelope API
  // ===========================================================================

  /// Шифрует сообщение и возвращает envelope (единый формат).
  ///
  /// Envelope содержит заголовок + nonce + ciphertext + tag в одном байте.
  /// Формат: [version:1][sender_ik:32][sender_rk:32][mn:4][pcl:4][nonce:12][ct+tag]
  static Future<({V2MessageEnvelope envelope, V2RatchetState state})> encryptToEnvelope({
    required V2RatchetState state,
    required String plaintext,
    required List<int> identityKeyPublic,
    required String senderDeviceId,
    required String recipientDeviceId,
  }) async {
    final result = await encrypt(
      state: state,
      plaintext: plaintext,
      identityKeyPublic: identityKeyPublic,
      senderDeviceId: senderDeviceId,
      recipientDeviceId: recipientDeviceId,
    );

    final envelope = V2MessageEnvelope.fromComponents(
      header: result.header,
      secretBoxConcat: result.ciphertext,
    );

    return (envelope: envelope, state: result.state);
  }

  /// Дешифрует сообщение из envelope.
  ///
  /// Парсит envelope, восстанавливает header и ciphertext,
  /// вызывает decrypt() с существующей логикой.
  static Future<({String plaintext, V2RatchetState state})> decryptFromEnvelope({
    required V2RatchetState state,
    required V2MessageEnvelope envelope,
    required String senderDeviceId,
    required String recipientDeviceId,
  }) async {
    if (envelope.version != 2) {
      throw V2RatchetException('Unsupported protocol version: ${envelope.version}');
    }

    final components = envelope.toDecryptComponents();

    try {
      return await decrypt(
        state: state,
        header: components.header,
        ciphertext: components.secretBoxConcat,
        senderDeviceId: senderDeviceId,
        recipientDeviceId: recipientDeviceId,
      );
    } on V2RatchetException {
      rethrow;
    } catch (e) {
      throw V2RatchetException('Decrypt failed: $e');
    }
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  /// Вычисляет nonce (12 bytes).
  ///
  /// spec §10.2: nonce = Encode32BE(msgNum) || Encode32BE(prevChainLen) || Encode32BE(ratchetStep)
  static List<int> _computeNonce(int messageNumber, int previousChainLength, int ratchetStep) {
    final byteData = ByteData(12);
    byteData.setUint32(0, messageNumber, Endian.big);
    byteData.setUint32(4, previousChainLength, Endian.big);
    byteData.setUint32(8, ratchetStep, Endian.big);
    return byteData.buffer.asUint8List();
  }

  /// Вычисляет AAD.
  ///
  /// spec §10.3: AD = sender_identity_key || sender_ratchet_pub(32)
  ///     || sender_device_id || recipient_device_id || msgNum || prevChainLen
  /// sender_ratchet_pub binds ciphertext to specific ratchet step — prevents
  /// cross-step key reuse if ratchet key is tampered in transit.
  static List<int> _computeAad({
    required List<int> senderIdentityKey,
    required List<int> senderRatchetPublicKey,
    required String senderDeviceId,
    required String recipientDeviceId,
    required int messageNumber,
    required int previousChainLength,
  }) {
    final numBytes = ByteData(8);
    numBytes.setUint32(0, messageNumber, Endian.big);
    numBytes.setUint32(4, previousChainLength, Endian.big);

    return [
      ...senderIdentityKey,
      ...senderRatchetPublicKey,
      ...utf8.encode(senderDeviceId),
      ...utf8.encode(recipientDeviceId),
      ...numBytes.buffer.asUint8List(),
    ];
  }

  /// Сравнение двух списков байтов.
  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
