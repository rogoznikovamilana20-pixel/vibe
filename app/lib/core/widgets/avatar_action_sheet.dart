import 'package:flutter/material.dart';

import '../theme/vibe_colors.dart';
import '../theme/vibe_spacing.dart';
import '../theme/vibe_theme.dart';
import '../theme/vibe_typography.dart';

/// Шит смены аватарки: галерея / камера / удалить.
/// Возвращает 'gal' | 'cam' | 'del' | null.
class AvatarActionSheet extends StatelessWidget {
  const AvatarActionSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AvatarActionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, String value, Color color) =>
        ListTile(
          leading: Icon(icon, color: color),
          title: Text(
            label,
            style: VibeTypography.bodyMedium.copyWith(color: color),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: VibeColors.textTertiaryDark,
          ),
          onTap: () => Navigator.of(context).pop(value),
        );
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(VibeSpacing.md),
        padding: const EdgeInsets.all(VibeSpacing.xs),
        decoration: BoxDecoration(
          color: context.vibeSurfaceHigh,
          borderRadius: BorderRadius.circular(VibeRadius.bottomSheet),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              item(Icons.photo_library_outlined, 'Выбрать из галереи', 'gal',
                  context.vibeTextPrimary),
              item(Icons.photo_camera_outlined, 'Сделать фото', 'cam',
                  context.vibeTextPrimary),
              item(Icons.delete_outline_rounded, 'Удалить аватар', 'del',
                  context.vibeError),
            ],
          ),
        ),
      ),
    );
  }
}