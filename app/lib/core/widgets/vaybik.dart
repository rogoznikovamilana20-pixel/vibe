import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/vibe_colors.dart';

/// Позы Вайбика.
enum VaybikPose { happy, wave, heart, rocket }

/// Вайбик — маскот Vibe: чёрный круглый пузырёк с неоновой обводкой.
/// Анимации: пульс свечения (energy pulse) + моргание.
class Vaybik extends StatefulWidget {
  const Vaybik({
    super.key,
    this.size = 120,
    this.pose = VaybikPose.happy,
    this.neon = VibeColors.vivid,
    this.animated = true,
  });

  final double size;
  final VaybikPose pose;
  final Color neon;
  final bool animated;

  @override
  State<Vaybik> createState() => _VaybikState();
}

class _VaybikState extends State<Vaybik> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _scheduleBlink();
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 2400 + _rand(2400)));
      if (!mounted) return;
      _blink.forward().then((_) => _blink.reverse());
    }
  }

  int _rand(int max) => DateTime.now().millisecondsSinceEpoch % max;

  @override
  void dispose() {
    _pulse.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _blink]),
      builder: (context, _) {
        final glow = widget.animated
            ? 0.55 + 0.45 * _pulse.value
            : 0.8;
        final blinkValue = _blink.value;
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _VaybikPainter(
            glow: glow,
            blink: blinkValue,
            pose: widget.pose,
            neon: widget.neon,
          ),
        );
      },
    );
  }
}

class _VaybikPainter extends CustomPainter {
  _VaybikPainter({
    required this.glow,
    required this.blink,
    required this.pose,
    required this.neon,
  });

  final double glow;
  final double blink;
  final VaybikPose pose;
  final Color neon;

  static const _twinkleDuration = Duration(milliseconds: 400);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = s * 0.40;
    final bodyColor = const Color(0xFF10101A);
    final neonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.030
      ..strokeCap = StrokeCap.round
      ..color = neon;

