import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Zoomable avatar — pinch to zoom, double-tap to reset.
/// Shows full-screen overlay when zoomed in (Telegram-style).
class ZoomableAvatar extends StatefulWidget {
  const ZoomableAvatar({
    super.key,
    required this.child,
    this.maxScale = 3.0,
    this.onDoubleTap,
  });

  final Widget child;
  final double maxScale;
  final VoidCallback? onDoubleTap;

  @override
  State<ZoomableAvatar> createState() => _ZoomableAvatarState();
}

class _ZoomableAvatarState extends State<ZoomableAvatar>
    with SingleTickerProviderStateMixin {
  late final TransformationController _controller;
  late final AnimationController _animController;
  Animation<Matrix4>? _animation;
  Offset? _doubleTapPosition;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (_animation != null) {
          _controller.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        maxScale: widget.maxScale,
        minScale: 1.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: widget.child,
      ),
    );
  }

  void _handleDoubleTap() {
    HapticFeedback.selectionClick();
    final currentScale = _controller.value.getMaxScaleOnAxis();

    Matrix4 targetMatrix;
    if (currentScale > 1.5) {
      // Zoomed in — reset.
      targetMatrix = Matrix4.identity();
    } else {
      // Zoomed out — zoom in to double-tap position.
      final x = -(_doubleTapPosition?.dx ?? 0) * 1.5;
      final y = -(_doubleTapPosition?.dy ?? 0) * 1.5;
      targetMatrix = Matrix4.identity()
        ..translate(x, y)
        ..scale(2.0);
    }

    _animation = Matrix4Tween(
      begin: _controller.value,
      end: targetMatrix,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward(from: 0);
  }
}
