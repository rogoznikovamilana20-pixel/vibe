
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
  late bool _animationsEnabled;
  late double _bubbleOpacity;
  late double _avatarSize;
  late int _previewLines;
  late bool _showDate;
  late bool _showStatus;
  late bool _bubbleTail;
  late bool _showTicks;

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
    _animationsEnabled = s.animationsEnabled;
    _bubbleOpacity = s.bubbleOpacity;
    _avatarSize = s.avatarSize;
    _previewLines = s.previewLines;
    _showDate = s.showDate;
    _showStatus = s.showStatus;
    _bubbleTail = s.bubbleTail;
    _showTicks = s.showTicks;
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

  Widget _buildPreview(BuildContext context) {
    final accent = Color(SettingsService.instance.accentColorValue);
    return Container(
      padding: const EdgeInsets.all(VibeSpacing.md),
      decoration: BoxDecoration(
        color: context.vibeSurface,
        borderRadius: BorderRadius.circular(VibeRadius.card),
        border: Border.all(color: context.vibeDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Превью', style: VibeTypography.subtitle.copyWith(color: context.vibeTextPrimary)),
          const SizedBox(height: VibeSpacing.sm),
          // Превью пузыря — отражает bubbleRadius/fontSizeDelta/bubbleOpacity
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: SettingsService.instance.bubbleOpacity),
                borderRadius: BorderRadius.circular(_bubbleRadius),
              ),
              child: Text('Привет! Это превью пузыря',
                  style: VibeTypography.body.copyWith(
                      color: Colors.white, fontSize: 14 + _fontSizeDelta)),
            ),
          ),
          const SizedBox(height: VibeSpacing.sm),
          // Превью чата — отражает listDensity/fontSizeDelta
          Container(
            padding: EdgeInsets.symmetric(vertical: 4 + _listDensity * 4),
            decoration: BoxDecoration(
              color: context.vibeSurfaceVariant,
              borderRadius: BorderRadius.circular(VibeRadius.sm),
            ),
            child: Row(
              children: [
                Container(width: 40 + _listDensity * 8, height: 40 + _listDensity * 8, decoration: BoxDecoration(shape: BoxShape.circle, color: accent)),
                const SizedBox(width: VibeSpacing.sm),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Чаты', style: VibeTypography.subtitle.copyWith(fontSize: 14 + _fontSizeDelta)), Text('Превью сообщения', style: VibeTypography.body.copyWith(color: context.vibeTextSecondary, fontSize: 12 + _fontSizeDelta))])),
              ],
            ),
          ),
        ],
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
        _animationsEnabled = SettingsService.instance.animationsEnabled;
        _bubbleOpacity = SettingsService.instance.bubbleOpacity;
        _avatarSize = SettingsService.instance.avatarSize;
        _previewLines = SettingsService.instance.previewLines;
        _showDate = SettingsService.instance.showDate;
        _showStatus = SettingsService.instance.showStatus;
        _bubbleTail = SettingsService.instance.bubbleTail;
        _showTicks = SettingsService.instance.showTicks;
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
          // Живой превью AyuGram-уровня: пузырь + чат-тайл + плотность
          _buildPreview(context),
          const SizedBox(height: VibeSpacing.lg),
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
            title: 'Анимации и эффекты',
            children: [
              _buildSwitchTile(
                icon: Icons.animation_rounded,
                color: context.vibePrimary,
                title: 'Анимации интерфейса',
                subtitle: _animationsEnabled ? 'Включены (плавные переходы)' : 'Выключены (мгновенно)',
                value: _animationsEnabled,
                onChanged: (v) {
                  setState(() => _animationsEnabled = v);
                  SettingsService.instance.setAnimationsEnabled(v);
                },
              ),
              Padding(
                padding: const EdgeInsets.all(VibeSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Прозрачность пузырей',
                        style: VibeTypography.bodyMedium.copyWith(color: context.vibeTextPrimary)),
                    const SizedBox(height: 8),
                    Slider(
                      value: _bubbleOpacity,
                      min: 0.5,
                      max: 1.0,
                      divisions: 10,
                      label: '${(_bubbleOpacity * 100).round()}%',
                      onChanged: (v) {
                        setState(() => _bubbleOpacity = v);
                        SettingsService.instance.setBubbleOpacity(v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            title: 'Список чатов',
            children: [
              Padding(
                padding: const EdgeInsets.all(VibeSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Размер аватара',
                        style: VibeTypography.bodyMedium.copyWith(color: context.vibeTextPrimary)),
                    Slider(
                      value: _avatarSize,
                      min: 32,
                      max: 52,
                      divisions: 10,
                      label: '${_avatarSize.round()}',
                      onChanged: (v) {
                        setState(() => _avatarSize = v);
                        SettingsService.instance.setAvatarSize(v);
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
                    Text('Строк превью',
                        style: VibeTypography.bodyMedium.copyWith(color: context.vibeTextPrimary)),
                    Slider(
                      value: _previewLines.toDouble(),
                      min: 1,
                      max: 3,
                      divisions: 2,
                      label: '$_previewLines',
                      onChanged: (v) {
                        setState(() => _previewLines = v.round());
                        SettingsService.instance.setPreviewLines(v.round());
                      },
                    ),
                  ],
                ),
              ),
              _buildSwitchTile(
                icon: Icons.calendar_today_rounded,
                color: context.vibePrimary,
                title: 'Показывать дату/время',
                value: _showDate,
                onChanged: (v) {
                  setState(() => _showDate = v);
                  SettingsService.instance.setShowDate(v);
                },
              ),
              _buildSwitchTile(
                icon: Icons.done_all_rounded,
                color: context.vibePrimary,
                title: 'Показывать статус (прочитано)',
                value: _showStatus,
                onChanged: (v) {
                  setState(() => _showStatus = v);
                  SettingsService.instance.setShowStatus(v);
                },
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            title: 'Сообщения',
            children: [
              _buildSwitchTile(
                icon: Icons.chat_bubble_outline_rounded,
                color: context.vibePrimary,
                title: 'Хвост пузыря',
                subtitle: _bubbleTail ? 'Показывать хвост у последнего в группе' : 'Без хвоста (плоские)',
                value: _bubbleTail,
                onChanged: (v) {
                  setState(() => _bubbleTail = v);
                  SettingsService.instance.setBubbleTail(v);
                },
              ),
              _buildSwitchTile(
                icon: Icons.done_all_rounded,
                color: context.vibePrimary,
                title: 'Галочки статуса',
                subtitle: _showTicks ? 'Показывать ✓✓' : 'Скрыты',
                value: _showTicks,
                onChanged: (v) {
                  setState(() => _showTicks = v);
                  SettingsService.instance.setShowTicks(v);
                },
              ),
              Padding(
                padding: const EdgeInsets.all(VibeSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Размер шрифта сообщений',
                        style: VibeTypography.bodyMedium.copyWith(color: context.vibeTextPrimary)),
                    Slider(
                      value: SettingsService.instance.messageFontSize,
                      min: 12,
                      max: 18,
                      divisions: 6,
                      label: '${SettingsService.instance.messageFontSize.round()}',
                      onChanged: (v) {
                        SettingsService.instance.setMessageFontSize(v);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SettingsSection(
            title: 'Навигация',
            children: [
              SettingsTile(
                icon: Icons.view_quilt_rounded,
                iconColor: context.vibePrimary,
                title: 'Стиль навигации',
                subtitle: SettingsService.instance.navigationStyle == 'bottom'
                    ? 'Снизу (капсула)'
                    : SettingsService.instance.navigationStyle == 'drawer'
                        ? 'Боковая шторка'
                        : 'Вкладки сверху',
                onTap: () async {
                  final style = await showDialog<String>(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: Text('Навигация', style: VibeTypography.subtitle.copyWith(color: context.vibeTextPrimary)),
                      children: [
                        SimpleDialogOption(onPressed: () => Navigator.of(ctx).pop('bottom'), child: Text('Снизу (капсула)')),
                        SimpleDialogOption(onPressed: () => Navigator.of(ctx).pop('drawer'), child: Text('Боковая шторка')),
                        SimpleDialogOption(onPressed: () => Navigator.of(ctx).pop('tabs'), child: Text('Вкладки сверху')),
                      ],
                    ),
                  );
                  if (style != null) {
                    await SettingsService.instance.setNavigationStyle(style);
                    setState(() {});
                  }
                },
              ),
              _buildSwitchTile(
                icon: Icons.add_circle_outline_rounded,
                color: context.vibePrimary,
                title: 'Кнопка создания чата (FAB)',
                value: SettingsService.instance.fabVisible,
                onChanged: (v) async {
                  await SettingsService.instance.setFabVisible(v);
                  setState(() {});
                },
              ),
              SettingsTile(
                icon: Icons.style_rounded,
                iconColor: context.vibePrimary,
                title: 'Пак иконок',
                subtitle: SettingsService.instance.iconPack,
                onTap: () async {
                  final pack = await showDialog<String>(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: Text('Иконки', style: VibeTypography.subtitle.copyWith(color: context.vibeTextPrimary)),
                      children: [
                        SimpleDialogOption(onPressed: () => Navigator.of(ctx).pop('vibe'), child: Text('Vibe (по умолчанию)')),
                        SimpleDialogOption(onPressed: () => Navigator.of(ctx).pop('material'), child: Text('Material')),
                        SimpleDialogOption(onPressed: () => Navigator.of(ctx).pop('telegram'), child: Text('Telegram')),
                      ],
                    ),
                  );
                  if (pack != null) {
                    await SettingsService.instance.setIconPack(pack);
                    setState(() {});
                  }
                },
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
                      _buildCustomColorButton(context),
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

  Widget _buildCustomColorButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final controller = TextEditingController(
            text: '#${SettingsService.instance.accentColorValue.toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}');
        final hex = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.vibeSurface,
            title: Text('HEX цвет', style: VibeTypography.subtitle.copyWith(color: context.vibeTextPrimary)),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '#8B4DFF',
                hintStyle: VibeTypography.body.copyWith(color: context.vibeTextTertiary),
              ),
              style: VibeTypography.body.copyWith(color: context.vibeTextPrimary),
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Отмена', style: TextStyle(color: context.vibePrimary))),
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                  child: Text('ОК', style: TextStyle(color: context.vibePrimary))),
            ],
          ),
        );
        if (hex != null && hex.isNotEmpty) {
          var clean = hex.trim().replaceAll('#', '');
          if (clean.length == 6) clean = 'FF$clean';
          final val = int.tryParse(clean, radix: 16);
          if (val != null) {
            HapticFeedback.selectionClick();
            await SettingsService.instance.setAccentColor(val);
            if (!mounted) return;
            setState(() {});
          } else {
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            VibeToast.show(context, 'Неверный HEX');
          }
        }
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: context.vibeSurfaceVariant,
          shape: BoxShape.circle,
          border: Border.all(color: context.vibeDivider),
        ),
        child: Icon(Icons.colorize_rounded, color: context.vibeTextSecondary, size: 20),
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
