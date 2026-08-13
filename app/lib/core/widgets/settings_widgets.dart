import 'package:flutter/material.dart';
import '../theme/vibe_spacing.dart';
import '../theme/vibe_theme.dart';
import '../theme/vibe_typography.dart';

/// Раздел настроек с заголовком и списком плиток (в стиле Telegram).
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.title,
    required this.children,
  });

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(
              left: VibeSpacing.lg + 4,
              bottom: VibeSpacing.sm,
              top: VibeSpacing.lg,
            ),
            child: Text(
              title!.toUpperCase(),
              style: VibeTypography.label.copyWith(
                color: context.vibeTextTertiary,
                letterSpacing: 1.2,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: context.vibeSurfaceVariant,
            borderRadius: BorderRadius.circular(VibeRadius.card),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    indent: VibeSizes.iconMd + VibeSpacing.md + VibeSpacing.lg,
                    color: context.vibeDivider,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Плитка настройки с иконкой в цветном кружке (в стиле Telegram).
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.iconWidget,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;

  /// Кастомная подпись вместо текстовой (например, иконка + текст).
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  /// Кастомная иконка вместо стандартной (например, нарисованная).
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.vibeError : context.vibeTextPrimary;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: VibeSpacing.lg,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: iconWidget ??
                    Icon(
                      icon,
                      size: 18,
                      color: iconColor,
                    ),
              ),
              const SizedBox(width: VibeSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: VibeTypography.bodyMedium.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: VibeTypography.caption.copyWith(
                          color: context.vibeTextSecondary,
                        ),
                      ),
                    ?subtitleWidget,
                  ],
                ),
              ),
              const SizedBox(width: VibeSpacing.sm),
              if (trailing != null)
                trailing!
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.vibeTextTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
