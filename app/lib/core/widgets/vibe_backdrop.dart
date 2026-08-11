import 'package:flutter/material.dart';

import '../theme/vibe_colors.dart';
import '../theme/vibe_theme.dart';
import 'vibe_icons.dart';

/// Глубинный фон всего приложения: единое полотно, которое лежит «в самом низу»
/// и просвечивает под стеклянными капсулами, барами и контентом вкладок.
/// Мягкие свечения + градиент — чтобы при скролле контент «уплывал» под блюр
/// без резких обрывов, как в Telegram.
class VibeBackdrop extends StatelessWidget {
  const VibeBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = context.vibeBackground;
    final isDark = context.isDarkMode;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bg,
                  isDark ? const Color(0xFF141127) : const Color(0xFFECE9F7),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -160,
          right: -80,
          child: VibeGlowBlob(
            size: 400,
            color: context.vibePrimary.withValues(
              alpha: isDark ? 0.07 : 0.05,
            ),
          ),
        ),
        Positioned(
          top: 280,
          left: -140,
          child: VibeGlowBlob(
            size: 360,
            color: VibeColors.workBlue.withValues(
              alpha: isDark ? 0.05 : 0.03,
            ),
          ),
        ),
        Positioned(
          bottom: -180,
          left: 60,
          child: VibeGlowBlob(
            size: 440,
            color: VibeColors.vivid.withValues(
              alpha: isDark ? 0.05 : 0.03,
            ),
          ),
        ),
      ],
    );
  }
}