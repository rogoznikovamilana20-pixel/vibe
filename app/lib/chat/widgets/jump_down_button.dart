import 'package:flutter/material.dart';

import '../../core/theme/vibe_animations.dart';
import '../../core/theme/vibe_theme.dart';

/// Кнопка «прокрутить вниз» с бейджем количества новых сообщений,
/// как в Telegram. Появляется, когда чат прокручен вверх.
class JumpDownButton extends StatelessWidget {
  const JumpDownButton({
    super.key,
    required this.visible,
    required this.badge,
    required this.onTap,
  });

  final bool visible;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1.0 : 0.0,
      duration: VibeAnimations.scaleIn,
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: VibeAnimations.fadeIn,
        child: IgnorePointer(
          ignoring: !visible,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.isDarkMode
                        ? context.vibeSurfaceVariant
                        : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(
                      color: context.vibePrimary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: context.vibeTextPrimary,
                    size: 26,
                  ),
                ),
              ),
              if (badge > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    constraints: const BoxConstraints(minWidth: 20),
                    decoration: BoxDecoration(
                      color: context.vibeError,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
