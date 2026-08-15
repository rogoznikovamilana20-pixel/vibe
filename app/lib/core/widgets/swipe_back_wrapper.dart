import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive swipe-back gesture wrapper (iOS-style rubber-band effect).
/// Wrap any screen to enable edge-swipe to pop.
class SwipeBackWrapper extends StatefulWidget {
  const SwipeBackWrapper({
    super.key,
    required this.child,
    this.onPop,
  });

  final Widget child;
  final VoidCallback? onPop;

  @override
  State<SwipeBackWrapper> createState() => _SwipeBackWrapperState();
}

class _SwipeBackWrapperState extends State<SwipeBackWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  double _dragOffset = 0;
  bool _isDragging = false;

  static const double _maxDrag = 280;
  static const double _threshold = 50;
  static const double _velocityThreshold = 500;
  static const double _rubberBandFactor = 0.55;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (details.globalPosition.dx < 30) {
      _isDragging = true;
      _animController.stop();
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, _maxDrag);
    final progress = _dragOffset / _maxDrag;
    _animController.value = progress;
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final velocity = details.primaryVelocity ?? 0;
    if (velocity > _velocityThreshold || _dragOffset > _threshold) {
      _dismiss();
    } else {
      _snapBack();
    }
  }

  void _dismiss() {
    HapticFeedback.mediumImpact();
    _animController
        .animateTo(1.0, duration: const Duration(milliseconds: 250))
        .then((_) {
      if (mounted) {
        widget.onPop?.call();
        Navigator.of(context).pop();
      }
    });
  }

  void _snapBack() {
    _animController.animateBack(0, duration: const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final fade = 1.0 - _animController.value;
        return GestureDetector(
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Transform.translate(
            offset: Offset(_dragOffset * _rubberBandFactor, 0),
            child: Opacity(
              opacity: fade,
              child: widget.child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
