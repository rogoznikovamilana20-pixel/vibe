import 'package:flutter/material.dart';

import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';

/// Разделитель дат в ленте чата: Сегодня / Вчера / дд.мм.гггг.
class MessageDateDivider extends StatelessWidget {
  const MessageDateDivider({super.key, this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VibeSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: VibeSpacing.md,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: context.vibeSurfaceVariant.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(VibeRadius.pill),
          ),
          child: Text(
            _label(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.vibeTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }

  String _label() {
    final d = date;
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Сегодня';
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == yesterday) return 'Вчера';
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }
}
