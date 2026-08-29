// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';

import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/payment/crypto_gateway.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    // Mock: баланс из CryptoGateway (test mode 100 USDT)
    final bal = CryptoGateway.instance.isTestMode ? 100.0 : 0.0;
    if (mounted) setState(()=> _balance = bal);
    // в live: await Supabase.instance.client.from('business_subscriptions').select('coins_spent')
    if (mounted) setState(()=> _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vibeBackground,
      appBar: VibeTopBarAppBar(topInset: MediaQuery.paddingOf(context).top, child: VibeTopBar(leading: VibeTopBarIcon(icon: Icons.arrow_back_rounded, onTap: ()=> Navigator.maybePop(context), tooltip: 'Назад'), title: const VibeTopBarTitle('Кошелёк'))),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Padding(padding: const EdgeInsets.all(VibeSpacing.lg), child: Column(children: [Container(padding: const EdgeInsets.all(VibeSpacing.lg), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF4F46E5)]), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 32), const SizedBox(width: VibeSpacing.md), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Баланс', style: VibeTypography.caption.copyWith(color: Colors.white70)), Text('$_balance USDT', style: VibeTypography.title.copyWith(color: Colors.white))])])), const SizedBox(height: VibeSpacing.lg), FilledButton.icon(icon: const Icon(Icons.output_rounded), label: const Text('Вывести (USDT TRC20)'), onPressed: () async { final ok = await CryptoGateway.instance.createPayment(businessId: 'withdraw', tier: 'withdraw', amountUsdt: 10); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Заявка: ${ok.payUrl}'))); }), const SizedBox(height: VibeSpacing.md), OutlinedButton.icon(icon: const Icon(Icons.receipt_long_rounded), label: const Text('Чек НПД (Мой налог)'), onPressed: ()=> ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Чек сформируется после вывода')))) ])),
    );
  }
}
