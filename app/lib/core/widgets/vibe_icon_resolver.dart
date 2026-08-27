import 'package:flutter/material.dart';

import '../../data/settings_service.dart';
import 'vibe_icon_font.dart';

/// Резолвер иконок по выбранному в [SettingsService.iconPack] набору.
/// `vibe` — фирменные VibeIcons, `material` — Icons.*, `telegram` — TG-стиль (пока = vibe с fallback на material).
abstract final class VibeIconResolver {
  static IconData get send => _r(VibeIcons.send, Icons.send_rounded);
  static IconData get back => _r(VibeIcons.back, Icons.arrow_back_rounded);
  static IconData get edit => _r(VibeIcons.edit, Icons.edit_rounded);
  static IconData get archive => _r(VibeIcons.archive, Icons.archive_rounded);
  static IconData get user => _r(VibeIcons.user, Icons.person_rounded);
  static IconData get group => _r(VibeIcons.group, Icons.group_rounded);
  static IconData get settings => _r(VibeIcons.settings, Icons.settings_rounded);
  static IconData get search => _r(VibeIcons.search, Icons.search_rounded);
  static IconData get mic => _r(VibeIcons.mic, Icons.mic_rounded);
  static IconData get bubble => _r(VibeIcons.bubble, Icons.chat_bubble_rounded);
  static IconData get check => _r(VibeIcons.check, Icons.check_rounded);
  static IconData get checkAll => _r(VibeIcons.checkAll, Icons.done_all_rounded);

  static IconData _r(IconData vibe, IconData material) {
    final pack = SettingsService.instance.iconPack;
    if (pack == 'material') return material;
    if (pack == 'telegram') return material; // TG использует material-like
    return vibe;
  }
}
