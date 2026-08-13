import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Генератор анимированных GIF для таба «Гифки» (8.3.4).
/// Рисует 64x64 кадры: градиентный фон + движущийся шар с бликом.
/// Валидный GIF89a: GCT 256, NETSCAPE loop, LZW (min code size 8).
void main() {
  const pairs = [
    ('7C4DFF', '2A1B5E'),
    ('4DD0E1', '0A2E38'),
    ('69F0AE', '0B3D2E'),
    ('FFB74D', '5C2E0B'),
    ('F48FB1', '5C0B2E'),
    ('FF8A65', '5C1E0B'),
    ('A5D6FF', '0B2A5C'),
    ('CE93D8', '2E0B5C'),
    ('FFF59D', '5C520B'),
    ('81C784', '0B3D16'),
  ];
  final outDir = Directory('assets/gifs');
  outDir.createSync(recursive: true);
  for (var i = 0; i < pairs.length; i++) {
    final file = File('${outDir.path}/gif${i + 1}.gif');
    file.writeAsBytesSync(_gif(pairs[i].$1, pairs[i].$2));
    stdout.writeln('${file.path}: ${file.lengthSync()} bytes');
  }
}

Uint8List _gif(String bgHex1, String bgHex2) {
  const w = 64, h = 64, frames = 6;
  final (r1, g1, b1) = _rgb(bgHex1);
  final (r2, g2, b2) = _rgb(bgHex2);
  // Палитра: 0..15 — вертикальный градиент фона, 16 — шар, 17 — блик.
  final palette = BytesBuilder();
  for (var i = 0; i < 16; i++) {
    final t = i / 15;
    palette.addByte(r1 + ((r2 - r1) * t).round());
    palette.addByte(g1 + ((g2 - g1) * t).round());
    palette.addByte(b1 + ((b2 - b1) * t).round());
  }
  palette.add([0xFF, 0xFF, 0xFF]); // 16: шар (белый)
  palette.add([0xE8, 0xEA, 0xF2]); // 17: блик
  for (var i = 18; i < 256; i++) {
    palette.add([0, 0, 0]);
  }

  final out = BytesBuilder();
  out.add('GIF89a'.codeUnits);
  _le16(out, w);
  _le16(out, h);
  out.add([0x87, 0, 0]); // GCT 256, bg 0
  out.add(palette.takeBytes());
  // NETSCAPE loop: бесконечный.
  out.add([
    0x21, 0xFF, 0x0B, // application extension
    0x4E, 0x45, 0x54, 0x53, 0x43, 0x41, 0x50, 0x45, 0x32, 0x2E, 0x30, // NETSCAPE2.0
    0x03, 0x01, 0x00, 0x00, 0x00,
  ]);

  final rng = math.Random(42 + palette.length);
  for (var f = 0; f < frames; f++) {
    final t = f / frames * 2 * math.pi;
    final cx = 32 + 22 * math.cos(t);
    final cy = 32 + 22 * math.sin(t);
    final r = 11 + (rng.nextDouble() - 0.5) * 4;
    // Кадр: индекс палитры для каждого пикселя.
    final pixels = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final dx = x - cx, dy = y - cy;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= r) {
          pixels[y * w + x] = dist < r * 0.55 ? 17 : 16;
        } else {
          pixels[y * w + x] = ((y * 15) / (h - 1)).round();
        }
      }
    }
    // Graphic Control Extension: delay 8 (80 мс), без прозрачности.
    out.add([0x21, 0xF9, 0x04, 0x00, 0x08, 0x00, 0x00, 0x00]);
    // Image Descriptor: полный кадр, без локальной палитры.
    out.add([0x2C]);
    _le16(out, 0);
    _le16(out, 0);
    _le16(out, w);
    _le16(out, h);
    out.add([0x00]);
    // LZW: min code size 8; кодер сам пишет CLEAR/EOI и строит словарь.
    out.add([8]);
    final bits = _pack9(pixels.toList(), 8);
    for (var i = 0; i < bits.length; i += 255) {
      final chunk = bits.sublist(i, math.min(i + 255, bits.length));
      out.addByte(chunk.length);
      out.add(chunk);
    }
    out.addByte(0);
  }
  out.addByte(0x3B); // Trailer
  return out.takeBytes();
}

/// LZW-кодер — дословный порт giflib (egif_lib.c, EGifCompressLine):
/// словарь пар (prefix<<8)|pixel, вставка слова ПОСЛЕ вывода кода
/// (RunningCode++), CLEAR при переполнении ПОСЛЕ вывода кода,
/// расширение ширины в writeCode по правилу RunningCode >= MaxCode1.
Uint8List _pack9(List<int> pixels, int minCodeSize) {
  final out = BytesBuilder();
  var acc = 0;
  var bits = 0;
  var width = minCodeSize + 1;
  var maxCode = 1 << width;
  var next = (1 << minCodeSize) + 2;
  final clearCode = 1 << minCodeSize;
  final eoiCode = clearCode + 1;
  final dict = <int, int>{};

  void writeCode(int code) {
    acc |= code << bits;
    bits += width;
    while (bits >= 8) {
      out.addByte(acc & 0xFF);
      acc >>= 8;
      bits -= 8;
    }
    if (next >= maxCode && code <= 4095) {
      maxCode = 1 << ++width;
    }
  }

  var pre = pixels.first;
  for (var i = 1; i < pixels.length; i++) {
    final k = pixels[i];
    final key = (pre << 8) | k;
    final found = dict[key];
    if (found != null) {
      pre = found;
      continue;
    }
    writeCode(pre);
    pre = k;
    if (next >= 4096) {
      writeCode(clearCode);
      next = (1 << minCodeSize) + 2;
      width = minCodeSize + 1;
      maxCode = 1 << width;
      dict.clear();
    } else {
      dict[key] = next++;
    }
  }
  writeCode(pre);
  writeCode(eoiCode);
  if (bits > 0) out.addByte(acc & 0xFF);
  return out.takeBytes();
}

void _le16(BytesBuilder b, int v) {
  b.addByte(v & 0xFF);
  b.addByte((v >> 8) & 0xFF);
}

(int, int, int) _rgb(String hex) => (
      int.parse(hex.substring(0, 2), radix: 16),
      int.parse(hex.substring(2, 4), radix: 16),
      int.parse(hex.substring(4, 6), radix: 16),
    );
