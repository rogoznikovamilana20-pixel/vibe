import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/vibe_colors.dart';

/// Праздничный конфетти: частицы с гравитацией и вращением.
/// Спавнится с верха экрана (или из точки), живёт ~3 секунды.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.particleCount = 80});

  final int particleCount;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _rand = math.Random(7);
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..forward();
    _particles = List.generate(
      widget.particleCount,
      (_) => _Particle(_rand),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(
              progress: Curves.easeOut.transform(_controller.value),
              particles: _particles,
            ),
          );
        },
      ),
    );
  }
}

class _Particle {
  _Particle(this.rand)
      : x = rand.nextDouble(),
        y = rand.nextDouble() * 0.3,
        speed = 0.35 + rand.nextDouble() * 0.55,
        drift = (rand.nextDouble() - 0.5) * 0.25,
        size = 5 + rand.nextDouble() * 7,
        rotation = rand.nextDouble() * math.pi * 2,
        spin = (rand.nextDouble() - 0.5) * 10,
        color = VibeColors.confettiPalette[
            rand.nextInt(VibeColors.confettiPalette.length)],
        delay = rand.nextDouble() * 0.35;

  final math.Random rand;
  double x;
  double y;
  final double speed;
  final double drift;
  final double size;
  double rotation;
  final double spin;
  final Color color;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.particles});

  final double progress;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final fade = (1 - t) < 0.3 ? (1 - t) / 0.3 : 1.0;
      final x = (p.x + p.drift * t) * size.width;
      final y = (p.y + p.speed * t) * size.height;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.spin * t);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.size,
        height: p.size * (1.2 + math.sin(t * math.pi * 3) * 0.5),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = p.color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
