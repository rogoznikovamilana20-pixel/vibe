import 'package:flutter/material.dart';

import '../theme/vibe_spacing.dart';
import 'vibe_top_frost.dart';

/// Общий каркас экрана с коллапсирующей шапкой (как главный экран в Vibe и
/// Telegram): большой заголовок скроллится вместе с лентой, а при прокрутке
/// поверх контента вплывает морозный `collapsedBar`. Контент проходит под
/// барами, не обрезаясь.
class VibeCollapsibleScreen extends StatefulWidget {
  const VibeCollapsibleScreen({
    super.key,
    required this.slivers,
    this.collapsedBarBuilder,
    this.collapsedBarPadding = const EdgeInsets.symmetric(
      horizontal: VibeSpacing.lg,
    ),
    this.collapseStart = 40,
    this.collapseRange = 200,
    this.bottomPadding = VibeSpacing.xxl * 2 + VibeSizes.bottomNavHeight,
    this.scrollController,
  });

  /// Все слаи контента, включая большой заголовок сверху.
  final List<Widget> slivers;

  /// Строит компактную фиксированную шапку поверх ленты
  /// (например [VibeCollapsedTopBar]). Получает прогресс коллапса 0..1.
  final Widget Function(BuildContext, double)? collapsedBarBuilder;

  final EdgeInsetsGeometry collapsedBarPadding;
  final double collapseStart;
  final double collapseRange;
  final double bottomPadding;

  /// Опциональный контроллер прокрутки (например, для автоскролла вниз).
  final ScrollController? scrollController;

  @override
  State<VibeCollapsibleScreen> createState() => _VibeCollapsibleScreenState();
}

class _VibeCollapsibleScreenState extends State<VibeCollapsibleScreen> {
  double _offset = 0;

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
      final value = n.metrics.pixels;
      if ((value - _offset).abs() > 0.5) {
        _offset = value;
        setState(() {});
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.collapsedBarBuilder;
    final progress =
        ((_offset - widget.collapseStart) / widget.collapseRange)
            .clamp(0.0, 1.0);
    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: SafeArea(
              bottom: false,
              child: CustomScrollView(
                controller: widget.scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  ...widget.slivers,
                  SliverToBoxAdapter(
                    child: SizedBox(height: widget.bottomPadding),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Морозный «бесшовный» блюрик под верхней кромкой: проявляется
        // только по мере скролла (вместе с коллапс-баром), когда контент
        // реально проходит под баром. В покое — прозрачен, без статики.
        if (progress > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 84,
            child: IgnorePointer(
              child: Opacity(
                opacity: progress,
                child: const VibeTopFrost(),
              ),
            ),
          ),
        if (builder != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: widget.collapsedBarPadding,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _ProgressScope(
                    progress: progress,
                    child: builder(context, progress),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProgressScope extends InheritedWidget {
  const _ProgressScope({required this.progress, required super.child});

  final double progress;

  static double of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ProgressScope>();
    return scope?.progress ?? 0;
  }

  @override
  bool updateShouldNotify(_ProgressScope old) => progress != old.progress;
}

extension VibeCollapsibleContext on BuildContext {
  /// Прогресс коллапса шапки (0..1). Доступен внутри
  /// [VibeCollapsibleScreen.collapsedBarBuilder].
  double get vibeCollapseProgress => _ProgressScope.of(this);
}