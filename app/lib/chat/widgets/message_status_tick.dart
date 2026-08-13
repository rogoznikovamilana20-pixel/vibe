import 'package:flutter/material.dart';

import '../../data/backend.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Галочки статуса сообщения: часики → ✓ → ✓✓ → синие ✓✓ (как в Telegram).
class MessageStatusTick extends StatelessWidget {
  const MessageStatusTick({super.key, required this.status, this.size = 14});

  final MsgStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MsgStatus.sending:
        return Icon(VibeIcons.clock, size: size, color: Colors.white38);
      case MsgStatus.sent:
        return Icon(VibeIcons.check, size: size, color: Colors.white70);
      case MsgStatus.delivered:
        return Icon(VibeIcons.checkAll, size: size, color: Colors.white70);
      case MsgStatus.read:
        return Icon(
          VibeIcons.checkAll,
          size: size,
          color: const Color(0xFF8AB4F8),
        );
      case MsgStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: size,
          color: const Color(0xFFFF6B6B),
        );
    }
  }
}
