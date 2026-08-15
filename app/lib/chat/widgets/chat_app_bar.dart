import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_avatar.dart';
import '../../core/widgets/vibe_icon_button.dart';
import '../../data/backend.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';
import '../../core/localization/vibe_localizations.dart';

/// Анимированные точки «печатает…» как в Telegram.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_ctrl.value - i * 0.15).clamp(0.0, 1.0);
            final bounce = t < 0.5
                ? Curves.easeOut.transform(t * 2)
                : Curves.easeIn.transform(1.0 - (t - 0.5) * 2);
            return Transform.translate(
              offset: Offset(0, -2 * bounce),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.vibePrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Стеклянная пилюля шапки чата — как в Telegram: одна плавающая капсула.
/// Использует стекло темы, поэтому дружит и со светлой, и с тёмной темой.
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
    final l = VibeLocalizations.of(context);
    final isGroup = chat.kind == 'group';
    final typing = !isGroup && peerTyping;
    final subtitle = typing
        ? null
        : (isGroup
            ? l.chatStatusGroup
            : (chat.peerOnline
                ? l.statusOnline
                : (chat.peerLastSeen != null
                    ? 'был(а) в сети ${VibeBackend.formatTime(chat.peerLastSeen)}'
                    : l.statusRecently)));
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
                iconSize: 22,
                tooltip: l.tooltipBack,
                color: context.vibeTextPrimary,
              ),
              const SizedBox(width: VibeSpacing.xs),
              Expanded(
                child: _HeaderPill(
                  onTap: isGroup ? onOpenGroupInfo : onOpenProfile,
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    if (!isGroup) onOpenProfile();
                  },
                  child: Row(
                    children: [
                      Hero(
                        tag: 'avatar_${chat.id}',
                        child: VibeAvatar(
                          name: chat.title,
                          size: 38,
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
                            if (typing)
                              const _TypingDots()
                            else
                              Text(
                                subtitle ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: VibeTypography.caption.copyWith(
                                  fontSize: 13,
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
                        tooltip: l.tooltipSearch,
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
                        tooltip: l.tooltipCall,
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
                        tooltip: l.tooltipMore,
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
