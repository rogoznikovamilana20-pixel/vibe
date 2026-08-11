import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/core/widgets/vibe_app_icon.dart';

/// Разовые генераторы иконок: рисует логотип Vibe в Flutter
/// и сохраняет PNG в системные каталоги ресурсов.
/// Запуск: flutter test test/tools/render_icons_test.dart

Future<void> render(
  WidgetTester tester,
  int px, {
  required String outPath,
  bool adaptive = false,
}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(Size(px.toDouble(), px.toDouble()));
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: SizedBox(
          width: px.toDouble(),
          height: px.toDouble(),
          child: VibeAppIcon(size: px.toDouble(), adaptive: adaptive),
        ),
      ),
    ),
  );
  await tester.pump();
  final rb = key.currentContext!.findRenderObject() as RenderRepaintBoundary?;
  if (rb == null) return;
  final image = await tester.runAsync(() => rb.toImage(pixelRatio: 1.0));
  if (image == null) return;
  final byteData =
      await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  image.dispose();
  if (byteData == null) return;
  final file = File(outPath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(byteData.buffer.asUint8List());
  await tester.binding.setSurfaceSize(null);
}

void main() {
  testWidgets('Render Vibe app icons', (tester) async {
    final base = Directory.current.path;
    final res = '$base/android/app/src/main/res';
    const legacySizes = {
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };
    const foregroundSizes = {
      'mipmap-mdpi': 108,
      'mipmap-hdpi': 162,
      'mipmap-xhdpi': 216,
      'mipmap-xxhdpi': 324,
      'mipmap-xxxhdpi': 432,
    };

    for (final e in legacySizes.entries) {
      await render(tester, e.value,
          outPath: '$res/${e.key}/ic_launcher.png');
      await render(tester, e.value,
          outPath: '$res/${e.key}/ic_launcher_round.png');
    }

    for (final e in foregroundSizes.entries) {
      await render(
        tester,
        e.value,
        outPath: '$res/${e.key}/ic_launcher_foreground.png',
        adaptive: true,
      );
    }

    final ios = '$base/ios/Runner/Assets.xcassets/AppIcon.appiconset';
    const iosSizes = <String, int>{
      'Icon-App-20x20@1x.png': 20,
      'Icon-App-20x20@2x.png': 40,
      'Icon-App-20x20@3x.png': 60,
      'Icon-App-29x29@1x.png': 29,
      'Icon-App-29x29@2x.png': 58,
      'Icon-App-29x29@3x.png': 87,
      'Icon-App-40x40@1x.png': 40,
      'Icon-App-40x40@2x.png': 80,
      'Icon-App-40x40@3x.png': 120,
      'Icon-App-60x60@2x.png': 120,
      'Icon-App-60x60@3x.png': 180,
      'Icon-App-76x76@1x.png': 76,
      'Icon-App-76x76@2x.png': 152,
      'Icon-App-83.5x83.5@2x.png': 167,
      'Icon-App-1024x1024@1x.png': 1024,
    };
    for (final e in iosSizes.entries) {
      await render(tester, e.value, outPath: '$ios/${e.key}');
    }
  });
}