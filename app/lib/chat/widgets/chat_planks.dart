import 'package:flutter/material.dart';

import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';

/// Плашка «N непрочитанных» — прыжок к первому непрочитанному (как в ТГ).
class UnreadPlank extends StatelessWidget {
  const UnreadPlank({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.vibeSurfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.vibeBorder.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_downward_rounded,
              size: 16,
              color: context.vibePrimary,
            ),
            const SizedBox(width: 6),
            Text(
              '${VibeLocalizations.of(context).unreadCount}: $count',
              style: VibeTypography.caption.copyWith(
                color: context.vibeTextPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 8.4.1: липкая плашка даты — показывает дату верхнего видимого
/// сообщения, пока лента прокручена от низа (как в Telegram).
class StickDatePlank extends StatelessWidget {
  const StickDatePlank({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('stick_date'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.vibeSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.vibeBorder.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: VibeTypography.caption.copyWith(
          color: context.vibeTextPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
