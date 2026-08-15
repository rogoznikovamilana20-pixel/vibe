import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';

/// Telegram-style context menu for messages with stagger animation.
/// Shows reactions row + action items with staggered entrance.
class TelegramContextMenu extends StatefulWidget {
  const TelegramContextMenu({
    super.key,
    required this.children,
    this.reactions,
    this.onReactionTap,
  });

  final List<Widget> children;
  final List<String>? reactions;
  final ValueChanged<String>? onReactionTap;

  @override
  State<TelegramContextMenu> createState() => _TelegramContextMenuState();

  /// Show the context menu as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<Widget> children,
    List<String>? reactions,
    ValueChanged<String>? onReactionTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TelegramContextMenu(
        reactions: reactions,
        onReactionTap: onReactionTap,
        children: children,
      ),
    );
  }
}

class _TelegramContextMenuState extends State<TelegramContextMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
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
          builder: (context, child) => Opacity(
            opacity: _fadeAnim.value,
            child: Transform.scale(
              scale: 0.9 + 0.1 * _scaleAnim.value,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(VibeSpacing.lg),
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
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: VibeSpacing.sm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.reactions != null &&
                              widget.reactions!.isNotEmpty &&
                              widget.onReactionTap != null) ...[
                            _ReactionsRow(
                              reactions: widget.reactions!,
                              onTap: widget.onReactionTap!,
                              controller: _controller,
                            ),
                            const SizedBox(height: VibeSpacing.xs),
                            Divider(
                              height: 1,
                              color: textColor.withValues(alpha: 0.1),
                            ),
                            const SizedBox(height: VibeSpacing.xs),
                          ],
                          for (var i = 0; i < widget.children.length; i++)
                            _StaggeredActionItem(
                              index: i,
                              controller: _controller,
                              child: widget.children[i],
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
      ),
    );
  }
}

/// Staggered entrance animation for each action item.
class _StaggeredActionItem extends StatelessWidget {
  const _StaggeredActionItem({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (0.1 + index * 0.05).clamp(0.0, 0.8);
    final end = (start + 0.3).clamp(0.0, 1.0);
    final slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    ));
    final fadeAnim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, (start + 0.2).clamp(0.0, 1.0), curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => Opacity(
        opacity: fadeAnim.value,
        child: Transform.translate(
          offset: slideAnim.value * 20,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Reactions row at the top of the context menu.
class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({
    required this.reactions,
    required this.onTap,
    required this.controller,
  });

  final List<String> reactions;
  final ValueChanged<String> onTap;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeSpacing.md,
        vertical: VibeSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final emoji in reactions)
            _StaggeredActionItem(
              index: reactions.indexOf(emoji),
              controller: controller,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                  onTap(emoji);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.vibePrimary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
