import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Диск-кэш медиа (5.4): картинки (`vibe_cache/media/<sha1(url)>`)
/// скачиваются один раз и читаются с диска между сессиями.
/// Фетчер и корень кэша подменяемы (в тестах — in-memory фейк).
class MediaCache {
  MediaCache._();
  static final MediaCache instance = MediaCache._();

  static const _dirName = 'media';

  /// Скачивание байтов (в юнит-тестах подменяется фейком).
  Future<Uint8List> Function(String url) fetcher = (url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return res.bodyBytes;
  };

  /// Корень кэша (в тестах — temp-директория).
  Future<Directory> Function() dirOverride = _defaultDir;

  static Future<Directory> _defaultDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}vibe_cache'
      '${Platform.pathSeparator}$_dirName',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _key(String url) => sha1.convert(utf8.encode(url)).toString();

  /// Файл кэша для [url]: существующий — сразу; иначе fetch + запись.
  /// При любом сбое (сеть/диск) возвращает null — вызывающий показывает
  /// плейсхолдер, не ломая UI.
  Future<File?> cachedFile(String url) async {
    try {
      final dir = await dirOverride();
      if (!await dir.exists()) await dir.create(recursive: true);
      final f = File('${dir.path}${Platform.pathSeparator}${_key(url)}');
      if (await f.exists()) return f;
      final bytes = await fetcher(url);
      await f.writeAsBytes(bytes, flush: true);
      return f;
    } catch (_) {
      return null;
    }
  }

  /// Очистка кэша (для тестов).
  Future<void> debugClear() async {
    try {
      final dir = await dirOverride();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
