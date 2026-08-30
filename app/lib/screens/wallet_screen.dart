// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';

import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    double bal = CryptoGateway.instance.isTestMode ? 100.0 : 0.0;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final biz = await Supabase.instance.client.from('businesses').select('id').eq('owner_id', uid).limit(1);
        if (biz.isNotEmpty) {
          final bid = biz.first['id'] as String;
          final subs = await Supabase.instance.client.from('business_subscriptions').select('coins_spent').eq('business_id', bid).maybeSingle();
          final spent = (subs?['coins_spent'] as int?) ?? 0;
          final addons = await Supabase.instance.client.from('business_addons').select('coins').eq('business_id', bid);
          final addonCoins = (addons as List).fold<int>(0, (s, r) => s + ((r['coins'] as int?) ?? 0));
          bal = (100 - spent - addonCoins).clamp(0, 10000).toDouble();
          // Realtime: слушать изменения
          Supabase.instance.client.from('business_subscriptions').stream(primaryKey: ['business_id']).eq('business_id', bid).listen((_) { if (mounted) _load(); });
        }
      }
    } catch (_) {}
    if (mounted) setState(()=> _balance = bal);
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
