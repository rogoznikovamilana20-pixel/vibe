import 'package:flutter/material.dart';
import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../core/widgets/vibe_toast.dart';
import '../../core/widgets/vibe_top_bar.dart';
import '../../data/backend.dart';
import '../../data/settings_service.dart';
import '../../data/passcode_service.dart';
import 'privacy/privacy_selector_screen.dart';
import 'privacy/passcode_screen.dart';
import 'privacy/devices_screen.dart';
import 'privacy/two_step_verification_screen.dart';
import 'privacy/devices_screen.dart';
import '../auth/otp_verification_screen.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  /// Значение приватности (0 — Все, 1 — Контакты, 2 — Никто) → иконка и подпись.
  ({IconData icon, String label}) _privacyLabel(int val, VibeLocalizations l) {
    if (val == 1) {
      return (icon: Icons.people_alt_rounded, label: l.contacts);
    }
    if (val == 2) {
      return (icon: Icons.person_off_rounded, label: l.nobody);
    }
    return (icon: Icons.public_rounded, label: l.all);
  }

  /// Подпись с иконкой уровня приватности — как маленький бейдж.
  Widget _privacyBadge(BuildContext context, VibeLocalizations l, int val) {
    final spec = _privacyLabel(val, l);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(spec.icon, size: 13, color: context.vibeTextSecondary),
        const SizedBox(width: VibeSpacing.xs),
        Text(
          spec.label,
          style: VibeTypography.caption.copyWith(
            color: context.vibeTextSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    final s = SettingsService.instance;
    
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
          title: VibeTopBarTitle(l.privacy),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VibeSpacing.lg),
        children: [
          SettingsSection(
            title: l.security,
            children: [
              SettingsTile(
                icon: Icons.vpn_key_outlined,
                iconColor: Colors.orange,
                title: l.twoStep,
                subtitle: l.off,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TwoStepVerificationScreen()),
                ).then((_) => setState(() {})),
              ),
              SettingsTile(
                icon: Icons.phonelink_lock_rounded,
                iconColor: Colors.green,
                title: l.passcode,
                subtitle: PasscodeService.instance.hasPasscode ? l.active : l.off,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PasscodeSettingsScreen()),
                ).then((_) => setState(() {})),
              ),
              SettingsTile(
                icon: Icons.devices_rounded,
                iconColor: Colors.blue,
                title: l.devices,
                subtitle: l.locale.languageCode == 'ru' ? '1 активная сессия' : '1 active session',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DevicesScreen()),
                ),
              ),
              SettingsTile(
                icon: Icons.sms_rounded,
                iconColor: Colors.teal,
                title: l.locale.languageCode == 'ru' ? 'Верификация телефона' : 'Phone verification',
                subtitle: l.locale.languageCode == 'ru' ? 'Подтвердить номер через SMS' : 'Verify number via SMS',
                onTap: () {
                  final phone = VibeBackend.instance.myProfile?.phone ?? '';
                  if (phone.isEmpty) {
                    VibeToast.show(context, 'Номер телефона не задан');
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OtpVerificationScreen(phone: phone)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            title: l.privacy,
            children: [
              SettingsTile(
                icon: Icons.phone_android_rounded,
                iconColor: Colors.purple,
                title: l.phoneNumber,
                subtitleWidget: _privacyBadge(context, l, s.privacyPhone),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrivacySelectorScreen(
                      title: l.phoneNumber,
                      description: l.whoCanSeePhone,
                      initialValue: s.privacyPhone,
                      onChanged: (v) => s.setPrivacyPhone(v).then((_) => setState(() {})),
                    ),
                  ),
                ),
              ),
              SettingsTile(
                icon: Icons.access_time_rounded,
                iconColor: Colors.lightBlue,
                title: l.lastActivity,
                subtitleWidget: _privacyBadge(context, l, s.privacyLastSeen),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrivacySelectorScreen(
                      title: l.lastActivity,
                      description: l.whoCanSeeLastSeen,
                      initialValue: s.privacyLastSeen,
                      onChanged: (v) => s.setPrivacyLastSeen(v).then((_) => setState(() {})),
                    ),
                  ),
                ),
              ),
              SettingsTile(
                icon: Icons.account_circle_outlined,
                iconColor: Colors.teal,
                title: l.profilePhoto,
                subtitleWidget: _privacyBadge(context, l, s.privacyPhoto),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrivacySelectorScreen(
                      title: l.profilePhoto,
                      description: l.whoCanSeePhoto,
                      initialValue: s.privacyPhoto,
                      onChanged: (v) => s.setPrivacyPhoto(v).then((_) => setState(() {})),
                    ),
                  ),
                ),
              ),
              SettingsTile(
                icon: Icons.forward_rounded,
                iconColor: Colors.redAccent,
                title: l.forwarding,
                subtitleWidget: _privacyBadge(context, l, s.privacyForward),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrivacySelectorScreen(
                      title: l.forwarding,
                      description: l.locale.languageCode == 'ru' ? 'Кто может ссылаться на мой аккаунт при пересылке сообщений' : 'Who can link to my account when forwarding my messages',
                      initialValue: s.privacyForward,
                      onChanged: (v) => s.setPrivacyForward(v).then((_) => setState(() {})),
                    ),
                  ),
                ),
              ),
              SettingsTile(
                icon: VibeIcons.phone,
                iconColor: Colors.green,
                title: l.callsAndGroups,
                subtitleWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _privacyBadge(context, l, s.privacyCalls),
                    const SizedBox(width: VibeSpacing.md),
                    _privacyBadge(context, l, s.privacyGroups),
                  ],
                ),
                onTap: () => _showCallsGroupsMenu(context, l, s),
              ),
              SettingsTile(
                icon: Icons.mic_none_rounded,
                iconColor: Colors.indigo,
                title: 'Голосовые сообщения',
                subtitleWidget: _privacyBadge(context, l, s.privacyVoiceMessages),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrivacySelectorScreen(
                      title: 'Голосовые сообщения',
                      description: 'Кто может отправлять вам голосовые и видеосообщения.',
                      initialValue: s.privacyVoiceMessages,
                      onChanged: (v) => s.setPrivacyVoiceMessages(v).then((_) => setState(() {})),
                    ),
                  ),
                ),
              ),
              SettingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: Colors.cyan,
                title: 'Биография',
                subtitleWidget: _privacyBadge(context, l, s.privacyBio),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrivacySelectorScreen(
                      title: 'Биография',
                      description: 'Кто может видеть информацию о себе в вашем профиле.',
                      initialValue: s.privacyBio,
                      onChanged: (v) => s.setPrivacyBio(v).then((_) => setState(() {})),
                    ),
                  ),
                ),
              ),
              SettingsTile(
                icon: Icons.cake_outlined,
                iconColor: Colors.pinkAccent,
                title: 'День рождения',
                subtitleWidget: _privacyBadge(context, l, s.privacyBirthday),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrivacySelectorScreen(
                      title: 'День рождения',
                      description: 'Кто может видеть дату вашего рождения.',
                      initialValue: s.privacyBirthday,
                      onChanged: (v) => s.setPrivacyBirthday(v).then((_) => setState(() {})),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            title: 'Заблокированные',
            children: [
              SettingsTile(
                icon: Icons.block_rounded,
                iconColor: context.vibeError,
                title: 'Заблокированные пользователи',
                subtitle: '${s.blockedUsers.length}',
                onTap: () => _showBlockedUsers(context, s),
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            title: l.autoDelete,
            children: [
              SettingsTile(
                icon: Icons.delete_sweep_outlined,
                iconColor: context.vibeError,
                title: l.deleteIfInactive,
                subtitle: l.locale.languageCode == 'ru' 
                    ? 'Если не заходил ${s.autoDeleteMonths} мес.' 
                    : 'If inactive for ${s.autoDeleteMonths} mo.',
                onTap: () {
                  // Show simple dialog to select period
                  showDialog(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: Text(l.deleteIfInactive),
                      children: [1, 3, 6, 12].map((m) => SimpleDialogOption(
                        onPressed: () {
                          s.setAutoDeleteMonths(m).then((_) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) setState(() {});
                          });
                        },
                        child: Text(l.locale.languageCode == 'ru' ? '$m мес.' : '$m months'),
                      )).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
            child: Text(
              l.locale.languageCode == 'ru' 
                ? 'Вы можете настроить автоматическое удаление вашего аккаунта и всех связанных данных, если вы не будете заходить в Vibe в течение указанного срока.'
                : 'You can set up automatic deletion of your account and all associated data if you do not log into Vibe for the specified period.',
              style: VibeTypography.caption.copyWith(color: context.vibeTextSecondary),
            ),
          ),
        ],
      ),
    );
  }

  void _showCallsGroupsMenu(BuildContext context, VibeLocalizations l, SettingsService s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.vibeSurfaceHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(VibeRadius.bottomSheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.vibeTextTertiary.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              title: Text(l.whoCanCallMe, style: TextStyle(color: context.vibeTextPrimary)),
              subtitle: Text(_privacyLabel(s.privacyCalls, l).label, style: TextStyle(color: context.vibeTextSecondary)),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.vibeTextTertiary),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => PrivacySelectorScreen(
                  title: l.whoCanCallMe,
                  description: 'Выберите, кто может совершать голосовые и видеозвонки на ваш аккаунт.',
                  initialValue: s.privacyCalls,
                  onChanged: (v) => s.setPrivacyCalls(v).then((_) => setState(() {})),
                )));
              },
            ),
            ListTile(
              title: Text(l.whoCanAddToGroups, style: TextStyle(color: context.vibeTextPrimary)),
              subtitle: Text(_privacyLabel(s.privacyGroups, l).label, style: TextStyle(color: context.vibeTextSecondary)),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.vibeTextTertiary),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => PrivacySelectorScreen(
                  title: l.whoCanAddToGroups,
                  description: 'Выберите, кто может приглашать вас в групповые чаты и каналы.',
                  initialValue: s.privacyGroups,
                  onChanged: (v) => s.setPrivacyGroups(v).then((_) => setState(() {})),
                )));
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showBlockedUsers(BuildContext context, SettingsService s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: context.vibeSurfaceHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(VibeRadius.bottomSheet)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: context.vibeTextTertiary.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
                child: Row(
                  children: [
                    Text(
                      'Заблокированные',
                      style: VibeTypography.subtitle.copyWith(color: context.vibeTextPrimary),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.person_add_alt_1_rounded, color: context.vibePrimary),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _addBlockedUser(context, s);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: s.blockedUsers.isEmpty
                    ? Center(
                        child: Text(
                          'Нет заблокированных',
                          style: VibeTypography.body.copyWith(color: context.vibeTextSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: s.blockedUsers.length,
                        itemBuilder: (_, i) {
                          final userId = s.blockedUsers[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: context.vibePrimary.withValues(alpha: 0.15),
                              child: Text(
                                userId.substring(0, 2).toUpperCase(),
                                style: TextStyle(color: context.vibePrimary, fontSize: 14),
                              ),
                            ),
                            title: Text(userId, style: TextStyle(color: context.vibeTextPrimary)),
                            trailing: IconButton(
                              icon: Icon(Icons.close_rounded, color: context.vibeTextSecondary),
                              onPressed: () async {
                                await s.removeBlockedUser(userId);
                                if (ctx.mounted) setState(() {});
                                if (mounted) setState(() {});
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addBlockedUser(BuildContext context, SettingsService s) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.vibeSurface,
        title: Text('Заблокировать', style: TextStyle(color: context.vibeTextPrimary)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'ID пользователя',
            hintStyle: TextStyle(color: context.vibeTextTertiary),
          ),
          style: TextStyle(color: context.vibeTextPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: context.vibePrimary)),
          ),
          TextButton(
            onPressed: () async {
              final id = controller.text.trim();
              if (id.isNotEmpty) {
                await s.addBlockedUser(id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
              }
            },
            child: const Text('Заблокировать', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}



