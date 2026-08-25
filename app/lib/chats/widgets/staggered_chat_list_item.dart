import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// Telegram-style staggered entrance animation for chat list items.
/// Each item fades in and slides up with a delay based on its index.
class StaggeredChatListItem extends StatefulWidget {
  const StaggeredChatListItem({
    super.key,
    required this.index,
    required this.child,
    this.delay = const Duration(milliseconds: 30),
    this.duration = const Duration(milliseconds: 250),
  });

  final int index;
  final Widget child;

  /// Delay between each item's entrance.
  final Duration delay;

  /// Duration of each item's entrance animation.
  final Duration duration;

  @override
  State<StaggeredChatListItem> createState() => _StaggeredChatListItemState();
}

class _StaggeredChatListItemState extends State<StaggeredChatListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));

    // Start animation after a delay based on index (max 8 items staggered).
    final delayMs = (widget.index * widget.delay.inMilliseconds).clamp(0, 240);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(covariant StaggeredChatListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller.value = 1.0; // Already visible, don't re-animate.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = (() {
      try {
        return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      } catch (_) {
        return false;
      }
    })();
    if (isDesktop) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: _slide.value * 24,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
