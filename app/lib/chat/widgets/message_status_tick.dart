import 'dart:math';
import 'package:flutter/material.dart';

import '../../data/backend.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Галочки статуса сообщения с stroke-draw анимацией как в Telegram.
class MessageStatusTick extends StatefulWidget {
  const MessageStatusTick({
    super.key,
    required this.status,
    this.size = 14,
  });

  final MsgStatus status;
  final double size;

  @override
  State<MessageStatusTick> createState() => _MessageStatusTickState();
}

class _MessageStatusTickState extends State<MessageStatusTick>
    with SingleTickerProviderStateMixin {
  late AnimationController _drawController;
  late AnimationController _colorController;
  late Animation<double> _drawAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _drawAnimation = CurvedAnimation(
      parent: _drawController,
      curve: Curves.easeOutCubic,
    );
    _colorAnimation = ColorTween(
      begin: Colors.white70,
      end: const Color(0xFF8AB4F8),
    ).animate(_colorController);

    if (widget.status == MsgStatus.sent ||
        widget.status == MsgStatus.delivered ||
        widget.status == MsgStatus.read) {
      _drawController.value = 1.0;
    }
    if (widget.status == MsgStatus.read) {
      _colorController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(MessageStatusTick oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      if (widget.status == MsgStatus.sent) {
        _drawController.forward(from: 0.0);
      } else if (widget.status == MsgStatus.delivered) {
        _drawController.forward(from: 0.0);
      } else if (widget.status == MsgStatus.read) {
        _drawController.forward(from: 0.0);
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _colorController.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _drawController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Color _color(MsgStatus s) {
    switch (s) {
      case MsgStatus.sending:
        return Colors.white38;
      case MsgStatus.sent:
        return Colors.white70;
      case MsgStatus.delivered:
        return Colors.white70;
      case MsgStatus.read:
        return _colorAnimation.value ?? const Color(0xFF8AB4F8);
      case MsgStatus.failed:
        return const Color(0xFFFF6B6B);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == MsgStatus.sending) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const _ClockSpinner(),
      );
    }
    if (widget.status == MsgStatus.failed) {
      return Icon(Icons.error_outline_rounded,
          size: widget.size, color: _color(widget.status));
    }
    return AnimatedBuilder(
      animation: Listenable.merge([_drawAnimation, _colorAnimation]),
      builder: (context, _) {
        final color = _color(widget.status);
        if (widget.status == MsgStatus.sent ||
            widget.status == MsgStatus.delivered ||
            widget.status == MsgStatus.read) {
          final isDouble = widget.status == MsgStatus.delivered ||
              widget.status == MsgStatus.read;
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _CheckmarkPainter(
              progress: _drawAnimation.value,
              color: color,
              isDouble: isDouble,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.isDouble,
  });

  final double progress;
  final Color color;
  final bool isDouble;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final h = size.height;
    final w = size.width;
    final gap = isDouble ? w * 0.18 : 0.0;

    _drawCheck(canvas, paint, w - gap, h, progress);

    if (isDouble) {
      _drawCheck(canvas, paint, w * 0.82, h, progress);
    }
  }

  void _drawCheck(Canvas canvas, Paint paint, double w, double h, double p) {
    final path = Path();
    path.moveTo(w * 0.18, h * 0.52);
    path.lineTo(w * 0.42, h * 0.76);
    path.lineTo(w * 0.82, h * 0.28);

    final metrics = path.computeMetrics().first;
    final extracted = metrics.extractPath(0, metrics.length * p);

    canvas.drawPath(extracted, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) =>
      old.progress != progress || old.color != color;
}

class _ClockSpinner extends StatefulWidget {
  const _ClockSpinner();

  @override
  State<_ClockSpinner> createState() => _ClockSpinnerState();
}

class _ClockSpinnerState extends State<_ClockSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (context, child) {
        return Transform.rotate(
          angle: _spin.value * 2 * pi,
          child: Icon(VibeIcons.clock, size: 14, color: Colors.white38),
        );
      },
    );
  }
}
