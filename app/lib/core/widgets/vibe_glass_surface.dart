import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/vibe_colors.dart';
import '../theme/vibe_spacing.dart';
import '../theme/vibe_theme.dart';

/// Стеклянная поверхность Vibe: полупрозрачная подложка + блюр + деликатная рамка.
/// Используется везде, где нужны «островные» панели в духе Telegram:
/// пузыри, табы, чипы, карточки компоуза.
class VibeGlassSurface extends StatelessWidget {
  const VibeGlassSurface({
    super.key,
    required this.child,
    this.radius,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(VibeRadius.card),
    ),
    this.blur = VibeBlur.panel,
    this.color,
    this.borderColor,
    this.padding,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;

  /// Радиус в виде одного числа (удобно для пилюль). Приоритетнее [borderRadius].
  final double? radius;

  final BorderRadius borderRadius;
  final double blur;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final shape = radius != null
        ? BorderRadius.circular(radius!)
        : borderRadius;
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: color ?? context.vibeGlass,
          borderRadius: shape,
          border: Border.all(
            color: borderColor ?? context.vibeGlassBorder,
          ),
          boxShadow: [context.vibeGlassShadow],
        ),
        clipBehavior: clipBehavior,
        child: ClipRRect(
          borderRadius: shape,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: padding != null
                ? Padding(padding: padding!, child: child)
                : child,
          ),
        ),
      ),
    );
  }
}