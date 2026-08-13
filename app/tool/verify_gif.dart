import 'dart:io';
import 'dart:typed_data';

// Проверка LZW-потока сгенерированных GIF: декодирует каждый кадр
  // и сверяет размер с ожидаемым (w*h).
void main(List<String> args) {
  final path = args.isEmpty ? 'assets/gifs/gif1.gif' : args.first;
  final bytes = File(path).readAsBytesSync();
  var p = 0;
  String ascii() => String.fromCharCodes(bytes.sublist(p, p + 6));
  if (ascii() != 'GIF89a') {
    print('BAD HEADER');
    return;
  }
  p += 6;
  final w = _le16(bytes, p);
  final h = _le16(bytes, p + 2);
  final packed = bytes[p + 4];
  final gctSize = 1 << ((packed & 7) + 1);
  p += 7;
  p += gctSize * 3;
  print('size=$w x $h gct=$gctSize');
  var frame = 0;
  var guard = 0;
  while (p < bytes.length && guard++ < 40) {
    final b = bytes[p];
    if (b == 0x3B) {
      print('TRAILER ok');
      return;
    }
    if (b == 0x21) {
      p += 1;
      final block = bytes[p];
      p++;
      if (block == 0xFF) {
        p += 1 + bytes[p];
        while (bytes[p] != 0) {
          p += 1 + bytes[p];
        }
        p++;
      } else if (block == 0xF9) {
        p += 1 + 4 + 1;
      } else {
        p += 1 + block;
        while (bytes[p] != 0) {
          p += 1 + bytes[p];
        }
        p++;
      }
      continue;
    }
    if (b != 0x2C) {
      print('UNEXPECTED byte 0x${b.toRadixString(16)} at $p');
      return;
    }
    p += 10; // descriptor: 2C + x,y,w,h (2x4) + packed (1)
    final minCode = bytes[p];
    p++;
    print('frame=$frame lzwMin=$minCode');
    final data = <int>[];
    while (bytes[p] != 0) {
      final n = bytes[p];
      data.addAll(bytes.sublist(p + 1, p + 1 + n));
      p += 1 + n;
    }
    p++; // terminator
    final pixels = _lzwDecode(minCode, data);
    if (pixels == null) {
      print('LZW DECODE FAILED');
      return;
    }
    print('decoded=${pixels.length} expected=${w * h} '
        'min=${_min(pixels)} max=${_max(pixels)} dataLen=${data.length}');
    frame++;
  }
}

Uint8List? _lzwDecode(int minCodeSize, List<int> data) {  // Классический GIF-декодер (как giflib): битовый буфер + ранний CLEAR.
  final clearCode = 1 << minCodeSize;
  final eoiCode = clearCode + 1;
  final out = BytesBuilder();
  var buf = 0;
  var bitCount = 0;
  var pos = 0;
  var codeSize = minCodeSize + 1;
  var next = clearCode + 2;
  List<int>? prev;
  final dict = <int, List<int>>{};

  int? readCode() {
    while (bitCount < codeSize) {
      if (pos >= data.length) return null;
      buf |= data[pos++] << bitCount;
      bitCount += 8;
    }
    final code = buf & ((1 << codeSize) - 1);
    buf >>= codeSize;
    bitCount -= codeSize;
    return code;
  }

  final trace = <String>[];
  var why = 'eoi';
  var codeCount = 0;
  while (true) {
    final code = readCode();
    if (code == null) {
      why = 'end-of-data';
      break;
    }
    if (code == eoiCode) break;
    codeCount++;
    if (code == clearCode) {
      trace.add('[$code:CLEAR]');
      dict.clear();
      next = clearCode + 2;
      codeSize = minCodeSize + 1;
      prev = null;
      continue;
    }
    List<int> entry;
    if (code < clearCode) {
      entry = [code];
    } else if (dict.containsKey(code)) {
      entry = dict[code]!;
    } else if (code == next) {
      entry = [...prev!, prev!.first];
    } else {
      print('  FAIL code=$code next=$next codeSize=$codeSize pos=$pos '
          'buf=${buf.toRadixString(2)} bitCount=$bitCount');
      return null;
    }
    if (trace.length < 24) trace.add('$code');
    out.add(entry);
    if (prev != null && next < 4096) {
      dict[next++] = [...prev!, entry.first];
      if (next == (1 << codeSize) && codeSize < 12) codeSize++;
    }
    prev = entry;
  }
  print('  stop=$why pos=$pos dataLen=${data.length} codes=$codeCount codeSize=$codeSize');
  print('  firstCodes=${trace.take(24).join(',')}');
  return Uint8List.fromList(out.takeBytes());
}

int _le16(Uint8List b, int p) => b[p] | (b[p + 1] << 8);

int _min(List<int> l) => l.reduce((a, b) => a < b ? a : b);
int _max(List<int> l) => l.reduce((a, b) => a > b ? a : b);