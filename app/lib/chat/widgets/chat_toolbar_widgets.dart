import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';

/// Selection toolbar for chat messages — shows when messages are selected.
/// Displays count, copy, forward, and delete actions.
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    super.key,
    required this.selectedCount,
    required this.onClose,
    required this.onDelete,
    required this.onForward,
    required this.onCopy,
  });

  final int selectedCount;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onForward;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.vibeSurfaceElevated,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 22),
            onPressed: onClose,
          ),
          Text(
            '$selectedCount',
            style: VibeTypography.subtitle.copyWith(
              color: context.vibeTextPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 22),
            onPressed: () {
              HapticFeedback.selectionClick();
              onCopy();
            },
          ),
          IconButton(
            icon: const Icon(Icons.forward_rounded, size: 22),
            onPressed: () {
              HapticFeedback.mediumImpact();
              onForward();
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 22, color: context.vibeError),
            onPressed: () {
              HapticFeedback.mediumImpact();
              onDelete();
            },
          ),
        ],
      ),
    );
  }
}

/// Telegram-style action tile for context menus.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? context.vibeError
        : context.vibeTextPrimary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: VibeSpacing.lg,
          vertical: VibeSpacing.sm + 2,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: VibeSpacing.md),
            Text(
              label,
              style: VibeTypography.body.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
