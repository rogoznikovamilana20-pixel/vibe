import 'package:flutter/material.dart';

import '../../core/theme/vibe_animations.dart';
import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_avatar.dart';
import '../../data/backend.dart';
import '../../data/settings_service.dart';
import '../../screens/settings/notifications_settings.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';
import '../../core/localization/vibe_localizations.dart';

/// Меню чата как в Telegram: столбец «Уведомления» открывает подраздел,
/// из него — «Выключить на время» со списком длительностей. А кнопка
/// «Не беспокоить» в главном столбце работает сразу.
class ChatMenuSheet extends StatefulWidget {
  const ChatMenuSheet({
    super.key,
    required this.chat,
    required this.onSnack,
    this.onTapSearch,
    this.onTapMedia,
    this.onClearHistory,
    this.onChatInfo,
    this.onArchive,
    this.onDelete,
    this.onExport,
  });

  final VibeChat chat;
  final ValueChanged<String> onSnack;
  final VoidCallback? onTapSearch;
  final VoidCallback? onTapMedia;
  final VoidCallback? onClearHistory;

  /// 2.12: открыть «Сведения о чате» (вместо заглушки «в v2.0»).
  final VoidCallback? onChatInfo;

  /// 8.3.2: «Архивировать» / «Удалить чат» — рабочие действия.
  final VoidCallback? onArchive;
  final Future<bool> Function()? onDelete;

  /// 8.5: «Экспорт чата» — выгрузка истории в файл.
  final VoidCallback? onExport;

  @override
  State<ChatMenuSheet> createState() => _ChatMenuSheetState();
}

class _ChatMenuSheetState extends State<ChatMenuSheet> {
  /// 0 — главный столбец, 1 — «Уведомления», 2 — «Выключить на время».
  int _level = 0;

  late bool _muted;

  @override
  void initState() {
    super.initState();
    _muted = SettingsService.instance.mutedChats.contains(widget.chat.id);
  }

