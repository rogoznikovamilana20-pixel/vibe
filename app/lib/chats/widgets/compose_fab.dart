import 'package:flutter/material.dart';

import '../../core/theme/vibe_colors.dart';

/// Плавающая кнопка «Новое сообщение» в шапке списка чатов.
class ComposeFAB extends StatelessWidget {
  const ComposeFAB({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: VibeColors.brandGradient,
        ),
        boxShadow: const [VibeShadows.floating],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
          tooltip: 'Новое сообщение',
        ),
      ),
    );
  }
}
