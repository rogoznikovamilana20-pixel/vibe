import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/backend.dart';
import '../data/payment/business_crypto_pay.dart';
import '../data/settings_service.dart';
import 'business/business_members_screen.dart';
import 'business/business_metrics_screen.dart';
import 'business/business_showcases_screen.dart';

Future<String> _ensureBusinessId() async {
  final uid = VibeBackend.instanceOrNull?.myProfileId ?? Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) throw Exception('Не авторизован');
  final client = Supabase.instance.client;
  final existing = await client.from('businesses').select('id').eq('owner_id', uid).limit(1);
  if (existing.isNotEmpty) return existing.first['id'] as String;
  final inserted = await client.from('businesses').insert({'owner_id': uid, 'title': 'Мой бизнес'}).select('id').single();
  return inserted['id'] as String;
}

/// Бизнес-пространство: витрины, чаты, метрики, команда — отдельно от личных чатов (как TG Business).
/// Лимиты по тиру: Старт(1/10/1) Микро(1/50/3) Рост(5/500/10) Масштаб(20/5k/50) Энтерпрайз(∞).
class BusinessSpaceScreen extends StatelessWidget {
  const BusinessSpaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tier = SettingsService.instance.businessTier;
    final limits = SettingsService.instance.businessLimits;
    return Scaffold(
      backgroundColor: context.vibeBackground,
      appBar: VibeTopBarAppBar(
        topInset: MediaQuery.paddingOf(context).top,
        child: VibeTopBar(
          leading: VibeTopBarIcon(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
            tooltip: 'Назад',
          ),
          title: const VibeTopBarTitle('Бизнес'),
          actions: [
            IconButton(
              icon: const Icon(Icons.workspace_premium_rounded),
              tooltip: 'Подписка $tier',
              onPressed: () => _showTierSheet(context),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VibeSpacing.lg),
        children: [
          _TierCard(tier: tier, limits: limits),
          const SizedBox(height: VibeSpacing.lg),
          _SectionCard(
            icon: Icons.storefront_rounded,
            title: 'Витрина',
            subtitle: '${limits['showcases']} витрин • ${limits['products']} товаров',
            onTap: () async { try { final id = await _ensureBusinessId(); if (!context.mounted) return; Navigator.of(context).push(MaterialPageRoute(builder: (_) => BusinessShowcasesScreen(businessId: id))); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'))); } },
          ),
          _SectionCard(
            icon: Icons.chat_bubble_rounded,
            title: 'Чаты бизнеса',
            subtitle: '${limits['chats']} чатов/мес',
            onTap: () async { try { final id = await _ensureBusinessId(); if (!context.mounted) return; final chats = await VibeBackend.instance.listChats(); if (!context.mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Бизнес $id: ${chats.length} чатов'))); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'))); } },
          ),
          _SectionCard(
            icon: Icons.bar_chart_rounded,
            title: 'Метрики',
            subtitle: tier == 'start' ? '7 дней' : tier == 'micro' ? '30 дней' : tier == 'growth' ? '90 дней' : '365 дней',
            onTap: () async { try { final id = await _ensureBusinessId(); if (!context.mounted) return; Navigator.of(context).push(MaterialPageRoute(builder: (_) => BusinessMetricsScreen(businessId: id))); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'))); } },
          ),
          _SectionCard(
            icon: Icons.group_rounded,
            title: 'Команда',
            subtitle: '${limits['members']} сотрудников',
            trailing: TextButton(
              onPressed: () async { try { final id = await _ensureBusinessId(); if (!context.mounted) return; Navigator.of(context).push(MaterialPageRoute(builder: (_) => BusinessMembersScreen(businessId: id))); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'))); } },
              child: const Text('+ Добавить'),
            ),
          ),
          const SizedBox(height: VibeSpacing.lg),
          Text(
            'Pay-as-you-go: +50 товаров 499 Coins, +5 сотрудников 999 Coins — без прыжка в тир.',
            style: VibeTypography.caption.copyWith(color: context.vibeTextTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showTierSheet(BuildContext context) {
    final tiers = {
      'Старт 0₽ (0 USDT)': 'start',
      'Микро 2 USDT ~199₽': 'micro',
      'Рост 8 USDT ~799₽': 'growth',
      'Масштаб 25 USDT ~2499₽': 'scale',
      'Энтерпрайз 100 USDT': 'enterprise',
    };
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(VibeSpacing.lg),
        decoration: BoxDecoration(color: context.vibeSurface, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Подписка — только USDT TRC20', style: VibeTypography.subtitle.copyWith(color: context.vibeTextPrimary)),
            Text('Самозанятый: чек НПД в Мой налог после конвертации', style: VibeTypography.caption.copyWith(color: context.vibeTextTertiary)),
            const SizedBox(height: VibeSpacing.md),
            for (final e in tiers.entries)
              ListTile(
                title: Text(e.key),
                trailing: SettingsService.instance.businessTier == e.value ? Icon(Icons.check_rounded, color: context.vibePrimary) : null,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  if (!context.mounted) return;
                  if (e.value == 'start') {
                    await SettingsService.instance.setBusinessTier('start');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Тир Старт')));
                    return;
                  }
                  bool ok = false;
                  String bid = 'my_business';
                  try { bid = await _ensureBusinessId(); } catch (_) {}
                  try {
                    ok = await BusinessCryptoPay.instance.payTier(
                      businessId: bid,
                      tier: e.value,
                      getCurrentTier: () => SettingsService.instance.businessTier,
                      onSuccess: (newTier) async => await SettingsService.instance.setBusinessTier(newTier),
                    );
                  } catch (err) {
                    ok = false;
                  }
                  if (!context.mounted) return;
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось создать оплату')));
                  } else {
                    try {
                      await BusinessCryptoPay.instance.confirmTestPayment(bid, e.value);
                    } catch (_) {}
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Оплачено ${e.key} (test)')));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.limits});
  final String tier;
  final Map<String, int> limits;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VibeSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: VibeColors.brandGradient),
        borderRadius: BorderRadius.circular(VibeRadius.card),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Colors.white, size: 32),
          const SizedBox(width: VibeSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Тир: $tier', style: VibeTypography.subtitle.copyWith(color: Colors.white)),
                Text('${limits['showcases']} витрин • ${limits['members']} в команде',
                    style: VibeTypography.caption.copyWith(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.subtitle, this.trailing, this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.vibeSurface,
      margin: const EdgeInsets.only(bottom: VibeSpacing.sm),
      child: ListTile(
        leading: Icon(icon, color: context.vibePrimary),
        title: Text(title, style: VibeTypography.bodyMedium.copyWith(color: context.vibeTextPrimary)),
        subtitle: Text(subtitle, style: VibeTypography.caption.copyWith(color: context.vibeTextSecondary)),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
