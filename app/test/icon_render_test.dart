// Рендерит иконки приложения Vibe в PNG через Flutter (CustomPainter).
// Запуск: flutter test test/icon_render_test.dart
// Пишет файлы прямо в android/app/src/main/res/mipmap-*/
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _VibeIconPainter extends CustomPainter {
  _VibeIconPainter({required this.background, required this.round});

  final bool background;
  final bool round;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (background) {
      final rect = Offset.zero & size;
      if (round) {
        canvas.save();
        canvas.clipPath(Path()..addOval(rect));
      } else {
        canvas.save();
        canvas.clipPath(
          Path()
            ..addRRect(RRect.fromRectAndRadius(
              rect,
              Radius.circular(w * 0.22),
            )),
        );
      }

      final bg = Paint()
        ..        shader = ui.Gradient.linear(
          Offset(w * 0.15, 0),
          Offset(w * 0.85, h),
          const [
            Color(0xFFB471FF),
            Color(0xFF8B5CF6),
            Color(0xFF5B21B6),
          ],
          const [0.0, 0.5, 1.0],
        );
      canvas.drawRect(rect, bg);

      final glow = Paint()
        ..shader = ui.Gradient.radial(
          Offset(w * 0.5, h * 0.12),
          w * 0.6,
          [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
        );
      canvas.drawRect(rect, glow);

      final depth = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.55),
          Offset(0, h),
          [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.28),
          ],
        );
      canvas.drawRect(rect, depth);

      canvas.restore();
    }

    final stroke = w * 0.105;
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final halo = Paint()
      ..color = const Color(0xFF5B21B6).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path()
      ..moveTo(w * 0.33, h * 0.30)
      ..lineTo(w * 0.50, h * 0.675)
      ..lineTo(w * 0.67, h * 0.30);

    canvas.drawPath(path, halo);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _VibeIconPainter old) =>
      background != old.background || round != old.round;
}

Future<void> _render(
  WidgetTester tester, {
  required double size,
  required bool background,
  required bool round,
  required String path,
}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(Size.square(size));
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: CustomPaint(
        size: Size.square(size),
        painter: _VibeIconPainter(background: background, round: round),
      ),
    ),
  );
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  final data = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  File(path).writeAsBytesSync(data!.buffer.asUint8List(), flush: true);
  await _assertPixels(image!, size,
      tester: tester, background: background, round: round);
  await tester.binding.setSurfaceSize(null);
}

Future<void> _assertPixels(
  ui.Image image,
  double size, {
  required WidgetTester tester,
  required bool background,
  required bool round,
}) async {
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  final bytes = data!.buffer.asUint8List();

  int px(double fx, double fy) {
    final x = (size * fx).round();
    final y = (size * fy).round();
    final i = (y * image.width + x) * 4;
    return (bytes[i] << 24) | (bytes[i + 1] << 16) |
        (bytes[i + 2] << 8) | bytes[i + 3];
  }

  final vR = (px(0.50, 0.675) >> 24) & 0xFF; // центр линии V
  final vG = (px(0.50, 0.675) >> 16) & 0xFF;
  final vB = (px(0.50, 0.675) >> 8) & 0xFF;
  expect(vR > 240 && vG > 240 && vB > 240, isTrue,
      reason: 'центр V должен быть белым');

  if (background) {
    // Для круглой иконки угол (0.08, 0.08) вне овала-клипа — сэмплим
    // верх-центр, который гарантированно внутри фигуры.
    final fx = round ? 0.5 : 0.08;
    final r = (px(fx, 0.08) >> 24) & 0xFF;
    final b = (px(fx, 0.08) >> 8) & 0xFF;
    expect(b > r && px(0.50, 0.08) != 0, isTrue,
        reason: 'фон должен быть фиолетовым');
  } else {
    expect(px(0.03, 0.03) & 0xFF, 0,
        reason: 'у прозрачного фона alpha = 0');
  }
}

void main() {
  testWidgets('рендер иконок в res/mipmap', (tester) async {
    const sizes = {
      'mdpi': 48.0,
      'hdpi': 72.0,
      'xhdpi': 96.0,
      'xxhdpi': 144.0,
      'xxxhdpi': 192.0,
    };
    const base = 'android/app/src/main/res';

    for (final e in sizes.entries) {
      await _render(
        tester,
        size: e.value,
        background: true,
        round: false,
        path: '$base/mipmap-${e.key}/ic_launcher.png',
      );
      await _render(
        tester,
        size: e.value,
        background: true,
        round: true,
        path: '$base/mipmap-${e.key}/ic_launcher_round.png',
      );
    }

    const foregroundSizes = {
      'mdpi': 108.0,
      'hdpi': 162.0,
      'xhdpi': 216.0,
      'xxhdpi': 324.0,
      'xxxhdpi': 432.0,
    };
    for (final e in foregroundSizes.entries) {
      await _render(
        tester,
        size: e.value,
        background: false,
        round: false,
        path: '$base/mipmap-${e.key}/ic_launcher_foreground.png',
      );
    }
  });
}