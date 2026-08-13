import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/vibe_animations.dart';
import '../theme/vibe_colors.dart';
import '../theme/vibe_spacing.dart';
import '../theme/vibe_typography.dart';

/// 8.4.6: фирменный тост Vibe — всплывающая капсула как у Telegram.
/// Единая тёмная капсула над всем (root overlay), авто-исчезание,
/// один тост за раз (новый заменяет предыдущий).
class VibeToast {
  VibeToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;
  static int _seq = 0;

  /// Показать тост. [icon]/[iconColor] — необязательная иконка-акцент
  /// (например, успех или ошибка).
  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    Color? iconColor,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    _seq++;
    final seq = _seq;
    _timer?.cancel();
    _entry?.remove();
    final entry = OverlayEntry(
      builder: (_) => _VibeToastHost(
        message: message,
        icon: icon,
        iconColor: iconColor,
        onDone: () => _dismiss(seq),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, () => _dismiss(seq));
  }

  static void _dismiss(int seq) {
    if (seq != _seq) return;
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
  }
}

class _VibeToastHost extends StatefulWidget {
  const _VibeToastHost({
    required this.message,
    this.icon,
    this.iconColor,
    required this.onDone,
  });

  final String message;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback onDone;

  @override
  State<_VibeToastHost> createState() => _VibeToastHostState();
}

class _VibeToastHostState extends State<_VibeToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: VibeAnimations.fast,
    );
    _slide = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        minimum: const EdgeInsets.all(VibeSpacing.lg),
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _slide,
            builder: (context, child) => Opacity(
              opacity: _slide.value,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - _slide.value)),
                child: child,
              ),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: VibeSpacing.lg,
                  vertical: VibeSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xE6161424),
                  borderRadius: BorderRadius.circular(VibeRadius.badge + 4),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(VibeRadius.badge + 4),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: VibeBlur.nav,
                      sigmaY: VibeBlur.nav,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            size: 18,
                            color: widget.iconColor ?? Colors.white,
                          ),
                          const SizedBox(width: VibeSpacing.sm),
                        ],
                        Flexible(
                          child: Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: VibeTypography.bodyMedium.copyWith(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Пре-сет иконок тоста (как в ТГ: галочка успеха, ошибка).
abstract final class VibeToastIcons {
  static const success = Icons.check_rounded;
  static const error = Icons.error_outline_rounded;
  static const info = Icons.info_outline_rounded;

  static const successColor = VibeColors.success;
  static const errorColor = VibeColors.errorLight;
  static const infoColor = VibeColors.info;
}