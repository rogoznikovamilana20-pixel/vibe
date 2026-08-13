import 'package:flutter/material.dart';

import '../../core/widgets/vibe_icon_button.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Плавающая кнопка «Новое сообщение» в шапке списка чатов.
/// 8.2.3: делегирует фирменному VibeFab (сжатие 86%, бренд-градиент).
class ComposeFAB extends StatelessWidget {
  const ComposeFAB({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VibeFab(icon: VibeIcons.edit, onPressed: onTap);
  }
}