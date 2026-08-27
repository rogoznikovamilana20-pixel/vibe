import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/settings_service.dart';
import 'crypto_gateway.dart';

/// Бизнес-оплата только криптой (USDT TRC20) — для самозанятого.
/// Тиры: Старт(0) Микро(2 USDT) Рост(8 USDT) Масштаб(25 USDT) Энтерпрайз(100 USDT) + pay-as-you-go.
class BusinessCryptoPay {
  BusinessCryptoPay._();
  static final instance = BusinessCryptoPay._();

  static const _tierPrices = {
    'start': 0.0,
    'micro': 2.0,
    'growth': 8.0,
    'scale': 25.0,
    'enterprise': 100.0,
  };

  static const _tierNames = {
    'start': 'Старт',
    'micro': 'Микро',
    'growth': 'Рост',
    'scale': 'Масштаб',
    'enterprise': 'Энтерпрайз',
  };

  double priceFor(String tier) => _tierPrices[tier] ?? 0;
  String nameFor(String tier) => _tierNames[tier] ?? tier;

  /// Запустить оплату тира для бизнеса: открывает payUrl, ждёт подтверждения
  Future<bool> payTier({
    required String businessId,
    required String tier,
    required String Function() getCurrentTier,
    required Future<void> Function(String newTier) onSuccess,
  }) async {
    final price = priceFor(tier);
    if (price == 0) {
      await onSuccess(tier);
      return true;
    }

    final payment = await CryptoGateway.instance.createPayment(
      businessId: businessId,
      tier: tier,
      amountUsdt: price,
    );

    final uri = Uri.parse(payment.payUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('[BusinessCryptoPay] cannot launch ${payment.payUrl}');
      return false;
    }

    // В test mode сразу считаем оплаченным после "Я оплатил" диалога
    // В live — ждём webhook, но для теста эмулируем
    if (CryptoGateway.instance.isTestMode) {
      // Показываем диалог "Я оплатил" — вызывающий покажет его
      return true;
    }

    // Live: ждём webhook (пока просто true, webhook обновит tier в фоне)
    return true;
  }

  /// Подтвердить оплату в test mode (вызывается из UI после "Я оплатил")
  Future<bool> confirmTestPayment(String businessId, String tier) async {
    final ok = await CryptoGateway.instance.simulateConfirm('${businessId}_$tier');
    if (ok) {
      await SettingsService.instance.setBusinessTier(tier);
    }
    return ok;
  }

  /// Pay-as-you-go аддоны (только крипта)
  Future<bool> payAddon({
    required String businessId,
    required String type, // extra_showcase, extra_members, extra_products
    required int quantity,
    required double pricePerUnit,
  }) async {
    final total = pricePerUnit * quantity;
    final payment = await CryptoGateway.instance.createPayment(
      businessId: businessId,
      tier: 'addon_${type}_$quantity',
      amountUsdt: total,
    );
    final uri = Uri.parse(payment.payUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }
}
