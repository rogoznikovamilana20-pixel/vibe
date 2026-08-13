import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_avatar.dart';
import '../../core/widgets/vibe_icon_button.dart';
import '../../data/backend.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Стеклянная пилюля шапки чата — как в Telegram: одна плавающая капсула.
/// Использует стекло темы, поэтому дружит и со светлой, и с тёмной темой.
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VibeSpacing.sm,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: context.vibeGlass.withValues(
            alpha: context.isDarkMode ? 0.35 : 0.65,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0x1A1C1B22),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Шапка чата: назад, аватар+имя+статус, действия (поиск/звонок/меню).
class ChatAppBar extends StatelessWidget {
  const ChatAppBar({
    super.key,
    required this.chat,
    this.groupTitle,
    this.peerTyping = false,
    required this.onBack,
    required this.onOpenProfile,
    required this.onOpenGroupInfo,
    required this.onOpenSearch,
    required this.onChooseCall,
    required this.onShowMenu,
  });

  final VibeChat chat;
  final String? groupTitle;

  /// Индикатор «печатает…» для личного чата.
  final bool peerTyping;

  final VoidCallback onBack;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenGroupInfo;
  final VoidCallback onOpenSearch;
  final VoidCallback onChooseCall;
  final VoidCallback onShowMenu;

  @override
  Widget build(BuildContext context) {
    final isGroup = chat.kind == 'group';
    final typing = !isGroup && peerTyping;
    final subtitle = typing
        ? 'печатает…'
        : (isGroup
            ? 'Группа'
            : (chat.peerOnline
                ? 'в сети'
                : (chat.peerLastSeen != null
                    ? 'был(а) в сети ${VibeBackend.formatTime(chat.peerLastSeen)}'
                    : 'был(а) недавно')));
    final subtitleColor = typing
        ? context.vibePrimary
        : ((!isGroup && chat.peerOnline)
            ? VibeColors.success
            : context.vibeTextTertiary);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VibeSpacing.sm,
        VibeSpacing.xs,
        VibeSpacing.sm,
        VibeSpacing.xs,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Row(
            children: [
              VibeIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: onBack,
                iconSize: 18,
                tooltip: 'Назад',
                color: context.vibeTextPrimary,
              ),
              const SizedBox(width: VibeSpacing.xs),
              Expanded(
                child: _HeaderPill(
                  onTap: isGroup ? onOpenGroupInfo : onOpenProfile,
                  child: Row(
                    children: [
                      Hero(
                        tag: 'avatar_${chat.id}',
                        child: VibeAvatar(
                          name: chat.title,
                          size: VibeSizes.avatarMd,
                          online: chat.peerOnline,
                          photoUrl: chat.peerAvatar,
                        ),
                      ),
                      const SizedBox(width: VibeSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              groupTitle ?? chat.title,
                              overflow: TextOverflow.ellipsis,
                              style: VibeTypography.subtitle.copyWith(
                                fontSize: 15,
                                color: context.vibeTextPrimary,
                              ),
                            ),
                            Text(
                              subtitle,
                              overflow: TextOverflow.ellipsis,
                              style: VibeTypography.caption.copyWith(
                                fontSize: 11,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: VibeSpacing.xs),
              _HeaderPill(
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VibeIconButton(
                        icon: VibeIcons.search,
                        onPressed: onOpenSearch,
                        tooltip: 'Поиск',
                        color: context.vibeTextPrimary,
                      ),
                      VerticalDivider(
                        width: 1,
                        indent: 4,
                        endIndent: 4,
                        color: context.isDarkMode
                            ? Colors.white24
                            : const Color(0x1F1C1B22),
                      ),
                      VibeIconButton(
                        icon: Icons.call_outlined,
                        onPressed: onChooseCall,
                        tooltip: 'Позвонить',
                        color: context.vibeTextPrimary,
                      ),
                      VerticalDivider(
                        width: 1,
                        indent: 4,
                        endIndent: 4,
                        color: context.isDarkMode
                            ? Colors.white24
                            : const Color(0x1F1C1B22),
                      ),
                      VibeIconButton(
                        icon: VibeIcons.moreVertical,
                        onPressed: onShowMenu,
                        tooltip: 'Ещё',
                        color: context.vibeTextPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Одна строка листа выбора звонка.
class SheetCallTile extends StatelessWidget {
  const SheetCallTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: VibeTypography.body.copyWith(
          fontWeight: FontWeight.w600,
          color: context.vibeTextPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: VibeTypography.caption.copyWith(
          color: context.vibeTextTertiary,
        ),
      ),
      onTap: onTap,
    );
  }
}
