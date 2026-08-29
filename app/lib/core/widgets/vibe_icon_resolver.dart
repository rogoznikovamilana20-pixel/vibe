import 'package:flutter/material.dart';

import '../../data/settings_service.dart';
import 'vibe_icon_font.dart';

/// Резолвер иконок по выбранному в [SettingsService.iconPack] набору.
/// `vibe` — фирменные VibeIcons, `material` — Icons.*, `telegram` — TG-стиль (пока = vibe с fallback на material).
abstract final class VibeIconResolver {
  static IconData get send => _r(VibeIcons.send, Icons.send_rounded);
  static IconData get back => _r(VibeIcons.back, Icons.arrow_back_rounded);
  static IconData get forward => _r(VibeIcons.forward, Icons.forward_rounded);
  static IconData get check => _r(VibeIcons.check, Icons.check_rounded);
  static IconData get checkAll => _r(VibeIcons.checkAll, Icons.done_all_rounded);
  static IconData get edit => _r(VibeIcons.edit, Icons.edit_rounded);
  static IconData get trash => _r(VibeIcons.trash, Icons.delete_rounded);
  static IconData get pin => _r(VibeIcons.pin, Icons.push_pin_rounded);
  static IconData get star => _r(VibeIcons.star, Icons.star_rounded);
  static IconData get heart => _r(VibeIcons.heart, Icons.favorite_rounded);
  static IconData get bolt => _r(VibeIcons.bolt, Icons.bolt_rounded);
  static IconData get home => _r(VibeIcons.home, Icons.home_rounded);
  static IconData get phone => _r(VibeIcons.phone, Icons.call_rounded);
  static IconData get video => _r(VibeIcons.video, Icons.videocam_rounded);
  static IconData get camera => _r(VibeIcons.camera, Icons.photo_camera_rounded);
  static IconData get moreVertical => _r(VibeIcons.moreVertical, Icons.more_vert_rounded);
  static IconData get moreHorizontal => _r(VibeIcons.moreHorizontal, Icons.more_horiz_rounded);
  static IconData get plus => _r(VibeIcons.plus, Icons.add_rounded);
  static IconData get close => _r(VibeIcons.close, Icons.close_rounded);
  static IconData get search => _r(VibeIcons.search, Icons.search_rounded);
  static IconData get mic => _r(VibeIcons.mic, Icons.mic_rounded);
  static IconData get lock => _r(VibeIcons.lock, Icons.lock_rounded);
  static IconData get folder => _r(VibeIcons.folder, Icons.folder_rounded);
  static IconData get archive => _r(VibeIcons.archive, Icons.archive_rounded);
  static IconData get user => _r(VibeIcons.user, Icons.person_rounded);
  static IconData get group => _r(VibeIcons.group, Icons.group_rounded);
  static IconData get copy => _r(VibeIcons.copy, Icons.copy_rounded);
  static IconData get reply => _r(VibeIcons.reply, Icons.reply_rounded);
  static IconData get download => _r(VibeIcons.download, Icons.download_rounded);
  static IconData get volume => _r(VibeIcons.volume, Icons.volume_up_rounded);
  static IconData get play => _r(VibeIcons.play, Icons.play_arrow_rounded);
  static IconData get pause => _r(VibeIcons.pause, Icons.pause_rounded);
  static IconData get eye => _r(VibeIcons.eye, Icons.visibility_rounded);
  static IconData get info => _r(VibeIcons.info, Icons.info_rounded);
  static IconData get file => _r(VibeIcons.file, Icons.insert_drive_file_rounded);
  static IconData get clock => _r(VibeIcons.clock, Icons.access_time_rounded);
  static IconData get bubble => _r(VibeIcons.bubble, Icons.chat_bubble_rounded);
  static IconData get smile => _r(VibeIcons.smile, Icons.emoji_emotions_rounded);
  static IconData get settings => _r(VibeIcons.settings, Icons.settings_rounded);
  static IconData get attach => _r(VibeIcons.attach, Icons.attach_file_rounded);

  static IconData _r(IconData vibe, IconData material) {
    final pack = SettingsService.instance.iconPack;
    if (pack == 'material') return material;
    if (pack == 'telegram') return material; // TG использует material-like
    return vibe;
  }
}
