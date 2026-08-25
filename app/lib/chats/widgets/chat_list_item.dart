import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_avatar.dart';
import '../../data/backend.dart';
import '../../data/settings_service.dart';
import 'full_swipe.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Плитка чата в ленте: аватар, имя, превью, время-пилюля, pin, DND,
/// unread-бейдж, полный свайп (одно действие, как в Telegram) и
/// мультивыбор.
///
/// Контракт: все данные и callbacks приходят снаружи (screen/controller);
/// сам виджет не знает про backend.
class ChatListItem extends StatelessWidget {
  const ChatListItem({
    super.key,
    required this.chat,
    required this.selected,
    required this.isArchived,
    required this.isDnd,
    required this.pinned,
    required this.unread,
    required this.selectionMode,
    required this.density,
    required this.swipeAction,
    required this.onTap,
    required this.onLongPress,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    this.draft,
    this.typing = false,
  });

  final VibeChat chat;
  final bool selected;
  final bool isArchived;
  final bool isDnd;
  final bool pinned;
  final int unread;
  final bool selectionMode;

  /// 0 — компактно, 1 — просторно.
  final double density;

  /// Действие свайпа влево (настраивается, как в TG).
  final ChatSwipeAction swipeAction;

  /// Черновик чата («Черновик: …» вместо превью, как в Telegram).
  final String? draft;

  /// Собеседник печатает (как в Telegram): «печатает…» вместо превью.
  final bool typing;

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// Свайп влево → выбранное действие (архив/прочитано/мут/закреп/удалить).
  final VoidCallback onSwipeLeft;

  /// Свайп вправо → вернуть из архива (как в Telegram).
  final VoidCallback onSwipeRight;

  /// Цвет/иконка действия свайпа влево (TG: archiveBackground для всех,
  /// dialogSwipeRemove — для удаления).
  ({Color color, IconData icon}) _swipeStyle(BuildContext context) {
    switch (swipeAction) {
      case ChatSwipeAction.delete:
        return (color: VibeColors.error, icon: Icons.delete_outline_rounded);
      case ChatSwipeAction.read:
        return (
          color: context.vibePrimary,
          icon: unread > 0
              ? Icons.mark_chat_read_rounded
              : Icons.mark_chat_unread_rounded,
        );
      case ChatSwipeAction.mute:
        return (
          color: context.vibePrimary,
          icon: isDnd
              ? Icons.notifications_active_rounded
              : Icons.notifications_off_rounded,
        );
      case ChatSwipeAction.pin:
        return (color: context.vibePrimary, icon: VibeIcons.pin);
      case ChatSwipeAction.archive:
        return (color: context.vibePrimary, icon: VibeIcons.archive);
    }
  }

  String _swipeLabel(BuildContext context) {
    final l = VibeLocalizations.of(context);
    return switch (swipeAction) {
      ChatSwipeAction.delete => l.dialogDelete,
      ChatSwipeAction.read =>
        unread > 0 ? l.chatMarkRead : l.chatMarkUnread,
      ChatSwipeAction.mute =>
        isDnd ? l.chatEnableNotifications : l.chatDoNotDisturb,
      ChatSwipeAction.pin => pinned ? l.chatUnpinChat : l.chatPinChat,
      ChatSwipeAction.archive =>
        isArchived ? l.chatSwipeFromArchive : l.chatSwipeArchive,
    };
  }