  void _setMuted(bool value) {
    setState(() => _muted = value);
    final ids = SettingsService.instance.mutedChats.toList();
    if (value && !ids.contains(widget.chat.id)) ids.add(widget.chat.id);
    if (!value) ids.remove(widget.chat.id);
    SettingsService.instance.setMutedChats(ids);
    // Облачный DND (как в TG): muted_until на сервере.
    VibeBackend.instance.setChatMuted(widget.chat.id, muted: value);
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          VibeSpacing.lg,
          0,
          VibeSpacing.lg,
          VibeSpacing.lg,
        ),
        child: AnimatedSize(
          duration: VibeAnimations.fast,
          curve: Curves.easeOut,
          child: _level == 0
              ? _buildMainColumn(context, l)
              : _level == 1
                  ? _buildNotificationsColumn(context, l)
                  : _buildMuteForAWhileColumn(context, l),
        ),
      ),
    );
  }

  Widget _buildMainColumn(BuildContext context, VibeLocalizations l) {
    final chat = widget.chat;
    final isGroup = chat.kind == 'group';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            VibeAvatar(
              name: chat.title,
              size: VibeSizes.avatarMd,
              online: chat.peerOnline,
              photoUrl: chat.peerAvatar,
            ),
            const SizedBox(width: VibeSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.title,
                    style: VibeTypography.subtitle.copyWith(
                      color: context.vibeTextPrimary,
                    ),
                  ),
                  Text(
                    isGroup
                        ? l.chatStatusGroup
                        : (chat.peerOnline
                            ? l.statusOnline
                            : (chat.peerLastSeen != null
                                ? 'был(а) в сети '
                                    '${VibeBackend.formatTime(chat.peerLastSeen)}'
                                : l.statusRecently)),
                    style: VibeTypography.caption.copyWith(
                      color: chat.peerOnline
                          ? VibeColors.success
                          : context.vibeTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: VibeSpacing.md),
        const Divider(height: 1),
        const SizedBox(height: VibeSpacing.xs),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.notifications_none_rounded,
              color: context.vibePrimary),
          title: Text(l.chatMenuNotifications),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () => setState(() => _level = 1),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            _muted ? Icons.volume_off_rounded : Icons.volume_up_outlined,
            color: _muted ? context.vibeError : context.vibePrimary,
          ),
          title: Text(_muted ? l.chatMenuSoundOff : l.chatMenuDnd),
          trailing: Switch(
            value: _muted,
            onChanged: _setMuted,
          ),
          onTap: () => _setMuted(!_muted),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.photo_library_outlined, color: context.vibePrimary),
          title: Text(l.chatMenuMedia),
          onTap: () {
            Navigator.of(context).pop();
            widget.onTapMedia?.call();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(VibeIcons.search, color: context.vibePrimary),
          title: Text(l.chatMenuSearch),
          onTap: () {
            Navigator.of(context).pop();
            widget.onTapSearch?.call();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(VibeIcons.info,
              color: context.vibePrimary),
          title: Text(l.chatMenuChatInfo),
          onTap: () {
            Navigator.of(context).pop();
            final info = widget.onChatInfo;
            if (info != null) {
              info();
            } else {
              widget.onSnack('Сведения о чате — в v2.0');
            }
          },
        ),
        // 8.3.2: архив и удаление — как в структуре меню ТГ.
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.archive_outlined, color: context.vibePrimary),
          title: Text(l.chatMenuArchive),
          onTap: () {
            Navigator.of(context).pop();
            final archive = widget.onArchive;
            if (archive != null) {
              archive();
            } else {
              widget.onSnack('Архив — скоро');
            }
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_outline_rounded, color: context.vibeError),
          title: Text(l.chatMenuDeleteChat, style: TextStyle(color: context.vibeError)),
          onTap: () async {
            Navigator.of(context).pop();
            final del = widget.onDelete;
            if (del == null) {
              widget.onSnack('Удаление — скоро');
              return;
            }
            final ok = await del();
            if (ok) widget.onSnack('Чат удалён');
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_outline_rounded,
              color: context.vibePrimary),
          title: Text(l.chatMenuClearHistory),
          onTap: () {
            Navigator.of(context).pop();
            final clear = widget.onClearHistory;
            if (clear != null) {
              clear();
            } else {
              widget.onSnack('Очистить историю — в v2.0');
            }
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.file_upload_outlined, color: context.vibePrimary),
          title: Text(l.chatMenuExport),
          onTap: () {
            Navigator.of(context).pop();
            final export = widget.onExport;
            if (export != null) {
              export();
            } else {
              widget.onSnack('Экспорт — скоро');
            }
          },
        ),
      ],
    );
  }

  Widget _buildNotificationsColumn(BuildContext context, VibeLocalizations l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(VibeIcons.back, size: 20),
          title: Text(l.chatMenuNotifications),
          onTap: () => setState(() => _level = 0),
        ),
        const Divider(height: 1),
        const SizedBox(height: VibeSpacing.xs),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            _muted ? Icons.volume_off_rounded : Icons.volume_up_outlined,
            color: context.vibePrimary,
          ),
          title: Text(l.chatMenuMuteSound),
          trailing: Switch(value: _muted, onChanged: _setMuted),
          onTap: () => _setMuted(!_muted),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.timer_outlined, color: context.vibePrimary),
          title: Text(l.chatMenuMuteForAWhile),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () => setState(() => _level = 2),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.tune_rounded, color: context.vibePrimary),
          title: Text(l.chatMenuConfigure),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsSettingsScreen(),
              ),
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.notifications_off_rounded, color: context.vibeError),
          title: Text(
            l.chatMenuNotifications,
            style: TextStyle(color: context.vibeError),
          ),
          onTap: () {
            _setMuted(true);
            Navigator.of(context).pop();
            widget.onSnack('Уведомления выключены');
          },
        ),
      ],
    );
  }

  Widget _buildMuteForAWhileColumn(BuildContext context, VibeLocalizations l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(VibeIcons.back, size: 20),
          title: Text(l.chatMenuMuteForAWhile),
          onTap: () => setState(() => _level = 1),
        ),
        const Divider(height: 1),
        const SizedBox(height: VibeSpacing.xs),
        for (final entry in [
          (label: l.muteDuration1Hour, duration: const Duration(hours: 1)),
          (label: l.muteDuration8Hours, duration: const Duration(hours: 8)),
          (label: l.muteDuration1Day, duration: const Duration(days: 1)),
          (label: l.muteDuration2Days, duration: const Duration(days: 2)),
          (label: l.muteDuration1Week, duration: const Duration(days: 7)),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(VibeIcons.clock, color: context.vibePrimary),
            title: Text(entry.label),
            onTap: () {
              _setMuted(true);
              final until = DateTime.now().add(entry.duration);
              VibeBackend.instance.setChatMuted(
                widget.chat.id,
                muted: true,
                forever: false,
                until: until,
              );
              Navigator.of(context).pop();
              widget.onSnack('Звук выключен на ${entry.label}');
            },
          ),
      ],
    );
  }
}
