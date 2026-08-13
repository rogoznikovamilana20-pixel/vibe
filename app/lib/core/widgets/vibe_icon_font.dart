import 'package:flutter/widgets.dart';

/// Фирменный шрифт иконок Vibe (`assets/fonts/vibe_icons.ttf`).
///
/// Конвейер пересборки: `C:\Users\andre\AppData\Local\Temp\opencode\icons\gen_vibe_icons.py`
/// (добавить путь в ICONS → `python gen_vibe_icons.py <app>\assets\fonts\vibe_icons.ttf`).
/// Глифы — 24px-грид, Material-совместимо; коды начинаются с U+E000.
abstract final class VibeIcons {
  static const String _family = 'VibeIcons';

  static const send = IconData(0xE000, fontFamily: _family);
  static const back = IconData(0xE001, fontFamily: _family);
  static const forward = IconData(0xE002, fontFamily: _family);
  static const check = IconData(0xE003, fontFamily: _family);
  static const checkAll = IconData(0xE004, fontFamily: _family);
  static const edit = IconData(0xE005, fontFamily: _family);
  static const trash = IconData(0xE006, fontFamily: _family);
  static const pin = IconData(0xE007, fontFamily: _family);
  static const star = IconData(0xE008, fontFamily: _family);
  static const heart = IconData(0xE009, fontFamily: _family);
  static const bolt = IconData(0xE00A, fontFamily: _family);
  static const home = IconData(0xE00B, fontFamily: _family);
  static const phone = IconData(0xE00C, fontFamily: _family);
  static const video = IconData(0xE00D, fontFamily: _family);
  static const camera = IconData(0xE00E, fontFamily: _family);
  static const moreVertical = IconData(0xE00F, fontFamily: _family);
  static const moreHorizontal = IconData(0xE010, fontFamily: _family);
  static const plus = IconData(0xE011, fontFamily: _family);
  static const close = IconData(0xE012, fontFamily: _family);
  static const search = IconData(0xE013, fontFamily: _family);
  static const mic = IconData(0xE014, fontFamily: _family);
  static const lock = IconData(0xE015, fontFamily: _family);
  static const folder = IconData(0xE016, fontFamily: _family);
  static const archive = IconData(0xE017, fontFamily: _family);
  static const user = IconData(0xE018, fontFamily: _family);
  static const group = IconData(0xE019, fontFamily: _family);
  static const copy = IconData(0xE01A, fontFamily: _family);
  static const reply = IconData(0xE01B, fontFamily: _family);
  static const download = IconData(0xE01C, fontFamily: _family);
  static const volume = IconData(0xE01D, fontFamily: _family);
  static const play = IconData(0xE01E, fontFamily: _family);
  static const pause = IconData(0xE01F, fontFamily: _family);
  static const eye = IconData(0xE020, fontFamily: _family);
  static const info = IconData(0xE021, fontFamily: _family);
  static const file = IconData(0xE022, fontFamily: _family);
  static const clock = IconData(0xE023, fontFamily: _family);
  static const bubble = IconData(0xE024, fontFamily: _family);
  static const smile = IconData(0xE025, fontFamily: _family);
  static const settings = IconData(0xE026, fontFamily: _family);
  static const attach = IconData(0xE027, fontFamily: _family);
}