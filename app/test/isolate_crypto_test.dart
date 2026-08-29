import 'dart:isolate';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> _hkdfInIsolate(List<int> ikm) async {
  return await Isolate.run(() async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final key = await hkdf.deriveKey(secretKey: SecretKey(ikm), nonce: List.filled(32, 0));
    return await key.extractBytes();
  });
}

void main() {
  test('HKDF in isolate does not block UI (perf)', () async {
    final sw = Stopwatch()..start();
    final out = await _hkdfInIsolate(List.filled(32, 42));
    sw.stop();
    expect(out.length, 32);
    expect(sw.elapsedMilliseconds, lessThan(200));
  });
}
