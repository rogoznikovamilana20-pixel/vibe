import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Логотип Vibe: молния в скошенном ромбе с градиентом.
class VibeLogoMark extends StatelessWidget {
  const VibeLogoMark({
    super.key,
    this.size = 64,
    this.color,
    this.gradient = const [Color(0xFF9D5CFF), Color(0xFF7C3AED)],
  });

  final double size;
  final Color? color;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _VibeBoltPainter(color: color, gradient: gradient)),
    );
  }
}

class _VibeBoltPainter extends CustomPainter {
  _VibeBoltPainter({this.color, required this.gradient});
  final Color? color;
  final List<Color> gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);

    // Плашка — скруглённый ромб
    final plate = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: s, height: s),
      Radius.circular(s * 0.22),
    );
    if (color != null) {
      canvas.drawRRect(plate, Paint()..color = color!);
    } else {
      final rect = Rect.fromCenter(center: center, width: s, height: s);
      canvas.drawRRect(
        plate,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ).createShader(rect),
      );
    }

    // Молния
    final bolt = Path();
    final w = s * 0.22;
    final h = s * 0.52;
    final bx = center.dx;
    final top = center.dy - h / 2;
    bolt.moveTo(bx + w * 0.7, top);
    bolt.lineTo(bx - w * 0.85, center.dy + h * 0.05);
    bolt.lineTo(bx - w * 0.05, center.dy + h * 0.05);
    bolt.lineTo(bx - w * 0.7, top + h);
    bolt.lineTo(bx + w * 0.85, center.dy - h * 0.05);
    bolt.lineTo(bx + w * 0.05, center.dy - h * 0.05);
    bolt.close();

    canvas.drawPath(bolt, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_VibeBoltPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.gradient != gradient;
}

/// Декоративный градиентный овал для фона (размытое пятно).
class VibeGlowBlob extends StatelessWidget {
  const VibeGlowBlob({
    super.key,
    this.size = 240,
    this.color = const Color(0x338B5CF6),
    this.offset = Offset.zero,
  });

  final double size;
  final Color color;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: size,
          height: size,
decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
        ),
      ),
    );
  }
}

/// Скруглённый N-угольник (для «нееоновых» плашек).
class VibeHexPath extends StatelessWidget {
  const VibeHexPath({super.key, this.size = 48, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _VibeHexPainter(color));
  }
}

class _VibeHexPainter extends CustomPainter {
  _VibeHexPainter(this.color);
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final p = Offset(c.dx + s * math.cos(angle), c.dy + s * math.sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color ?? Colors.white);
  }

  @override
  bool shouldRepaint(_VibeHexPainter oldDelegate) => oldDelegate.color != color;
}