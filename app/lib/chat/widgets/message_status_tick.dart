import 'package:flutter/material.dart';

import '../../data/backend.dart';

/// Галочки статуса сообщения: часики → ✓ → ✓✓ → синие ✓✓ (как в Telegram).
class MessageStatusTick extends StatelessWidget {
  const MessageStatusTick({super.key, required this.status, this.size = 14});

  final MsgStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MsgStatus.sending:
        return Icon(Icons.schedule_rounded, size: size, color: Colors.white38);
      case MsgStatus.sent:
        return Icon(Icons.check_rounded, size: size, color: Colors.white70);
      case MsgStatus.delivered:
        return Icon(Icons.done_all_rounded, size: size, color: Colors.white70);
      case MsgStatus.read:
        return Icon(
          Icons.done_all_rounded,
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
