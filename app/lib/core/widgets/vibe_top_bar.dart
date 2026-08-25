import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/vibe_colors.dart';
import '../theme/vibe_spacing.dart';
import '../theme/vibe_theme.dart';
import '../theme/vibe_typography.dart';

/// Стеклянный «остров»-шапка вверху — единый с нижней навигацией стиль (как в Telegram):
/// плавающая капсула с блюром, деликатной рамкой и тенью.
class VibeTopBar extends StatelessWidget {
  const VibeTopBar({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.height = 60,
    this.floating = true,
    this.padding = const EdgeInsets.fromLTRB(
      VibeSpacing.xs,
      VibeSpacing.xs,
      VibeSpacing.lg,
      VibeSpacing.xs,
    ),
  });

  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final List<Widget> actions;
  final double height;
  final bool floating;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: _buildSurface(
        context,
        child: Row(
          children: [
            if (leading != null)
              Padding(
                padding: const EdgeInsets.only(left: VibeSpacing.xs),
                child: leading,
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.sm),
                child: _buildTitle(context),
              ),
            ),
            for (final a in actions)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: a,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurface(BuildContext context, {required Widget child}) {
    if (!floating) {
      return SizedBox(height: height, child: child);
    }
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: context.vibeGlass,
        borderRadius: BorderRadius.circular(VibeRadius.bottomSheet),
        border: Border.all(color: context.vibeGlassBorder),
        boxShadow: [context.vibeGlassShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VibeRadius.bottomSheet),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: VibeBlur.panel,
            sigmaY: VibeBlur.panel,
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final t = title;
    final s = subtitle;
    if (t == null && s == null) return const SizedBox.shrink();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ?t,
        ?s == null
            ? null
            : Padding(padding: const EdgeInsets.only(top: 2), child: s),
      ],
    );
  }
}

/// Обёртка `VibeTopBar` для слота `appBar:` Scaffold: добавляет отступ под
/// статус-бар/вырез камеры (в отличие от Material AppBar Scaffold сам этого
/// не делает), чтобы шапка-«остров» не уезжала под системные элементы.
class VibeTopBarAppBar extends StatelessWidget implements PreferredSizeWidget {
  const VibeTopBarAppBar({
    super.key,
    required this.topInset,
    required this.child,
  });

  /// Высота статус-бара: `MediaQuery.paddingOf(context).top`.
  final double topInset;
  final Widget child;

  @override
  Size get preferredSize => Size.fromHeight(VibeSizes.toolbarHeight + topInset);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: child,
    );
  }
}

/// Стандартный заголовок шапки-острова.
class VibeTopBarTitle extends StatelessWidget {
  const VibeTopBarTitle(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style:
          style ??
          VibeTypography.title.copyWith(color: context.vibeTextPrimary),
    );
  }
}

/// Стандартная иконка-действие в шапке с единым размером.
class VibeTopBarIcon extends StatelessWidget {
  const VibeTopBarIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      color: color ?? context.vibeTextPrimary,
      tooltip: tooltip,
    );
  }
}
