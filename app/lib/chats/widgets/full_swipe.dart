import 'package:flutter/material.dart';

import '../../core/theme/vibe_animations.dart';

/// Полный свайп в стиле Telegram: свайп влево — одно действие
/// (настраивается в настройках, по умолчанию архив), свайп вправо —
/// вернуть из архива. Порог 0.45 и отмена за 200 мс — как в TG
/// (SwipeController.getSwipeThreshold / getAnimationDuration).
class FullSwipe extends StatefulWidget {
  const FullSwipe({
    super.key,
    required this.child,
    required this.enabled,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.leftBackground,
    this.rightBackground,
    this.onTileTap,
    this.onTileLongPress,
  });

  final Widget child;

  /// Свайпы работают (выкл. в режиме выбора).
  final bool enabled;

  /// Действие при свайпе влево (архив/прочитано/мут/закреп/удаление).
  final VoidCallback? onSwipeLeft;

  /// Действие при свайпе вправо (вернуть из архива).
  final VoidCallback? onSwipeRight;

  /// Фон под плиткой при свайпе влево (цвет действия + иконка).
  final Widget? leftBackground;

  /// Фон под плиткой при свайпе вправо (архив).
  final Widget? rightBackground;

  /// Тап по плитке.
  final VoidCallback? onTileTap;

  /// Длинный тап по плитке.
  final VoidCallback? onTileLongPress;

  @override
  State<FullSwipe> createState() => _FullSwipeState();
}

class _FullSwipeState extends State<FullSwipe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _offset = AnimationController(
    vsync: this,
    duration: VibeAnimations.fast,
    lowerBound: -1,
    upperBound: 1,
    value: 0,
  );

  /// Максимальный сдвиг плитки (px) — фон действия виден целиком.
  static const double _maxShift = 160;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    // Игнорируем вертикальный скролл, чтобы не мешать листу (чаты не должны хромать при вертикальном свайпе).
    if (details.delta.dx.abs() < details.delta.dy.abs()) return;
    final delta = details.primaryDelta ?? details.delta.dx;
    final next = (_offset.value - delta / _maxShift).clamp(-1.0, 1.0);
    _offset.value = next;
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    final v = _offset.value;

    // TG: getSwipeThreshold = 0.45 ширины.
    const threshold = 0.45;
    if (v > threshold) {
      final cb = widget.onSwipeLeft;
      _offset.animateTo(1, curve: Curves.easeOut).whenComplete(() {
        _offset.value = 0;
        if (cb != null) cb();
      });
      return;
    }
    if (v < -threshold) {
      final cb = widget.onSwipeRight;
      _offset.animateTo(-1, curve: Curves.easeOut).whenComplete(() {
        _offset.value = 0;
        if (cb != null) cb();
      });
      return;
    }
    // TG: отмена свайпа за 200 мс.
    _offset.animateTo(0, duration: const Duration(milliseconds: 200));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;

    return ClipRect(
      child: Stack(
        children: [
          // Фон под плиткой при свайпе влево (действие).
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: widget.leftBackground ?? const SizedBox.shrink(),
            ),
          ),
          // Фон под плиткой при свайпе вправо (вернуть из архива).
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: widget.rightBackground ?? const SizedBox.shrink(),
            ),
          ),
          AnimatedBuilder(
            animation: _offset,
            builder: (context, child) {
              final offsetPx = _offset.value * _maxShift;
              return Transform.translate(
                offset: Offset(-offsetPx, 0),
                child: child,
              );
            },
            child: GestureDetector(
              onHorizontalDragUpdate: enabled ? _onDragUpdate : null,
              onHorizontalDragEnd: enabled ? _onDragEnd : null,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: enabled ? widget.onTileTap : null,
                  onLongPress: enabled ? widget.onTileLongPress : null,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}