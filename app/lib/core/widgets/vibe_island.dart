import 'package:flutter/material.dart';

import '../theme/vibe_animations.dart';
import '../theme/vibe_colors.dart';
import '../theme/vibe_spacing.dart';
import '../theme/vibe_theme.dart';

/// «Остров»: лёгкая полупрозрачная подложка с радиусом и тонкой рамкой —
/// мягкая структура списков без резких карточек. Работает в обеих темах.
///
/// Material-слой отделяет ink-эффекты дочерних ListTile от DecoratedBox,
/// иначе при перерисовке сыплются assertion'ы и срезается ripple.
class VibeIsland extends StatelessWidget {
  const VibeIsland({
    super.key,
    required this.child,
    this.selected = false,
  });

  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeSpacing.lg,
        vertical: VibeSpacing.xs,
      ),
      child: AnimatedContainer(
        duration: VibeAnimations.pulse,
        curve: VibeAnimations.standard,
        decoration: BoxDecoration(
          color: selected
              ? context.vibePrimary.withValues(alpha: 0.12)
              : context.isDarkMode
              ? VibeColors.surfaceElevatedDark.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(VibeRadius.card),
          border: Border.all(
            color: selected
                ? context.vibePrimary.withValues(alpha: 0.40)
                : context.vibeBorder.withValues(
                    alpha: context.isDarkMode ? 0.55 : 0.65,
                  ),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      ),
    );
  }
}
