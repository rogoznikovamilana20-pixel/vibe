
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../core/widgets/vibe_toast.dart';
import '../../core/widgets/vibe_top_bar.dart';
import '../../data/settings_service.dart';
import '../../main.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

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
  late bool _sendByEnter;
  late bool _autoNightEnabled;
  late int _autoNightStart;
  late int _autoNightEnd;

  @override
  void initState() {
    super.initState();
    final s = SettingsService.instance;
    _mode = s.themeMode;
    _bubbleRadius = s.bubbleRadius;
    _fontSizeDelta = s.fontSizeDelta;
    _listDensity = s.listDensity;
    _sendByEnter = s.sendByEnter;
    _autoNightEnabled = s.autoNightEnabled;
    _autoNightStart = s.autoNightStart;
    _autoNightEnd = s.autoNightEnd;
  }

  void _setTheme(ThemeMode mode) {
    HapticFeedback.selectionClick();
    setState(() => _mode = mode);
    VibeApp.themeModeNotifier.value = mode;
    SettingsService.instance.setThemeMode(mode);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _autoNightStart : _autoNightEnd;
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
          _autoNightStart = picked.hour;
          SettingsService.instance.setAutoNightStart(picked.hour);
        } else {
          _autoNightEnd = picked.hour;
          SettingsService.instance.setAutoNightEnd(picked.hour);
        }
      });
    }
  }

  void _pickWallpaperColor() {
    final colors = [
      const Color(0xFF1A1A2E),
      const Color(0xFF16213E),
      const Color(0xFF0F3460),
      const Color(0xFF533483),
      const Color(0xFF2B2D42),
      const Color(0xFF1B1B2F),
      const Color(0xFF2C3E50),
      const Color(0xFF1C2833),
      const Color(0xFF0D1117),
      const Color(0xFF1E1E2E),
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(VibeSpacing.lg),
        decoration: BoxDecoration(
          color: context.vibeSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Обои чата',
              style: VibeTypography.subtitle.copyWith(color: context.vibeTextPrimary),
            ),
            const SizedBox(height: VibeSpacing.md),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildWallpaperOption('Нет', null, Icons.block_rounded),
                ...colors.map((c) => _buildWallpaperOption(
                  '',
                  c,
                  Icons.circle,
                  gradient: [c, c.withValues(alpha: 0.7)],
                )),
                _buildWallpaperOption('Градиент', null, Icons.gradient_rounded,
                    gradient: const [
                      Color(0xFF1A1A2E),
                      Color(0xFF16213E),
                    ]),
              ],
            ),
            const SizedBox(height: VibeSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildWallpaperOption(String label, Color? color, IconData icon,
      {List<Color>? gradient}) {
    final currentType = SettingsService.instance.wallpaperType;
    final currentColor = SettingsService.instance.wallpaperColor;
    bool isSelected = false;
    if (color == null && label == 'Нет') {
      isSelected = currentType == 'none';
    } else if (gradient != null && label == 'Градиент') {
      isSelected = currentType == 'gradient';
    } else if (color != null) {
      isSelected = currentType == 'color' && currentColor == color.toARGB32();
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (label == 'Нет') {
          SettingsService.instance.setWallpaper('none');
        } else if (label == 'Градиент') {
          SettingsService.instance.setWallpaper('gradient',
              color: const Color(0xFF1A1A2E).toARGB32(),
              endColor: const Color(0xFF16213E).toARGB32());
        } else if (color != null) {
          SettingsService.instance.setWallpaper('color', color: color.toARGB32());
        }
        Navigator.of(context).pop();
        setState(() {});
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color ?? context.vibeSurface,
          gradient: gradient != null
              ? LinearGradient(colors: gradient)
              : null,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: context.vibePrimary, width: 3)
              : Border.all(color: context.vibeDivider, width: 1),
        ),
        child: color == null
            ? Icon(icon, color: context.vibeTextSecondary, size: 22)
            : isSelected
                ? Icon(Icons.check_rounded, color: Colors.white, size: 22)
                : null,
      ),
    );
  }

  Future<void> _resetDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.vibeSurface,
        title: Text('Сбросить настройки?',
            style: VibeTypography.subtitle.copyWith(color: context.vibeTextPrimary)),
        content: Text('Все настройки внешнего вида будут сброшены к значениям по умолчанию.',
            style: VibeTypography.body.copyWith(color: context.vibeTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Отмена', style: TextStyle(color: context.vibePrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Сбросить', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SettingsService.instance.resetAll();
      if (!mounted) return;
      setState(() {
        _mode = SettingsService.instance.themeMode;
        _bubbleRadius = SettingsService.instance.bubbleRadius;
        _fontSizeDelta = SettingsService.instance.fontSizeDelta;
        _listDensity = SettingsService.instance.listDensity;
        _sendByEnter = SettingsService.instance.sendByEnter;
        _autoNightEnabled = SettingsService.instance.autoNightEnabled;
        _autoNightStart = SettingsService.instance.autoNightStart;
        _autoNightEnd = SettingsService.instance.autoNightEnd;
      });
      VibeApp.themeModeNotifier.value = SettingsService.instance.themeMode;
      VibeToast.show(context, 'Настройки сброшены');
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
            title: 'Авто-ночь',
            children: [
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                color: context.vibePrimary,
                title: 'Включить по расписанию',
                value: _autoNightEnabled,
                onChanged: (v) {
                  setState(() => _autoNightEnabled = v);
                  SettingsService.instance.setAutoNightEnabled(v);
                },
              ),
              if (_autoNightEnabled) ...[
                SettingsTile(
                  icon: Icons.access_time_rounded,
                  iconColor: context.vibePrimary,
                  title: 'Начало',
                  subtitle: '${_autoNightStart.toString().padLeft(2, '0')}:00',
                  onTap: () => _pickTime(isStart: true),
                ),
                SettingsTile(
                  icon: Icons.access_time_filled_rounded,
                  iconColor: context.vibePrimary,
                  title: 'Конец',
                  subtitle: '${_autoNightEnd.toString().padLeft(2, '0')}:00',
                  onTap: () => _pickTime(isStart: false),
                ),
              ],
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            title: l.chatSettings,
            children: [
              _buildSwitchTile(
                icon: Icons.keyboard_return_rounded,
                color: context.vibePrimary,
                title: 'Отправка по Enter',
                subtitle: _sendByEnter ? 'Enter — отправить, Shift+Enter — перенос' : 'Enter — перенос',
                value: _sendByEnter,
                onChanged: (v) {
                  setState(() => _sendByEnter = v);
                  SettingsService.instance.setSendByEnter(v);
                },
              ),
              SettingsTile(
                icon: Icons.wallpaper_rounded,
                iconColor: context.vibePrimary,
                title: 'Обои чата',
                subtitle: SettingsService.instance.wallpaperType == 'none'
                    ? 'По умолчанию'
                    : SettingsService.instance.wallpaperType == 'gradient'
                        ? 'Градиент'
                        : 'Цвет',
                onTap: _pickWallpaperColor,
              ),
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
                        const Color(0xFF8B4DFF),
                        l,
                        label: 'По умолчанию',
                      ),
                      _buildColorCircle(Colors.blue, l),
                      _buildColorCircle(Colors.green, l),
                      _buildColorCircle(Colors.orange, l),
                      _buildColorCircle(Colors.pink, l),
                      _buildColorCircle(Colors.teal, l),
                      _buildColorCircle(Colors.purple, l),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            children: [
              SettingsTile(
                icon: Icons.restore_rounded,
                iconColor: context.vibePrimary,
                title: 'Сбросить к умолчаниям',
                onTap: _resetDefaults,
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
      trailing: active ? Icon(VibeIcons.check, color: context.vibePrimary) : const SizedBox.shrink(),
    );
  }

  Widget _buildColorCircle(Color color, VibeLocalizations l, {String? label}) {
    final active =
        SettingsService.instance.accentColorValue == color.toARGB32();
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        SettingsService.instance.setAccentColor(color.toARGB32());
        setState(() {});
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: active ? Border.all(color: Colors.white, width: 3) : null,
              boxShadow: active
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10)]
                  : null,
            ),
          ),
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 12),
              child: Text(
                label,
                style: VibeTypography.label.copyWith(
                  color: context.vibeTextSecondary,
                  fontSize: 9,
                ),
              ),
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
    String? subtitle,
  }) {
    return SettingsTile(
      icon: icon,
      iconColor: color,
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
