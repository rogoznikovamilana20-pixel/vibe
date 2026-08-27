import 'package:flutter/material.dart';

import '../theme/vibe_animations.dart';
import '../theme/vibe_colors.dart';
import '../theme/vibe_theme.dart';

/// 8.2.2: фирменная иконокнопка. Hit-target 48×48 (accessibility),
/// при нажатии сжимается до 86%, ripple по теме.
class VibeIconButton extends StatefulWidget {
  const VibeIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.tooltip,
    this.iconSize = 20,
    this.color,
    this.backgroundColor,
    this.hitTarget = 48,
    this.heroTag,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final double iconSize;
  final Color? color;

  /// Подложка круглой кнопки (null — прозрачная).
  final Color? backgroundColor;
  final double hitTarget;

  /// Для Hero-тегов навигации (назад в стеклянной шапке).
  final Object? heroTag;

  @override
  State<VibeIconButton> createState() => _VibeIconButtonState();
}

class _VibeIconButtonState extends State<VibeIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final fg = widget.color ?? context.vibeTextPrimary;
    final bg = widget.backgroundColor;

    final button = AnimatedScale(
      scale: _pressed ? 0.86 : 1.0,
      duration: VibeAnimations.micro,
      curve: Curves.easeOut,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? widget.onPressed : null,
            onLongPress: widget.onLongPress,
            splashColor: context.vibePrimary.withValues(alpha: 0.16),
            highlightColor: Colors.transparent,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: () => setState(() => _pressed = false),
            child: SizedBox(
              width: widget.hitTarget,
              height: widget.hitTarget,
              child: Icon(widget.icon, size: widget.iconSize, color: fg),
            ),
          ),
        ),
      ),
    );

    final result = widget.tooltip == null
        ? button
        : Tooltip(message: widget.tooltip!, child: button);
    final tag = widget.heroTag;
    return tag == null ? result : Hero(tag: tag, child: result);
  }
}

/// 8.2.3: фирменный FAB — градиент, свечение, сжатие 86% при нажатии.
class VibeFab extends StatefulWidget {
  const VibeFab({super.key, required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  State<VibeFab> createState() => _VibeFabState();
}

class _VibeFabState extends State<VibeFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return AnimatedScale(
      scale: _pressed ? 0.86 : 1.0,
      duration: VibeAnimations.micro,
      curve: Curves.easeOut,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: VibeColors.brandGradient,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [VibeShadows.floating],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? widget.onPressed : null,
            splashColor: Colors.white.withValues(alpha: 0.22),
            highlightColor: Colors.white.withValues(alpha: 0.10),
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: () => setState(() => _pressed = false),
            child: Icon(widget.icon, size: 26, color: Colors.white),
          ),
        ),
      ),
    );
  }
}