  Widget _swipeBackground({
    required BuildContext context,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return ColoredBox(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: VibeSpacing.sm),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VibeTypography.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    final style = _swipeStyle(context);
    return RepaintBoundary(
      child: FullSwipe(
        enabled: !selectionMode,
        onSwipeLeft: () {
          HapticFeedback.mediumImpact();
          onSwipeLeft();
        },
        leftBackground: _swipeBackground(
          context: context,
          color: style.color,
          icon: style.icon,
          label: _swipeLabel(context),
        ),
        onSwipeRight: () {
          HapticFeedback.mediumImpact();
          onSwipeRight();
        },
        rightBackground: _swipeBackground(
          context: context,
          color: context.vibePrimary,
          icon: VibeIcons.archive,
          label: l.chatSwipeFromArchive,
        ),
        onTileTap: onTap,
        onTileLongPress: () {
          HapticFeedback.mediumImpact();
          onLongPress();
        },
        child: Material(
          color: selected
              ? context.vibePrimary.withValues(alpha: 0.12)
              : Colors.transparent,
          child: Stack(
            children: [
              _tile(context),
              if (selected)
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: context.vibePrimary,
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context) {
    final l = VibeLocalizations.of(context);
    final name = chat.title;
    // TG exact: 72dp row, 52dp avatar, tighter vertical.
    final vPad = density == 0 ? 5.0 : 7.0;

    return Padding(
        padding: EdgeInsets.symmetric(vertical: vPad),
        child: ListTile(
          minVerticalPadding: 8,
          minTileHeight: 72,
          contentPadding: const EdgeInsets.only(left: 68, right: 10),
          leading: Hero(
            tag: 'avatar_${chat.id}',
            child: VibeAvatar(
              name: name,
              size: 52,
              online: chat.peerOnline,
              photoUrl: chat.peerAvatar,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: VibeTypography.subtitle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 20 / 16,
                    color: isDnd
                        ? context.vibeTextSecondary
                        : context.vibeTextPrimary,
                  ),
                ),
              ),
              if (pinned) ...[
                const SizedBox(width: VibeSpacing.xs),
                const Icon(
                  VibeIcons.pin,
                  size: 16,
                  color: VibeColors.vivid,
                ),
              ],
              if (isDnd) ...[
                const SizedBox(width: VibeSpacing.xs),
                Icon(
                  Icons.notifications_off_rounded,
                  size: 16,
                  color: context.vibeTextTertiary,
                ),
              ],
            ],
          ),
          subtitle: typing
              ? Text(
                  l.chatTyping,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VibeTypography.body.copyWith(
                    color: context.vibePrimary,
                    fontSize: 14,
                    height: 18 / 14,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : draft != null && draft!.isNotEmpty
              ? Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: l.chatDraftLabel,
                        style: VibeTypography.body.copyWith(
                          color: context.vibePrimary,
                          fontSize: 14,
                          height: 18 / 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: draft,
                        style: VibeTypography.body.copyWith(
                          color: context.vibeTextSecondary,
                          fontSize: 14,
                          height: 18 / 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : Text(
                  isArchived ? l.chatInArchive : chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VibeTypography.body.copyWith(
                    color: context.vibeTextSecondary,
                    fontSize: 14,
                    height: 18 / 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (chat.kind != 'pm') ...[
                    Icon(
                      _typeIcon(chat.kind),
                      size: 15,
                      color: context.vibeTextTertiary,
                    ),
                    const SizedBox(width: 5),
                  ],
                  if (unread > 0 && isDnd) ...[
                    const Icon(Icons.circle, size: 6, color: VibeColors.vivid),
                    const SizedBox(width: 4),
                  ],
                  // TG exact: flat time 12sp, no pill, tertiary / accent when unread.
                  if (chat.lastTime.isNotEmpty)
                    Text(
                      chat.lastTime,
                      style: VibeTypography.caption.copyWith(
                        fontSize: 12,
                        fontWeight:
                            unread > 0 ? FontWeight.w500 : FontWeight.w400,
                        color: unread > 0
                            ? context.vibePrimary
                            : context.vibeTextTertiary,
                      ),
                    )
                  else if (unread == 0 && !isArchived)
                    Text(
                      l.chatNew,
                      style: VibeTypography.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.vibePrimary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (unread > 0)
                VibeUnreadBadge(count: unread, muted: isDnd),
            ],
          ),
        ),
    );
  }

  IconData _typeIcon(String kind) {
    switch (kind) {
      case 'group':
        return Icons.people_alt_outlined;
      case 'channel':
        return Icons.campaign_outlined;
      case 'biz':
        return Icons.business_outlined;
      default:
        return VibeIcons.user;
    }
  }
}