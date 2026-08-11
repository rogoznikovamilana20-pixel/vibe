import 'package:flutter/material.dart';

import '../theme/vibe_colors.dart';

/// Фирменный логотип Vibe для иконок приложения: глубокий тёмный фон
/// с фирменным свечением и энерго-орбом с молнией.
///
/// Параметр [adaptive] рисует только «безопасную» центральную зону
/// (для foreground адаптивных иконок Android): прозрачный фон,
/// орб без внешнего кольца — какую бы маску ни накладывал лаунчер,
/// логотип не обрежется.
class VibeAppIcon extends StatelessWidget {
  const VibeAppIcon({
    super.key,
    required this.size,
    this.adaptive = false,
  });

  final double size;
  final bool adaptive;

  @override
  Widget build(BuildContext context) {
    final s = size;

    if (adaptive) {
      return SizedBox(
        width: s,
        height: s,
        child: Center(
          child: _OrbCore(adaptive: true, core: s * 0.76, bolt: s * 0.34),
        ),
      );
    }

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1B1437),
                  const Color(0xFF0D0A1E),
                ],
              ),
            ),
          ),
          // Мягкое фиолетовое свечение в верхней части.
          Positioned(
            top: -s * 0.22,
            right: -s * 0.2,
            child: _GlowBlob(
              size: s * 0.9,
              color: VibeColors.vivid.withValues(alpha: 0.22),
            ),
          ),
          // Холодное свечение внизу слева.
          Positioned(
            bottom: -s * 0.25,
            left: -s * 0.15,
            child: _GlowBlob(
              size: s * 0.75,
              color: VibeColors.workBlue.withValues(alpha: 0.14),
            ),
          ),
          Center(
            child: _OrbCore(
              adaptive: true,
              core: s * 0.56,
              bolt: s * 0.25,
            ),
          ),
        ],
      ),
    );
  }
}

/// Энерго-орб: ядро с градиентом, тонкое световое кольцо и молния.
class _OrbCore extends StatelessWidget {
  const _OrbCore({
    this.adaptive = false,
    this.core = 0,
    this.bolt = 0,
  });

  final bool adaptive;
  final double core;
  final double bolt;

  @override
  Widget build(BuildContext context) {
    final halo = core * 0.16;
    return SizedBox(
      width: core * (adaptive ? 0.86 : 1.0),
      height: core * (adaptive ? 0.86 : 1.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Мягкое внешнее свечение ядра.
          Container(
            width: core * 1.05,
            height: core * 1.05,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  VibeColors.vivid.withValues(alpha: 0.28),
                  VibeColors.vivid.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Тонкое световое кольцо.
          Container(
            width: core * 0.92,
            height: core * 0.92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: VibeColors.primaryLight.withValues(alpha: 0.5),
                width: core * 0.012,
              ),
            ),
          ),
          // Ядро с фирменным градиентом.
          Container(
            width: core,
            height: core,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFB06BFF),
                  VibeColors.vivid,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: VibeColors.vivid.withValues(alpha: 0.45),
                  blurRadius: halo,
                  spreadRadius: -halo * 0.35,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: bolt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Мягкое круглое пятно свечения (радиальный градиент от цвета к пустоте).
class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

@override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: color.a * 0.4),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}