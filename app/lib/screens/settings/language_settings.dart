import 'package:flutter/material.dart';
import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../core/widgets/vibe_top_bar.dart';
import '../../data/settings_service.dart';
import '../../main.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  late String _currentCode;

  @override
  void initState() {
    super.initState();
    _currentCode = SettingsService.instance.languageCode;
  }

  void _setLanguage(String code) {
    setState(() => _currentCode = code);
    SettingsService.instance.setLanguageCode(code);
    VibeApp.localeNotifier.value = Locale(code);
    Navigator.of(context).pop();
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
          title: VibeTopBarTitle(l.language),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VibeSpacing.lg),
        children: [
          SettingsSection(
            children: [
              _buildLangTile('Русский', 'ru'),
              _buildLangTile('English', 'en'),
              _buildLangTile('Deutsch', 'de', comingSoon: true),
              _buildLangTile('Français', 'fr', comingSoon: true),
              _buildLangTile('Español', 'es', comingSoon: true),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: VibeSpacing.sm),
            child: Text(
              l.languagesAvailable,
              style: VibeTypography.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangTile(String name, String code, {bool comingSoon = false}) {
    final active = _currentCode == code;
    return ListTile(
      onTap: comingSoon ? null : () => _setLanguage(code),
      enabled: !comingSoon,
      title: Text(
        name,
        style: VibeTypography.bodyMedium.copyWith(
          color: active ? context.vibePrimary : context.vibeTextPrimary,
          fontWeight: active ? FontWeight.w500 : FontWeight.w500,
        ),
      ),
      subtitle: comingSoon
          ? Text(
              'Скоро',
              style: VibeTypography.caption.copyWith(
                color: context.vibeTextSecondary,
              ),
            )
          : null,
      trailing: comingSoon
          ? null
          : active
              ? Icon(VibeIcons.check, color: context.vibePrimary)
              : null,
    );
  }
}

