import 'package:flutter/material.dart';

/// Telegram-style staggered entrance animation for chat list items.
/// Currently disabled for performance (desktop & mobile) — returns child directly.
/// To re-enable, restore StatefulWidget with AnimationController.
class StaggeredChatListItem extends StatelessWidget {
  const StaggeredChatListItem({
    super.key,
    required this.index,
    required this.child,
    this.delay = const Duration(milliseconds: 30),
    this.duration = const Duration(milliseconds: 250),
  });

  final int index;
  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) => child;
}
