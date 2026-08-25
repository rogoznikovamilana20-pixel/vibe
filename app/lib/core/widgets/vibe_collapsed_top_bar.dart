import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/vibe_spacing.dart';
import '../theme/vibe_theme.dart';

/// Компактная морозная шапка, которая «вплывает» поверх контента, когда
/// большой заголовок коллапсирует при скролле (как в Telegram).
/// Контент, проезжающий под баром, деликатно подмораживается блюром.
class VibeCollapsedTopBar extends StatelessWidget {
  const VibeCollapsedTopBar({
    super.key,
    required this.progress,
    this.leading,
    required this.title,
    this.actions = const [],
    this.blur = 10,
    this.opacity = 0.92,
    this.height = 60,
    this.floating = true,
  });

  /// 0..1 — насколько лента прокручена (0: бар спрятан).
  final double progress;

  final Widget? leading;
  final Widget title;
  final List<Widget> actions;

  final double blur;
  final double opacity;
  final double height;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      builder: (context, p, child) => Opacity(opacity: p, child: child),
      child: SizedBox(
        height: height,
        child: _buildSurface(
          context,
          child: Row(
            children: [
              const SizedBox(width: VibeSpacing.sm),
              if (leading != null) ...[
                leading!,
                const SizedBox(width: VibeSpacing.md),
              ],
              Expanded(child: title),
              for (final a in actions)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: a,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSurface(BuildContext context, {required Widget child}) {
    if (!floating) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(VibeRadius.bottomSheet),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: context.vibeGlass.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(VibeRadius.bottomSheet),
            border: Border.all(color: context.vibeGlassBorder),
            boxShadow: [context.vibeGlassShadow],
          ),
          child: child,
        ),
      ),
    );
  }
}
