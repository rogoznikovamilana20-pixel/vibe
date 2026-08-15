import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';

/// Telegram-style bottom sheet with drag handle, swipe-to-dismiss,
/// and spring physics. Replaces default showModalBottomSheet.
class TelegramBottomSheet extends StatefulWidget {
  const TelegramBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showDragHandle = true,
  });

  final Widget child;
  final String? title;
  final bool showDragHandle;

  /// Show as modal bottom sheet.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool showDragHandle = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => TelegramBottomSheet(
        title: title,
        showDragHandle: showDragHandle,
        child: child,
      ),
    );
  }

  @override
  State<TelegramBottomSheet> createState() => _TelegramBottomSheetState();
}

class _TelegramBottomSheetState extends State<TelegramBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _dragOffset += d.delta.dy);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dragOffset > 100 || (d.primaryVelocity ?? 0) > 500) {
      Navigator.of(context).pop();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? VibeColors.surface2Dark : VibeColors.surface2Light;
    final textColor = isDark
        ? VibeColors.textPrimaryDark
        : VibeColors.textPrimaryLight;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _scaleAnim.value;
            final opacity = (_fadeAnim.value - (_dragOffset.abs() / 300)).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, _dragOffset * 0.5),
                child: Transform.scale(
                  scale: 0.9 + 0.1 * progress,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
            );
          },
          child: GestureDetector(
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                margin: const EdgeInsets.all(VibeSpacing.md),
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: BorderRadius.circular(VibeRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(VibeRadius.lg),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.showDragHandle) ...[
                          const SizedBox(height: VibeSpacing.sm),
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: textColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: VibeSpacing.sm),
                        ],
                        if (widget.title != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: VibeSpacing.lg,
                            ),
                            child: Text(
                              widget.title!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: VibeSpacing.sm),
                          Divider(
                            height: 1,
                            color: textColor.withValues(alpha: 0.1),
                          ),
                        ],
                        Flexible(child: widget.child),
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
