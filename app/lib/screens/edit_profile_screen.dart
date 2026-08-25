import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/widgets/vibe_button.dart';
import '../core/widgets/vibe_input.dart';
import '../core/widgets/settings_widgets.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/backend.dart';
import '../data/backend_api.dart';
import 'aurion_screen.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';
import '../core/localization/vibe_localizations.dart';

/// Редактирование данных аккаунта — аналог экрана
/// «Изменить данные» в профиле Telegram.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.backend});

  /// Инжектируемый бэкенд (widget-тесты); null — живой `VibeBackend`.
  final VibeBackendApi? backend;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final VibeBackendApi _backend = widget.backend ?? LiveVibeBackend();
  bool _saving = false;
  bool _usernameTaken = false;
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    final p = VibeBackend.myProfileNotifier.value;
    _name = TextEditingController(text: p?.displayName ?? '');
    _username = TextEditingController(text: p?.username ?? '');
    _bio = TextEditingController(text: p?.bio ?? '');
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  /// Живая проверка ника на занятость (с дебаунсом, как в Telegram).
  Future<void> _checkUsername(String val) async {
    _checkTimer?.cancel();
    final clean = val.trim();
    final mine = VibeBackend.myProfileNotifier.value?.username ?? '';
    if (clean.isEmpty || clean.toLowerCase() == mine.toLowerCase()) {
      setState(() => _usernameTaken = false);
      return;
    }
    _checkTimer = Timer(const Duration(milliseconds: 300), () async {
      final available = await _backend.isUsernameAvailable(clean);
      if (!mounted) return;
      setState(() => _usernameTaken = !available);
    });
  }

  Future<void> _save() async {
    final l = VibeLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack(l.profileEnterName);
      return;
    }
    if (_usernameTaken) {
      _snack(l.profileUsernameTaken);
      return;
    }
    setState(() => _saving = true);
    try {
      await _backend.updateProfile(
        username: _username.text.trim().isEmpty
            ? (VibeBackend.myProfileNotifier.value?.username ?? 'user')
            : _username.text.trim(),
        displayName: name,
        bio: _bio.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack(l.profileSavedSynced);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(l.profileSaveFailed);
    }
  }

  void _snack(String msg) {
    VibeToast.show(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    final userName =
        VibeBackend.myProfileNotifier.value?.displayName ?? l.profileDefaultName;
    return Scaffold(
      body: Column(
        children: [
          VibeTopBar(
            leading: IconButton(
              icon: const Icon(VibeIcons.back),
              onPressed: () => Navigator.of(context).pop(),
              color: context.vibeTextPrimary,
            ),
            title: VibeTopBarTitle(l.profileEditData),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: VibeSpacing.lg,
                vertical: VibeSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VibeInput(
                    controller: _name,
                    hint: l.profileScreenNameHint,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: VibeSpacing.md),
                  VibeInput(
                    controller: _username,
                    hint: l.profileScreenNickHint,
                    errorText: _usernameTaken ? l.profileUsernameTaken : null,
                    onChanged: _checkUsername,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: VibeSpacing.md),
                  VibeInput(
                    controller: _bio,
                    hint: l.profileScreenBioHint,
                    maxLines: 3,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: VibeSpacing.md),
                  SettingsSection(
                    children: [
                      SettingsTile(
                        icon: Icons.badge_outlined,
                        iconColor: context.vibePrimary,
                        title: l.profileInfo,
                        subtitle: l.profileInfoSubtitle,
                        onTap: () => _snack(l.profileInfoSoon),
                      ),
                      SettingsTile(
                        icon: Icons.campaign_outlined,
                        iconColor: context.vibePrimary,
                        title: l.profilePersonalChannel,
                        subtitle: l.profileChannelSubtitle,
                        onTap: () => _snack(l.profileChannelSoon),
                      ),
                      SettingsTile(
                        icon: Icons.auto_awesome_rounded,
                        iconColor: context.vibePrimary,
                        title: l.profileAutomation,
                        subtitle: l.profileAurionSubtitle,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AurionScreen(userName: userName),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: VibeSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: VibeButton(
                      type: VibeButtonType.primary,
                      label: _saving ? l.actionSaving : l.dialogSave,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
