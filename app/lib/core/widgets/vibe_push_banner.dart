import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../theme/vibe_animations.dart';
import '../theme/vibe_colors.dart';
import '../theme/vibe_spacing.dart';
import '../theme/vibe_theme.dart';
import '../theme/vibe_typography.dart';
import 'vibe_avatar.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Баннер входящего пуша в стиле Vibe: стеклянная панель, аватар,
/// имя + текст, тап по баннеру открывает чат.
class VibePushBanner extends StatelessWidget {
  const VibePushBanner({
    super.key,
    required this.push,
    required this.onTap,
    required this.onDismiss,
  });

  final VibePushEvent? push;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = push;
    return AnimatedSwitcher(
      duration: VibeAnimations.fluid,
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1.2),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: p == null
          ? const SizedBox.shrink()
          : _BannerCard(key: ValueKey(p.id), push: p, onTap: onTap, onDismiss: onDismiss),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    super.key,
    required this.push,
    required this.onTap,
    required this.onDismiss,
  });

  final VibePushEvent push;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.vibeGlass,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.vibeGlassBorder),
              boxShadow: isDark
                  ? const [VibeShadows.floating, VibeShadows.glowStrong]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 24,
                        spreadRadius: 0,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24 - 1),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: VibeBlur.panel,
                  sigmaY: VibeBlur.panel,
                ),
                child: Row(
                  children: [
                    VibeAvatar(name: push.title, size: 46),
                    const SizedBox(width: VibeSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  push.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: VibeTypography.label.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 13,
                                color: Color.lerp(
                                  Theme.of(context).colorScheme.primary,
                                  Colors.white,
                                  0.45,
                                )?.withValues(alpha: 0.9),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            push.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: VibeTypography.caption.copyWith(
                              fontSize: 13,
                              color: context.isDarkMode
                                  ? VibeColors.textSecondaryDark
                                  : VibeColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: VibeSpacing.xs),
                    // Кнопка закрытия: тап не проваливается в карточку.
                    GestureDetector(
                      onTap: onDismiss,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          VibeIcons.close,
                          size: 18,
                          color: VibeColors.textTertiaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}