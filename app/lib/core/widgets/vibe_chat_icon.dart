import 'package:flutter/material.dart';

/// Кастомная иконка «Чаты»: речевой пузырь с хвостиком и тремя точками
/// (в стиле TG). Заполненный вариант — для активной вкладки, контурный —
/// для неактивной и подписей.
class VibeChatIcon extends StatelessWidget {
  const VibeChatIcon({
    super.key,
    this.size = 24,
    this.color,
    this.filled = false,
  });

  final double size;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ChatIconPainter(
        color: color ?? Colors.grey,
        filled: filled,
      ),
    );
  }
}

class _ChatIconPainter extends CustomPainter {
  const _ChatIconPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.09;

    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Тело пузыря: скруглённый прямоугольник, чуть уже ширины холста.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.02, h * 0.14, w * 0.96, h * 0.68),
      Radius.circular(w * 0.30),
    );
    canvas.drawRRect(body, paint);

    // Хвостик пузыря — слева снизу.
    final tail = Path()
      ..moveTo(w * 0.22, h * 0.72)
      ..lineTo(w * 0.10, h * 0.94)
      ..lineTo(w * 0.40, h * 0.76)
      ..close();
    if (filled) {
      canvas.drawPath(tail, paint);
    } else {
      canvas.drawPath(
        tail,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Три точки внутри (в заполненном варианте — под цвет фона).
    final dotPaint = Paint()
      ..color = filled ? Colors.white : color
      ..style = PaintingStyle.fill;
    final dotR = w * 0.075;
    final cy = h * 0.46;
    for (var i = 0; i < 3; i++) {
      final cx = w * (0.30 + 0.20 * i);
      canvas.drawCircle(Offset(cx, cy), dotR, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChatIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}