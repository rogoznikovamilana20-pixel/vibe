import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Глобальное хранилище фото профиля «моего» аккаунта.
/// Подписчики (ValueListenableBuilder) получают байты своего аватара.
class ProfileAvatar {
  ProfileAvatar._();

  static const _fileName = 'my_avatar.png';

  static final ValueNotifier<Uint8List?> myPhoto =
      ValueNotifier<Uint8List?>(null);

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  /// Загрузить аватар при старте приложения.
  static Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        myPhoto.value = await f.readAsBytes();
      }
    } catch (_) {}
  }

  /// Сохранить новый аватар и оповестить подписчиков.
  static Future<void> save(Uint8List bytes) async {
    final f = await _file();
    await f.writeAsBytes(bytes, flush: true);
    myPhoto.value = bytes;
  }

  /// Удалить аватар (вернуть к градиенту с инициалами).
  static Future<void> remove() async {
    final f = await _file();
    if (!await f.exists()) {
      myPhoto.value = null;
      return;
    }
    try {
      await f.delete();
    } catch (_) {}
    myPhoto.value = null;
  }
}