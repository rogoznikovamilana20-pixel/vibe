import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/vibe_theme.dart';

/// Мягкая «бесшовная» морозная полоса у верхней кромки экрана: почти
/// незаметно подмораживает контент, проходящий под верхним баром, и плавно
/// растворяется градиентом — без видимых границ.
class VibeTopFrost extends StatelessWidget {
  const VibeTopFrost({
    super.key,
    this.height = 84,
    this.blur = 9,
    this.maxAlpha = 0.16,
  });

  final double height;
  final double blur;
  final double maxAlpha;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final tint = isDark ? const Color(0x0A0B1A00) : const Color(0xFFFFFFFF);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 1.0],
              colors: [
                tint.withValues(alpha: maxAlpha),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}