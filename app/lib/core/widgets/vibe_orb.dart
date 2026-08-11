import 'package:flutter/material.dart';

import '../theme/vibe_colors.dart';

/// Энерго-орб Vibe — фирменный логотип-визуал: градиентное ядро,
/// неоновое свечение и иконка фичи. Заменяет маскота в UI (Вайбик — стикерпак).
class VibeOrb extends StatefulWidget {
  const VibeOrb({
    super.key,
    this.size = 220,
    this.icon = Icons.bolt_rounded,
    this.accent = VibeColors.vivid,
    this.animated = true,
  });

  final double size;
  final IconData icon;
  final Color accent;
  final bool animated;

  @override
  State<VibeOrb> createState() => _VibeOrbState();
}

class _VibeOrbState extends State<VibeOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) {
        final scale = widget.animated ? 1.0 + 0.035 * _breath.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: s,
            height: s,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.accent.withValues(alpha: 0.16),
                        widget.accent.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Container(
                  width: s * 0.68,
                  height: s * 0.68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.accent.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                ),
                Container(
                  width: s * 0.56,
                  height: s * 0.56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(widget.accent, Colors.white, 0.18)!,
                        widget.accent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accent.withValues(alpha: 0.3),
                        blurRadius: s * 0.1,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    color: Colors.white,
                    size: s * 0.26,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
