import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_colors.dart';
import '../../core/widgets/vibe_icon_font.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_top_bar.dart';
import '../../core/widgets/vibe_glass_surface.dart';

/// Chat list header: top bar with avatar or selection toolbar.
class ChatListHeader extends StatelessWidget {
  const ChatListHeader({
    super.key,
    required this.selectionMode,
    required this.selectedCount,
    required this.onClearSelection,
    required this.onMarkRead,
    required this.onArchive,
    required this.onHide,
    required this.onDelete,
    required this.onDone,
    required this.meAvatar,
    required this.greeting,
    required this.onLock,
    required this.onSearch,
    required this.onMenu,
    required this.lockVisible,
    required this.localizations,
  });

  final bool selectionMode;
  final int selectedCount;
  final VoidCallback onClearSelection;
  final VoidCallback onMarkRead;
  final VoidCallback onArchive;
  final VoidCallback onHide;
  final VoidCallback onDelete;
  final VoidCallback onDone;
  final Widget meAvatar;
  final String greeting;
  final VoidCallback onLock;
  final VoidCallback onSearch;
  final VoidCallback onMenu;
  final bool lockVisible;
  final VibeLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    final l = localizations;
    if (selectionMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          VibeSpacing.lg,
          VibeSpacing.sm,
          VibeSpacing.lg,
          VibeSpacing.sm,
        ),
        child: Row(
          children: [
            Text(
              '$selectedCount',
              style: VibeTypography.subtitle.copyWith(
                color: context.vibePrimary,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onClearSelection,
              icon: const Icon(Icons.clear_rounded),
              tooltip: l.actionClearSelection,
            ),
            IconButton(
              onPressed: onMarkRead,
              icon: const Icon(VibeIcons.checkAll),
              tooltip: l.actionRead,
            ),
            IconButton(
              onPressed: onArchive,
              icon: const Icon(VibeIcons.archive),
              tooltip: l.actionArchive,
            ),
            IconButton(
              onPressed: onHide,
              icon: const Icon(VibeIcons.lock),
              tooltip: l.actionHide,
            ),
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                onDelete();
              },
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l.actionDelete,
            ),
            IconButton(
              onPressed: onDone,
              icon: const Icon(VibeIcons.check),
              tooltip: l.actionDone,
            ),
          ],
        ),
      );
    }
    return VibeTopBar(
      leading: meAvatar,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VibeTypography.caption.copyWith(
              color: context.vibeTextSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 1),
          VibeTopBarTitle(l.chatTitle),
        ],
      ),
      actions: [
        if (lockVisible)
          VibeTopBarIcon(
            icon: VibeIcons.lock,
            tooltip: l.actionLock,
            onTap: onLock,
          ),
        VibeTopBarIcon(
          icon: VibeIcons.search,
          tooltip: l.tooltipSearch,
          onTap: onSearch,
        ),
        VibeTopBarIcon(
          icon: VibeIcons.moreVertical,
          tooltip: l.actionChatsMenu,
          onTap: onMenu,
        ),
      ],
    );
  }
}

/// Archive/hidden chips row in chat list.
class ChatManageRow extends StatelessWidget {
  const ChatManageRow({
    super.key,
    required this.showArchive,
    required this.showHidden,
    required this.archiveCount,
    required this.hiddenCount,
    required this.dndCount,
    required this.onBackToChats,
    required this.onOpenArchive,
    required this.onOpenHidden,
    required this.localizations,
  });

  final bool showArchive;
  final bool showHidden;
  final int archiveCount;
  final int hiddenCount;
  final int dndCount;
  final VoidCallback onBackToChats;
  final VoidCallback onOpenArchive;
  final VoidCallback onOpenHidden;
  final VibeLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    final l = localizations;
    if (showArchive || showHidden) {
      final label = showArchive ? l.archiveTitle : l.hiddenTitle;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
        child: Row(
          children: [
            VibeGlassSurface(
              radius: VibeRadius.badge,
              color: VibeColors.vivid.withValues(alpha: 0.45),
              borderColor: Colors.white.withValues(alpha: 0.25),
              padding: const EdgeInsets.symmetric(
                horizontal: VibeSpacing.md,
                vertical: VibeSpacing.sm - 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    showHidden ? VibeIcons.lock : VibeIcons.archive,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: VibeSpacing.sm),
                  Text(
                    label,
                    style: VibeTypography.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: VibeSpacing.sm),
                  Text(
                    '${showArchive ? archiveCount : hiddenCount}',
                    style: VibeTypography.caption.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Flexible(
              child: GestureDetector(
                onTap: onBackToChats,
                child: Text(
                  l.actionBackToChats,
                  overflow: TextOverflow.ellipsis,
                  style: VibeTypography.bodyMedium.copyWith(
                    color: context.vibePrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final chips = <Widget>[];
    if (archiveCount > 0) {
      chips.add(_manageChip(context, l.archiveTitle, archiveCount, false, onOpenArchive));
    }
    if (hiddenCount > 0) {
      chips.add(_manageChip(context, l.hiddenTitle, hiddenCount, false, onOpenHidden));
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
      child: Row(
        children: [
          ...chips,
          const Spacer(),
          if (dndCount > 0)
            Row(
              children: [
                Icon(
                  Icons.notifications_off_rounded,
                  size: 16,
                  color: context.vibeTextTertiary,
                ),
                const SizedBox(width: VibeSpacing.xs),
                Text(
                  '$dndCount',
                  style: VibeTypography.caption.copyWith(
                    color: context.vibeTextTertiary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _manageChip(
    BuildContext context,
    String label,
    int count,
    bool active,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: VibeSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: VibeGlassSurface(
          radius: VibeRadius.badge,
          blur: VibeBlur.nav,
          color: active ? VibeColors.vivid.withValues(alpha: 0.55) : null,
          borderColor: active
              ? Colors.white.withValues(alpha: 0.25)
              : context.vibeGlassBorder,
          padding: const EdgeInsets.symmetric(
            horizontal: VibeSpacing.md,
            vertical: VibeSpacing.sm - 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                label == localizations.archiveTitle ? VibeIcons.archive : VibeIcons.lock,
                size: 16,
                color: active ? Colors.white : context.vibeTextSecondary,
              ),
              const SizedBox(width: VibeSpacing.xs),
              Text(
                label,
                style: VibeTypography.bodyMedium.copyWith(
                  color: active ? Colors.white : context.vibeTextSecondary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: VibeSpacing.xs),
              Text(
                '$count',
                style: VibeTypography.caption.copyWith(
                  color: active ? Colors.white70 : context.vibeTextTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
