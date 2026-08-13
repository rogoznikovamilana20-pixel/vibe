import 'package:flutter/material.dart';
import '../../../core/localization/vibe_localizations.dart';
import '../../../core/theme/vibe_colors.dart';
import '../../../core/theme/vibe_spacing.dart';
import '../../../core/theme/vibe_theme.dart';
import '../../../core/theme/vibe_typography.dart';
import '../../../core/widgets/settings_widgets.dart';
import '../../../core/widgets/vibe_top_bar.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

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
          title: VibeTopBarTitle(l.sessions),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VibeSpacing.lg),
        children: [
          Center(
            child: Icon(
              Icons.devices_rounded,
              size: 80,
              color: context.vibePrimary,
            ),
          ),
          const SizedBox(height: VibeSpacing.lg),
          Text(
            l.locale.languageCode == 'ru'
                ? 'Вы можете войти в Vibe с других устройств, используя ваш номер телефона. Все ваши данные будут синхронизированы.'
                : 'You can log into Vibe on other devices using your phone number. All your data will be synchronized.',
            textAlign: TextAlign.center,
            style: VibeTypography.body.copyWith(color: context.vibeTextSecondary),
          ),
          const SizedBox(height: VibeSpacing.xl),
          SettingsSection(
            title: 'ЭТО УСТРОЙСТВО',
            children: [
              ListTile(
                leading: const Icon(Icons.smartphone_rounded, color: VibeColors.success),
                title: Text('Vibe Mobile', style: VibeTypography.bodyMedium.copyWith(color: context.vibeTextPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  l.locale.languageCode == 'ru' ? 'Vibe v0.9 · Android 14 · В сети' : 'Vibe v0.9 · Android 14 · Online',
                  style: VibeTypography.caption.copyWith(color: VibeColors.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            children: [
              SettingsTile(
                icon: Icons.cancel_outlined,
                iconColor: context.vibeError,
                title: l.terminateAllSessions,
                destructive: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.terminateAllSessions)),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

