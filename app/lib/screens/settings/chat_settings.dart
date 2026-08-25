import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../core/widgets/vibe_top_bar.dart';
import '../../data/settings_service.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Экран настроек свайпа по чату — как TG SwipeGestureSettingsView.
/// Одно действие, по умолчанию архив (SharedConfig.getChatSwipeAction).
class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  late ChatSwipeAction _action;

  @override
  void initState() {
    super.initState();
    _action = SettingsService.instance.chatSwipeAction;
  }

  void _set(ChatSwipeAction a) {
    setState(() => _action = a);
    HapticFeedback.selectionClick();
    SettingsService.instance.setChatSwipeAction(a);
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
          title: VibeTopBarTitle(l.settingsSwipeTitle),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VibeSpacing.lg),
        children: [
          RadioGroup<ChatSwipeAction>(
            groupValue: _action,
            onChanged: (v) {
              if (v != null) _set(v);
            },
            child: SettingsSection(
              title: l.settingsSwipeSubtitle,
              children: [
                _radio(
                  value: ChatSwipeAction.archive,
                  icon: VibeIcons.archive,
                  color: context.vibePrimary,
                  title: l.settingsSwipeArchive,
                ),
                _radio(
                  value: ChatSwipeAction.read,
                  icon: Icons.mark_chat_read_rounded,
                  color: context.vibePrimary,
                  title: l.settingsSwipeRead,
                ),
                _radio(
                  value: ChatSwipeAction.mute,
                  icon: Icons.notifications_off_rounded,
                  color: context.vibePrimary,
                  title: l.settingsSwipeMute,
                ),
                _radio(
                  value: ChatSwipeAction.pin,
                  icon: VibeIcons.pin,
                  color: VibeColors.primary,
                  title: l.settingsSwipePin,
                ),
                _radio(
                  value: ChatSwipeAction.delete,
                  icon: Icons.delete_outline_rounded,
                  color: VibeColors.error,
                  title: l.settingsSwipeDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _radio({
    required ChatSwipeAction value,
    required IconData icon,
    required Color color,
    required String title,
  }) {
    return SettingsTile(
      icon: icon,
      iconColor: color,
      title: title,
      trailing: Radio<ChatSwipeAction>(
        value: value,
        activeColor: context.vibePrimary,
      ),
      onTap: () => _set(value),
    );
  }
}
