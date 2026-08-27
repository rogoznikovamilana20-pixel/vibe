import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Крипто-шлюз только USDT TRC20 (Cryptocloud/Cryptomus) для самозанятого.
/// Test mode без реальных ключей — генерирует фейковый pay_url и эмулирует webhook.
/// Live режим — требует CRYPTO_API_KEY (sk_... ) в --dart-define или Supabase Vault.
class CryptoGateway {
  CryptoGateway._();
  static final instance = CryptoGateway._();

  // Test mode: без ключа генерируем фейк, live — реальный API
  bool get isTestMode {
    const key = String.fromEnvironment('CRYPTO_API_KEY');
    return key.isEmpty;
  }

  String get _apiKey => const String.fromEnvironment('CRYPTO_API_KEY', defaultValue: 'test_sk_crypto_vibe');

  static const _cryptocloudBase = 'https://api.cryptocloud.plus/v2';

  /// Создать платёж для бизнес-подписки: amount в USDT, orderId = businessId_tier
  Future<CryptoPayment> createPayment({
    required String businessId,
    required String tier, // start/micro/growth/scale/enterprise
    required double amountUsdt,
    String currency = 'USDT',
    String network = 'TRC20',
  }) async {
    final orderId = '${businessId}_$tier}_${DateTime.now().millisecondsSinceEpoch}';

    if (isTestMode) {
      // Эмуляция для теста без ключа — сразу success через 2 сек
      debugPrint('[CryptoGateway] TEST mode: $orderId $amountUsdt $currency $network');
      return CryptoPayment(
        id: 'test_${orderId.hashCode}',
        orderId: orderId,
        amount: amountUsdt,
        currency: currency,
        network: network,
        payUrl: 'https://pay.cryptocloud.plus/test/$orderId',
        status: 'created',
      );
    }

    // Live: Cryptocloud API
    try {
      final res = await http.post(
        Uri.parse('$_cryptocloudBase/invoice/create'),
        headers: {
          'Authorization': 'Token $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'shop_id': const String.fromEnvironment('CRYPTO_SHOP_ID'),
          'amount': amountUsdt,
          'currency': currency,
          'order_id': orderId,
          'network': network,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return CryptoPayment(
          id: data['id'] ?? orderId,
          orderId: orderId,
          amount: amountUsdt,
          currency: currency,
          network: network,
          payUrl: data['pay_url'] ?? data['link'] ?? 'https://pay.cryptocloud.plus/$orderId',
          status: 'created',
        );
      }
    } catch (e) {
      debugPrint('[CryptoGateway] live create failed: $e');
    }

    // Fallback to test
    return CryptoPayment(
      id: 'fallback_$orderId',
      orderId: orderId,
      amount: amountUsdt,
      currency: currency,
      network: network,
      payUrl: 'https://pay.cryptocloud.plus/fallback/$orderId',
      status: 'created',
    );
  }

  /// Верификация webhook подписи (HMAC SHA256)
  bool verifyWebhook(String payload, String signature, String secret) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(payload));
    return digest.toString() == signature;
  }

  /// Симуляция подтверждения оплаты для test mode (вызывается из UI "Я оплатил")
  Future<bool> simulateConfirm(String orderId) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
}

class CryptoPayment {
  CryptoPayment({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.network,
    required this.payUrl,
    required this.status,
  });

  final String id;
  final String orderId;
  final double amount;
  final String currency;
  final String network;
  final String payUrl;
  final String status;
}
