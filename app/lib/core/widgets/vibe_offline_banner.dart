import 'package:flutter/material.dart';

import '../theme/vibe_colors.dart';
import '../theme/vibe_spacing.dart';
import '../theme/vibe_typography.dart';

/// Тонкая полоска «оффлайн»: показывается, когда приложение отдаёт
/// кешированные данные (как в Telegram — кеш виден, сеть отмечена).
class VibeOfflineBanner extends StatelessWidget {
  const VibeOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        VibeSpacing.lg,
        0,
        VibeSpacing.lg,
        VibeSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: VibeSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: VibeColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VibeRadius.pill),
        border: Border.all(
          color: VibeColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 14,
            color: VibeColors.warning,
          ),
          const SizedBox(width: VibeSpacing.xs),
          Flexible(
            child: Text(
              'Нет сети — показаны кешированные данные',
              style: VibeTypography.caption.copyWith(
                color: VibeColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}