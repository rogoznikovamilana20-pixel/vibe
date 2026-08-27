import 'package:flutter/material.dart';

import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/settings_service.dart';

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
            onTap: () {},
          ),
          _SectionCard(
            icon: Icons.chat_bubble_rounded,
            title: 'Чаты бизнеса',
            subtitle: '${limits['chats']} чатов/мес',
            onTap: () {},
          ),
          _SectionCard(
            icon: Icons.bar_chart_rounded,
            title: 'Метрики',
            subtitle: tier == 'start' ? '7 дней' : tier == 'micro' ? '30 дней' : tier == 'growth' ? '90 дней' : '365 дней',
            onTap: () {},
          ),
          _SectionCard(
            icon: Icons.group_rounded,
            title: 'Команда',
            subtitle: '${limits['members']} сотрудников',
            trailing: TextButton(
              onPressed: () {},
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
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(VibeSpacing.lg),
        decoration: BoxDecoration(color: context.vibeSurface, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Подписка', style: VibeTypography.subtitle.copyWith(color: context.vibeTextPrimary)),
            const SizedBox(height: VibeSpacing.md),
            for (final t in ['Старт 0₽', 'Микро 299₽', 'Рост 799₽', 'Масштаб 2499₽', 'Энтерпрайз 9999₽+'])
              ListTile(title: Text(t), onTap: () => Navigator.of(ctx).pop()),
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
