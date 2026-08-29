import 'package:flutter/material.dart';

/// Telegram-style staggered entrance (TG Desktop): fade+slide для первых 12 чатов.
/// Лимит 12 — без джанка на больших списках, RepaintBoundary изолирует перерисовку.
class StaggeredChatListItem extends StatefulWidget {
  const StaggeredChatListItem({
    super.key,
    required this.index,
    required this.child,
    this.delay = const Duration(milliseconds: 30),
    this.duration = const Duration(milliseconds: 220),
  });

  final int index;
  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<StaggeredChatListItem> createState() => _StaggeredChatListItemState();
}

class _StaggeredChatListItemState extends State<StaggeredChatListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    if (widget.index >= 12) {
      _c = AnimationController(vsync: this, value: 1, duration: widget.duration);
      _fade = AlwaysStoppedAnimation(1);
      _slide = AlwaysStoppedAnimation(Offset.zero);
      return;
    }
    _c = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.index >= 12) return RepaintBoundary(child: widget.child);
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}
