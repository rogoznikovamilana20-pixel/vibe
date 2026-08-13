import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:vibe_app/core/services/media_cache.dart';

void main() {
  Uint8List utf8Bytes(String s) => Uint8List.fromList(s.codeUnits);

  late Directory dir;
  late int fetchCalls;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vibe_media_cache_test');
    fetchCalls = 0;
    MediaCache.instance.dirOverride = () async => dir;
    MediaCache.instance.fetcher = (url) async {
      fetchCalls++;
      return Uint8List.fromList(utf8Bytes(url));
    };
  });

  tearDown(() async {
    await MediaCache.instance.debugClear();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('промах: скачивает и пишет файл в кэш', () async {
    final file = await MediaCache.instance.cachedFile('https://a/1.png');
    expect(file, isNotNull);
    expect(fetchCalls, 1);
    expect(await file!.exists(), isTrue);
    expect(await file.readAsBytes(), utf8Bytes('https://a/1.png'));
  });

  test('попадание: второй вызов не качает повторно', () async {
    await MediaCache.instance.cachedFile('https://a/2.png');
    final file = await MediaCache.instance.cachedFile('https://a/2.png');
    expect(file, isNotNull);
    expect(fetchCalls, 1);
  });

  test('сбой сети: null, файл не создаётся, без исключений', () async {
    MediaCache.instance.fetcher = (_) async => throw Exception('net down');
    final file = await MediaCache.instance.cachedFile('https://a/3.png');
    expect(file, isNull);
    final entries = dir.existsSync() ? dir.listSync() : <FileSystemEntity>[];
    expect(entries, isEmpty);
  });

  test('разные URL — разные файлы (ключ sha1)', () async {
    final f1 = await MediaCache.instance.cachedFile('https://a/x.png');
    final f2 = await MediaCache.instance.cachedFile('https://a/y.png');
    expect(f1!.path, isNot(f2!.path));
    expect(fetchCalls, 2);
  });

  test('debugClear: после очистки качает заново', () async {
    await MediaCache.instance.cachedFile('https://a/5.png');
    expect(fetchCalls, 1);
    await MediaCache.instance.debugClear();
    final file = await MediaCache.instance.cachedFile('https://a/5.png');
    expect(file, isNotNull);
    expect(fetchCalls, 2);
  });
}
