import 'package:flutter/material.dart';

import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_avatar.dart';
import '../../core/widgets/vibe_island.dart';
import '../../data/backend.dart';

/// Плитка чата в ленте: аватар, имя, превью, время-пилюля, pin, DND,
/// unread-бейдж, свайпы (архив / не беспокоить) и мультивыбор.
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
    required this.onTap,
    required this.onLongPress,
    required this.onDismissed,
    this.draft,
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

  /// Черновик чата («Черновик: …» вместо превью, как в Telegram).
  final String? draft;

  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(DismissDirection direction) onDismissed;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: VibeIsland(
        selected: selected,
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
    );
  }

  Widget _tile(BuildContext context) {
    final id = chat.id;
    final name = chat.title;
    final vPad = 2.0 + density * 5.0;

    return Dismissible(
      key: ValueKey('chat_$id'),
      direction: selectionMode
          ? DismissDirection.none
          : DismissDirection.horizontal,
      confirmDismiss: (_) async => !selectionMode,
      onDismissed: onDismissed,
      secondaryBackground: _swipeBackground(
        context: context,
        color: VibeColors.warning,
        icon: isDnd
            ? Icons.notifications_active_rounded
            : Icons.notifications_off_rounded,
        label: isDnd ? 'Включить уведомления' : 'Не беспокоить',
      ),
      background: _swipeBackground(
        context: context,
        color: VibeColors.surfaceElevatedDark,
        icon: isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
        label: isArchived ? 'Из архива' : 'Архив',
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: vPad),
        child: ListTile(
          onTap: onTap,
          onLongPress: onLongPress,
          leading: Hero(
            tag: 'avatar_${chat.id}',
            child: VibeAvatar(
              name: name,
              size: VibeSizes.avatarLg,
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
                    color: isDnd
                        ? context.vibeTextSecondary
                        : context.vibeTextPrimary,
                  ),
                ),
              ),
              if (pinned) ...[
                const SizedBox(width: VibeSpacing.xs),
                const Icon(
                  Icons.push_pin_rounded,
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
          subtitle: draft != null && draft!.isNotEmpty
              ? Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Черновик: ',
                        style: VibeTypography.body.copyWith(
                          color: context.vibePrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: draft,
                        style: VibeTypography.body.copyWith(
                          color: context.vibePrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : Text(
                  isArchived ? 'В архиве' : chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VibeTypography.body.copyWith(
                    color: context.vibeTextSecondary,
                    fontSize: 14,
                  ),
                ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pinned) ...[
                    const Icon(
                      Icons.push_pin_rounded,
                      size: 12,
                      color: VibeColors.vivid,
                    ),
                    const SizedBox(width: 4),
                  ],
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
                  // Мини-пилюля со временем/датой последнего сообщения (как в TG).
                  // На светлой теме — тёмная рамка и заметный фон, иначе
                  // пилюля сливается с белым рядом. Если сообщений ещё нет —
                  // пустой пузырь не рисуем, вместо него деликатная метка «Новый».
                  if (chat.lastTime.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.isDarkMode
                            ? context.vibeSurfaceElevated
                            : const Color(0xFFEFEDF8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: context.isDarkMode
                              ? context.vibeBorder.withValues(alpha: 0.6)
                              : const Color(0x291C1B22),
                        ),
                      ),
                      child: Text(
                        chat.lastTime,
                        style: VibeTypography.caption.copyWith(
                          fontSize: 10.5,
                          fontWeight: unread > 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: unread > 0
                              ? VibeColors.vivid
                              : context.vibeTextSecondary,
                        ),
                      ),
                    )
                  else if (unread == 0 && !isArchived)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: VibeColors.vivid.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Новый',
                        style: VibeTypography.caption.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: VibeColors.vivid,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (unread > 0)
                VibeUnreadBadge(count: unread, muted: isDnd),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swipeBackground({
    required BuildContext context,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      color: color,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: VibeSpacing.sm),
          Text(
            label,
            style: VibeTypography.bodyMedium.copyWith(color: Colors.white),
          ),
        ],
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
        return Icons.person_outline_rounded;
    }
  }
}
