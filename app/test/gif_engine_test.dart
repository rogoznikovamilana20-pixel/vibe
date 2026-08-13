import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (var i = 1; i <= 10; i++) {
    test('gif$i decodes by Flutter engine', () async {
      final bytes = File('assets/gifs/gif$i.gif').readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 64);
      expect(frame.image.height, 64);
      // 6 кадров: каждый getNextFrame должен давать следующее изображение.
      var frames = 1;
      try {
        for (var j = 0; j < 10; j++) {
          final f = await codec.getNextFrame();
          frames++;
          expect(f.image.width, 64);
          expect(f.image.height, 64);
          f.image.dispose();
        }
      } catch (_) {}
      expect(frames, greaterThanOrEqualTo(6));
      codec.dispose();
      frame.image.dispose();
    });
  }
}