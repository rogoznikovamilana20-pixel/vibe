
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../core/widgets/vibe_chat_icon.dart';
import '../../core/widgets/vibe_top_bar.dart';
import '../../data/settings_service.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  late bool _personal;
  late bool _groups;
  late bool _inAppSounds;
  late bool _inAppVibration;
  late bool _chatPreview;
  late bool _badgeEnabled;
  late bool _quietHoursEnabled;
  late int _quietHoursStart;
  late int _quietHoursEnd;

  @override
  void initState() {
    super.initState();
    final s = SettingsService.instance;
    _personal = s.notifyPersonal;
    _groups = s.notifyGroups;
    _inAppSounds = s.inAppSounds;
    _inAppVibration = s.inAppVibration;
    _chatPreview = s.chatPreview;
    _badgeEnabled = s.badgeEnabled;
    _quietHoursEnabled = s.quietHoursEnabled;
    _quietHoursStart = s.quietHoursStart;
    _quietHoursEnd = s.quietHoursEnd;
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _quietHoursStart : _quietHoursEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: context.vibeSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _quietHoursStart = picked.hour;
          SettingsService.instance.setQuietHoursStart(picked.hour);
        } else {
          _quietHoursEnd = picked.hour;
          SettingsService.instance.setQuietHoursEnd(picked.hour);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.vibeBackground,
      appBar: VibeTopBarAppBar(
        topInset: MediaQuery.paddingOf(context).top,
        child: VibeTopBar(
          leading: IconButton(
            icon: const Icon(VibeIcons.back),
            onPressed: () => Navigator.of(context).pop(),
            color: context.vibeTextPrimary,
          ),
          title: VibeTopBarTitle(l.notifications),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VibeSpacing.lg),
        children: [
          SettingsSection(
            title: l.notificationsFromChats,
            children: [
              _buildSwitchTile(
                icon: VibeIcons.user,
                color: context.vibePrimary,
                title: l.personalChats,
                value: _personal,
                onChanged: (v) {
                  setState(() => _personal = v);
                  SettingsService.instance.setNotifyPersonal(v);
                },
              ),
              _buildSwitchTile(
                icon: Icons.group_outlined,
                color: context.vibePrimary,
                title: l.groups,
                value: _groups,
                onChanged: (v) {
                  setState(() => _groups = v);
                  SettingsService.instance.setNotifyGroups(v);
                },
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            title: l.inApp,
            children: [
              _buildSwitchTile(
                icon: Icons.volume_up_outlined,
                color: context.vibePrimary,
                title: l.inAppSounds,
                value: _inAppSounds,
                onChanged: (v) {
                  setState(() => _inAppSounds = v);
                  SettingsService.instance.setInAppSounds(v);
                },
              ),
              _buildSwitchTile(
                icon: Icons.vibration_rounded,
                color: context.vibePrimary,
                title: l.vibration,
                value: _inAppVibration,
                onChanged: (v) {
                  setState(() => _inAppVibration = v);
                  SettingsService.instance.setInAppVibration(v);
                },
              ),
              _buildSwitchTile(
                icon: Icons.chat_bubble_outline_rounded,
                color: context.vibePrimary,
                iconWidget: VibeChatIcon(
                  size: 18,
                  color: context.vibePrimary,
                ),
                title: l.chatPreview,
                value: _chatPreview,
                onChanged: (v) {
                  setState(() => _chatPreview = v);
                  SettingsService.instance.setChatPreview(v);
                },
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            title: 'Badge и тихие часы',
            children: [
              _buildSwitchTile(
                icon: Icons.notifications_active_outlined,
                color: context.vibePrimary,
                title: 'Счётчик на иконке',
                subtitle: _badgeEnabled ? 'Показывать' : 'Скрыт',
                value: _badgeEnabled,
                onChanged: (v) {
                  setState(() => _badgeEnabled = v);
                  SettingsService.instance.setBadgeEnabled(v);
                },
              ),
              _buildSwitchTile(
                icon: Icons.do_not_disturb_on_outlined,
                color: context.vibePrimary,
                title: 'Тихие часы',
                subtitle: _quietHoursEnabled
                    ? '${_quietHoursStart.toString().padLeft(2, '0')}:00 — ${_quietHoursEnd.toString().padLeft(2, '0')}:00'
                    : 'Выкл',
                value: _quietHoursEnabled,
                onChanged: (v) {
                  setState(() => _quietHoursEnabled = v);
                  SettingsService.instance.setQuietHoursEnabled(v);
                },
              ),
              if (_quietHoursEnabled) ...[
                SettingsTile(
                  icon: Icons.access_time_rounded,
                  iconColor: context.vibePrimary,
                  title: 'Начало',
                  subtitle: '${_quietHoursStart.toString().padLeft(2, '0')}:00',
                  onTap: () => _pickTime(isStart: true),
                ),
                SettingsTile(
                  icon: Icons.access_time_filled_rounded,
                  iconColor: context.vibePrimary,
                  title: 'Конец',
                  subtitle: '${_quietHoursEnd.toString().padLeft(2, '0')}:00',
                  onTap: () => _pickTime(isStart: false),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color color,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? iconWidget,
    String? subtitle,
  }) {
    return SettingsTile(
      icon: icon,
      iconColor: color,
      iconWidget: iconWidget,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        onChanged: (v) {
          HapticFeedback.selectionClick();
          onChanged(v);
        },
        activeTrackColor: context.vibePrimary.withValues(alpha: 0.3),
        activeThumbColor: context.vibePrimary,
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
    );
  }
}
