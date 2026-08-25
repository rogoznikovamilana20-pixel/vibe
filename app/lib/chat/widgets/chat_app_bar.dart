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

/// Шапка чата: назад, аватар+имя+статус, действия (поиск/звонок/меню).
class ChatAppBar extends StatelessWidget {
  const ChatAppBar({
    super.key,
    required this.chat,
    this.groupTitle,
    this.peerTyping = false,
    this.typingUsers = const {},
    required this.onBack,
    this.onBackLongPress,
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
  final Set<String> typingUsers;

  final VoidCallback onBack;
  final VoidCallback? onBackLongPress;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenGroupInfo;
  final VoidCallback onOpenSearch;
  final VoidCallback onChooseCall;
  final VoidCallback onShowMenu;

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    final isGroup = chat.kind == 'group';
    final typing = peerTyping || typingUsers.isNotEmpty;
    final subtitle = typing
        ? null
        : (isGroup
              ? l.chatStatusGroup
              : (chat.peerOnline
                    ? l.statusOnline
                    : (chat.peerLastSeen != null
                          ? l.statusLastSeenAt.replaceFirst(
                              '{time}',
                              VibeBackend.formatTime(chat.peerLastSeen),
                            )
                          : l.statusRecently)));
    final subtitleColor = typing
        ? context.vibePrimary
        : ((!isGroup && chat.peerOnline)
              ? VibeColors.success
              : context.vibeTextTertiary);

    return Material(
      color: context.vibeGlass.withValues(
        alpha: context.isDarkMode ? 0.96 : 0.94,
      ),
      child: Container(
        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.vibeDivider)),
        ),
        child: Row(
          children: [
            if (MediaQuery.sizeOf(context).width < 900)
              VibeIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: onBack,
                onLongPress: onBackLongPress == null
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        onBackLongPress!.call();
                      },
                iconSize: 22,
                tooltip: l.tooltipBack,
                color: context.vibeTextPrimary,
              ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(VibeRadius.sm),
                onTap: isGroup ? onOpenGroupInfo : onOpenProfile,
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  if (!isGroup) onOpenProfile();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: VibeSpacing.xs,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'avatar_${chat.id}',
                        child: VibeAvatar(
                          name: chat.title,
                          size: 40,
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
            ),
            VibeIconButton(
              icon: VibeIcons.search,
              onPressed: onOpenSearch,
              tooltip: l.tooltipSearch,
              color: context.vibeTextPrimary,
            ),
            VibeIconButton(
              icon: Icons.call_outlined,
              onPressed: onChooseCall,
              tooltip: l.tooltipCall,
              color: context.vibeTextPrimary,
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
          fontWeight: FontWeight.w500,
          color: context.vibeTextPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: VibeTypography.caption.copyWith(color: context.vibeTextTertiary),
      ),
      onTap: onTap,
    );
  }
}
