
import 'package:vibe_app/core/widgets/vibe_toast.dart';import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../core/widgets/vibe_top_bar.dart';
import '../../data/settings_service.dart';
import '../../main.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  late ThemeMode _mode;
  late double _bubbleRadius;
  late double _fontSizeDelta;
  late double _listDensity;

  @override
  void initState() {
    super.initState();
    _mode = SettingsService.instance.themeMode;
    _bubbleRadius = SettingsService.instance.bubbleRadius;
    _fontSizeDelta = SettingsService.instance.fontSizeDelta;
    _listDensity = SettingsService.instance.listDensity;
  }

  void _setTheme(ThemeMode mode) {
    HapticFeedback.selectionClick();
    setState(() => _mode = mode);
    VibeApp.themeModeNotifier.value = mode;
    SettingsService.instance.setThemeMode(mode);
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
          title: VibeTopBarTitle(l.appearance),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VibeSpacing.lg),
        children: [
          SettingsSection(
            title: l.theme,
            children: [
              _buildThemeRadio(ThemeMode.light, l.light, Icons.light_mode_rounded, l),
              _buildThemeRadio(ThemeMode.dark, l.dark, Icons.dark_mode_rounded, l),
              _buildThemeRadio(ThemeMode.system, l.system, Icons.settings_brightness_rounded, l),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            title: l.chatSettings,
            children: [
              Padding(
                padding: const EdgeInsets.all(VibeSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Плотность списка',
                      style: VibeTypography.bodyMedium.copyWith(color: context.vibeTextPrimary),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _listDensity,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      label: _listDensity < 0.4
                          ? 'Компактный'
                          : _listDensity > 0.75
                              ? 'Просторный'
                              : 'Средний',
                      onChanged: (v) {
                        setState(() => _listDensity = v);
                        SettingsService.instance.setListDensity(v);
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(VibeSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.bubbleRadius,
                      style: VibeTypography.bodyMedium.copyWith(color: context.vibeTextPrimary),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _bubbleRadius,
                      min: 4,
                      max: 24,
                      label: '${_bubbleRadius.round()}px',
                      onChanged: (v) {
                        setState(() => _bubbleRadius = v);
                        SettingsService.instance.setBubbleRadius(v);
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(VibeSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.textSize,
                      style: VibeTypography.bodyMedium.copyWith(color: context.vibeTextPrimary),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _fontSizeDelta,
                      min: -4,
                      max: 8,
                      divisions: 12,
                      label: '${14 + _fontSizeDelta.toInt()}',
                      onChanged: (v) {
                        setState(() => _fontSizeDelta = v);
                        SettingsService.instance.setFontSizeDelta(v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            title: l.accentColor,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: VibeSpacing.md),
                child: SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
                    children: [
                      _buildColorCircle(
                        Color(SettingsService.instance.accentColorValue),
                        l,
                        hex: true,
                      ),
                      _buildColorCircle(Colors.blue, l),
                      _buildColorCircle(Colors.green, l),
                      _buildColorCircle(Colors.orange, l),
                      _buildColorCircle(Colors.pink, l),
                      _buildColorCircle(Colors.teal, l),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeRadio(ThemeMode mode, String title, IconData icon, VibeLocalizations l) {
    final active = _mode == mode;
    return SettingsTile(
      onTap: () => _setTheme(mode),
      icon: icon,
      iconColor: active ? context.vibePrimary : context.vibeTextSecondary,
      title: title,
      trailing: active ? Icon(Icons.check_rounded, color: context.vibePrimary) : const SizedBox.shrink(),
    );
  }

  Widget _buildColorCircle(Color color, VibeLocalizations l, {bool hex = false}) {
    // Первый кружок — текущий акцент из настроек (hex), остальные — палитра.
    final displayColor =
        hex ? Color(SettingsService.instance.accentColorValue) : color;
    final active =
        SettingsService.instance.accentColorValue == displayColor.toARGB32();
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        SettingsService.instance.setAccentColor(displayColor.toARGB32());
        setState(() {});
        VibeToast.show(context, l.locale.languageCode == 'ru'
? 'Акцентный цвет обновлён'
: 'Accent color updated');
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: displayColor,
          shape: BoxShape.circle,
          border: active ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: active
              ? [BoxShadow(color: displayColor.withValues(alpha: 0.4), blurRadius: 10)]
              : null,
        ),
      ),
    );
  }
}

