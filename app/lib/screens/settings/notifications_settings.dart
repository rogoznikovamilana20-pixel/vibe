
import 'package:vibe_app/core/widgets/vibe_toast.dart';import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../core/widgets/vibe_chat_icon.dart';
import '../../core/widgets/vibe_top_bar.dart';
import '../../data/settings_service.dart';

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

  @override
  void initState() {
    super.initState();
    _personal = SettingsService.instance.notifyPersonal;
    _groups = SettingsService.instance.notifyGroups;
    _inAppSounds = SettingsService.instance.inAppSounds;
    _inAppVibration = SettingsService.instance.inAppVibration;
    _chatPreview = SettingsService.instance.chatPreview;
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
            icon: const Icon(Icons.arrow_back_rounded),
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
                icon: Icons.person_outline_rounded,
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
              SettingsTile(
                icon: Icons.campaign_outlined,
                iconColor: context.vibePrimary,
                title: l.channels,
                subtitle: l.active,
                onTap: () {},
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
            children: [
              SettingsTile(
                icon: Icons.refresh_rounded,
                iconColor: context.vibeError,
                title: l.resetNotifications,
                destructive: true,
                onTap: () {
                  VibeToast.show(context, l.resetNotifications);
                },
              ),
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
  }) {
    return SettingsTile(
      icon: icon,
      iconColor: color,
      iconWidget: iconWidget,
      title: title,
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

