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
  });

  final VibeChat chat;
  final ValueChanged<String> onSnack;
  final VoidCallback? onTapSearch;
  final VoidCallback? onTapMedia;
  final VoidCallback? onClearHistory;

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
              ? _buildMainColumn(context)
              : _level == 1
                  ? _buildNotificationsColumn(context)
                  : _buildMuteForAWhileColumn(context),
        ),
      ),
    );
  }

  Widget _buildMainColumn(BuildContext context) {
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
                        ? 'Группа'
                        : (chat.peerOnline
                            ? 'в сети'
                            : (chat.peerLastSeen != null
                                ? 'был(а) в сети '
                                    '${VibeBackend.formatTime(chat.peerLastSeen)}'
                                : 'был(а) недавно')),
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
          title: const Text('Уведомления'),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () => setState(() => _level = 1),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            _muted ? Icons.volume_off_rounded : Icons.volume_up_outlined,
            color: _muted ? VibeColors.error : context.vibePrimary,
          ),
          title: Text(_muted ? 'Звук выключен' : 'Не беспокоить'),
          trailing: Switch(
            value: _muted,
            onChanged: _setMuted,
          ),
          onTap: () => _setMuted(!_muted),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.photo_library_outlined, color: context.vibePrimary),
          title: const Text('Медиа'),
          onTap: () {
            Navigator.of(context).pop();
            widget.onTapMedia?.call();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.search_rounded, color: context.vibePrimary),
          title: const Text('Поиск в чате'),
          onTap: () {
            Navigator.of(context).pop();
            widget.onTapSearch?.call();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline_rounded,
              color: context.vibePrimary),
          title: const Text('Сведения о чате'),
          onTap: () {
            Navigator.of(context).pop();
            widget.onSnack('Сведения о чате — в v2.0');
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_outline_rounded,
              color: context.vibePrimary),
          title: const Text('Очистить историю'),
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
      ],
    );
  }

  Widget _buildNotificationsColumn(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.arrow_back_rounded, size: 20),
          title: const Text('Уведомления'),
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
          title: const Text('Выключить звук'),
          trailing: Switch(value: _muted, onChanged: _setMuted),
          onTap: () => _setMuted(!_muted),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.timer_outlined, color: context.vibePrimary),
          title: const Text('Выключить на время'),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () => setState(() => _level = 2),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.tune_rounded, color: context.vibePrimary),
          title: const Text('Настроить'),
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
          leading: const Icon(Icons.notifications_off_rounded, color: VibeColors.error),
          title: const Text(
            'Выключить уведомления',
            style: TextStyle(color: VibeColors.error),
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

  Widget _buildMuteForAWhileColumn(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.arrow_back_rounded, size: 20),
          title: const Text('Выключить на время'),
          onTap: () => setState(() => _level = 1),
        ),
        const Divider(height: 1),
        const SizedBox(height: VibeSpacing.xs),
        for (final entry in {
          '1 час': const Duration(hours: 1),
          '8 часов': const Duration(hours: 8),
          '1 день': const Duration(days: 1),
          '2 дня': const Duration(days: 2),
          '1 неделя': const Duration(days: 7),
        }.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule_rounded, color: context.vibePrimary),
            title: Text(entry.key),
            onTap: () {
              _setMuted(true);
              final until = DateTime.now().add(entry.value);
              VibeBackend.instance.setChatMuted(
                widget.chat.id,
                muted: true,
                forever: false,
                until: until,
              );
              Navigator.of(context).pop();
              widget.onSnack('Звук выключен на ${entry.key}');
            },
          ),
      ],
    );
  }
}