    // Неоновое свечение (energy pulse)
    final glowPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05 * glow)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.030
      ..color = neon.withValues(alpha: 0.85);

    // Тело
    canvas.drawCircle(center, radius, Paint()..color = bodyColor);
    canvas.drawCircle(center, radius, glowPaint);
    canvas.drawCircle(center, radius, neonPaint);

    // Блик сверху-слева
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.38, center.dy - radius * 0.42),
      radius * 0.22,
      shine,
    );

    // Руки (зависит от позы)
    _paintArms(canvas, center, radius, s);

    // Глаза
    final eyeW = radius * 0.34;
    final eyeH = radius * (1.0 - 0.35 * blink) * 0.42;
    final eyeDy = center.dy - radius * 0.08;
    final eyeOffsetX = radius * 0.30;

    for (final side in [-1.0, 1.0]) {
      final eyeCenter = Offset(center.dx + side * eyeOffsetX, eyeDy);
      // Белок
      final white = Paint()..color = Colors.white;
      canvas.drawOval(
        Rect.fromCenter(
          center: eyeCenter,
          width: eyeW,
          height: math.max(eyeH, radius * 0.05),
        ),
        white,
      );
      // Зрачок (смотрит вперёд)
      final pupil = Paint()..color = const Color(0xFF1B1030);
      final pupilSize = eyeW * 0.52;
      canvas.drawCircle(
        Offset(eyeCenter.dx, eyeDy + eyeH * 0.08),
        pupilSize,
        pupil,
      );
      // Блик зрачка
      final glint = Paint()..color = Colors.white;
      canvas.drawCircle(
        Offset(eyeCenter.dx - pupilSize * 0.3, eyeDy - pupilSize * 0.3),
        pupilSize * 0.28,
        glint,
      );
    }

    // Рот
    _paintMouth(canvas, center, radius);
  }

  void _paintArms(Canvas canvas, Offset center, double radius, double s) {
    final armPaint = Paint()
      ..color = const Color(0xFF10101A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.060
      ..strokeCap = StrokeCap.round;

    switch (pose) {
      case VaybikPose.wave:
        // Поднятая рука машет
        final phase = (DateTime.now().millisecondsSinceEpoch %
                    _twinkleDuration.inMilliseconds) /
                _twinkleDuration.inMilliseconds *
                math.pi *
                2;
        final waveAngle = math.sin(phase) * 0.35;
        final base = Offset(center.dx + radius * 0.75, center.dy - radius * 0.45);
        final hand = Offset(
          center.dx + radius * 0.95 + math.sin(waveAngle) * radius * 0.15,
          center.dy - radius * 1.15,
        );
        canvas.drawLine(center, base, armPaint);
        canvas.drawLine(base, hand, armPaint);
        canvas.drawCircle(hand, s * 0.045, armPaint);
        // Левая рука — вдоль тела
        canvas.drawLine(
          center,
          Offset(center.dx - radius * 0.8, center.dy + radius * 0.55),
          armPaint,
        );
      case VaybikPose.heart:
        // Обе руки держат сердце
        canvas.drawLine(
          center,
          Offset(center.dx - radius * 0.65, center.dy + radius * 0.35),
          armPaint,
        );
        canvas.drawLine(
          center,
          Offset(center.dx + radius * 0.65, center.dy + radius * 0.35),
          armPaint,
        );
        _paintHeart(
          canvas,
          Offset(center.dx, center.dy + radius * 0.95),
          radius * 0.32,
        );
      case VaybikPose.rocket:
        // Руки по бокам + пламя под ракетой
        canvas.drawLine(
          center,
          Offset(center.dx - radius * 0.8, center.dy + radius * 0.5),
          armPaint,
        );
        canvas.drawLine(
          center,
          Offset(center.dx + radius * 0.8, center.dy + radius * 0.5),
          armPaint,
        );
        _paintFlame(canvas, Offset(center.dx, center.dy + radius * 1.25), radius * 0.5);
      case VaybikPose.happy:
        // Руки вдоль тела
        canvas.drawLine(
          center,
          Offset(center.dx - radius * 0.8, center.dy + radius * 0.55),
          armPaint,
        );
        canvas.drawLine(
          center,
          Offset(center.dx + radius * 0.8, center.dy + radius * 0.55),
          armPaint,
        );
    }
  }

  void _paintMouth(Canvas canvas, Offset center, double radius) {
    final mouthPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.09
      ..strokeCap = StrokeCap.round;

    switch (pose) {
      case VaybikPose.happy:
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(center.dx, center.dy + radius * 0.42),
            width: radius * 0.5,
            height: radius * 0.34,
          ),
          0.2,
          math.pi - 0.4,
          false,
          mouthPaint,
        );
      case VaybikPose.wave:
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(center.dx, center.dy + radius * 0.42),
            width: radius * 0.5,
            height: radius * 0.34,
          ),
          0.2,
          math.pi - 0.4,
          false,
          mouthPaint,
        );
      case VaybikPose.heart:
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(center.dx, center.dy + radius * 0.42),
            width: radius * 0.4,
            height: radius * 0.26,
          ),
          0.2,
          math.pi - 0.4,
          false,
          mouthPaint,
        );
      case VaybikPose.rocket:
        // Удивлённый «о»
        final oPaint = Paint()
          ..color = const Color(0xFF1B1030)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(center.dx, center.dy + radius * 0.45),
          radius * 0.10,
          oPaint,
        );
        canvas.drawCircle(
          Offset(center.dx, center.dy + radius * 0.45),
          radius * 0.10,
          mouthPaint,
        );
    }
  }

  void _paintHeart(Canvas canvas, Offset c, double r) {
    final heartPaint = Paint()
      ..color = VibeColors.error
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(c.dx, c.dy + r * 0.7);
    path.cubicTo(
      c.dx - r * 1.2,
      c.dy + r * 0.1,
      c.dx - r * 0.6,
      c.dy - r * 0.9,
      c.dx,
      c.dy - r * 0.25,
    );
    path.cubicTo(
      c.dx + r * 0.6,
      c.dy - r * 0.9,
      c.dx + r * 1.2,
      c.dy + r * 0.1,
      c.dx,
      c.dy + r * 0.7,
    );
    canvas.drawPath(path, heartPaint);
  }

  void _paintFlame(Canvas canvas, Offset c, double r) {
    final phase = (DateTime.now().millisecondsSinceEpoch %
                _twinkleDuration.inMilliseconds) /
            _twinkleDuration.inMilliseconds *
            math.pi *
            2;
    final flicker = 1.0 + math.sin(phase) * 0.15;
    final flame = Paint()
      ..color = VibeColors.warning
      ..style = PaintingStyle.fill;
    final flameInner = Paint()..color = VibeColors.warningGlow;
    final path = Path();
    path.moveTo(c.dx - r * 0.35, c.dy);
    path.quadraticBezierTo(
      c.dx - r * 0.1,
      c.dy - r * 0.9 * flicker,
      c.dx,
      c.dy - r * 0.5 * flicker,
    );
    path.quadraticBezierTo(
      c.dx + r * 0.1,
      c.dy - r * 0.9 * flicker,
      c.dx + r * 0.35,
      c.dy,
    );
    path.quadraticBezierTo(c.dx, c.dy + r * 0.25, c.dx - r * 0.35, c.dy);
    canvas.drawPath(path, flame);
    canvas.drawCircle(
      Offset(c.dx, c.dy - r * 0.35 * flicker),
      r * 0.12,
      flameInner,
    );
  }

  @override
  bool shouldRepaint(_VaybikPainter oldDelegate) =>
      oldDelegate.glow != glow ||
      oldDelegate.blink != blink ||
      oldDelegate.pose != pose ||
      oldDelegate.neon != neon;
}
