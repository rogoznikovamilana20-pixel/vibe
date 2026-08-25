import 'package:flutter/material.dart';

import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_avatar.dart';
import '../../screens/story_player.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Кружок истории в карусели (как в Telegram):
/// непросмотренная — градиентное кольцо, просмотренная — тонкое серое;
/// превью контента кадрируется под круг (BoxFit.cover).
class StoryCircle extends StatelessWidget {
  const StoryCircle({
    super.key,
    required this.item,
    required this.onTap,
    this.placeholder = false,
    this.size = 44,
  });

  final StoryItem item;
  final VoidCallback onTap;

  /// Пустой кружок «+» для «Моей истории» без контента.
  final bool placeholder;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2 + 8),
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: !item.seen
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: VibeColors.brandGradient,
                    )
                  : null,
              border: item.seen
                  ? Border.all(
                      color: VibeColors.textTertiaryDark.withValues(alpha: 0.6),
                      width: 1.5,
                    )
                  : null,
            ),
            child: ClipOval(
              child: placeholder
                  ? Icon(
                      VibeIcons.plus,
                      color: context.vibePrimary,
                      size: size * 0.52,
                    )
                  : _preview(item, context),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: size + 8,
            child: Text(
              item.author,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: VibeTypography.caption.copyWith(
                color: item.seen
                    ? context.vibeTextTertiary
                    : context.vibeTextSecondary,
                fontSize: 11,
                height: 14 / 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(StoryItem item, BuildContext context) {
    if (item.photo != null) {
      return Image.memory(
        item.photo!,
        width: size - 4,
        height: size - 4,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    if (item.photoUrl != null) {
      return SizedBox(
        width: size - 4,
        height: size - 4,
        child: VibeNetImage(
          source: item.photoUrl,
          errorBuilder: (_, _, _) =>
              const ColoredBox(color: VibeColors.surfaceDark),
        ),
      );
    }
    return VibeAvatar(name: item.author, size: size - 4, storyRing: false);
  }
}
