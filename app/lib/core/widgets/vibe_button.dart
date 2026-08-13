import 'package:flutter/material.dart';

import '../theme/vibe_animations.dart';
import '../theme/vibe_colors.dart';
import '../theme/vibe_spacing.dart';
import '../theme/vibe_theme.dart';
import '../theme/vibe_typography.dart';

enum VibeButtonType { primary, secondary, ghost, outline }

/// 8.2.1: пресеты высоты по DESIGN_SYSTEM (56 / 44 / 36).
enum VibeButtonSize {
  l(56),
  m(44),
  s(36);

  const VibeButtonSize(this.height);

  final double height;
}

/// Кнопка Vibe v2: градиент, свечение, пружинное нажатие, ripple.
class VibeButton extends StatefulWidget {
  const VibeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = VibeButtonType.primary,
    this.icon,
    this.expand = true,
    this.height,
    this.size = VibeButtonSize.m,
  });

  final String label;
  final VoidCallback? onPressed;
  final VibeButtonType type;
  final IconData? icon;
  final bool expand;
  final double? height;
  final VibeButtonSize size;

  @override
  State<VibeButton> createState() => _VibeButtonState();
}

class _VibeButtonState extends State<VibeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final primary = widget.type == VibeButtonType.primary;

    final decoration = switch (widget.type) {
      VibeButtonType.primary => BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: VibeColors.brandGradient,
          ),
          borderRadius: BorderRadius.circular(VibeRadius.button),
          boxShadow: enabled ? [VibeShadows.glowPrimary] : const [],
        ),
      VibeButtonType.secondary => BoxDecoration(
          color: context.vibeSurfaceHigh,
          borderRadius: BorderRadius.circular(VibeRadius.button),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      VibeButtonType.outline => BoxDecoration(
          borderRadius: BorderRadius.circular(VibeRadius.button),
          border: Border.all(color: context.vibePrimary, width: 1.5),
        ),
      VibeButtonType.ghost => BoxDecoration(
          borderRadius: BorderRadius.circular(VibeRadius.button),
        ),
    };

    final fg = switch (widget.type) {
      VibeButtonType.primary => Colors.white,
      VibeButtonType.secondary => context.vibeTextPrimary,
      VibeButtonType.ghost => context.vibePrimary,
      VibeButtonType.outline => context.vibePrimary,
    };

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: VibeAnimations.pulse,
      curve: Curves.easeOut,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTap: enabled ? widget.onPressed : null,
          child: Container(
            height: widget.height ?? widget.size.height,
            width: widget.expand ? double.infinity : null,
            decoration: decoration,
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(VibeRadius.button),
              child: InkWell(
                borderRadius: BorderRadius.circular(VibeRadius.button),
                splashColor: primary
                    ? Colors.white.withValues(alpha: 0.18)
                    : context.vibePrimary.withValues(alpha: 0.14),
                highlightColor: primary
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.transparent,
                onTap: enabled ? widget.onPressed : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: VibeSpacing.xl,
                  ),
                  child: Row(
                    mainAxisSize:
                        widget.expand ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 20, color: fg),
                        const SizedBox(width: VibeSpacing.sm),
                      ],
                      Text(
                        widget.label,
                        style:
                            VibeTypography.button.copyWith(color: fg),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}