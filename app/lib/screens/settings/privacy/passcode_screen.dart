
import 'package:vibe_app/core/widgets/vibe_toast.dart';import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import '../../../core/localization/vibe_localizations.dart';
import '../../../core/theme/vibe_colors.dart';
import '../../../core/theme/vibe_spacing.dart';
import '../../../core/theme/vibe_theme.dart';
import '../../../core/theme/vibe_typography.dart';
import '../../../core/widgets/settings_widgets.dart';
import '../../../core/widgets/vibe_top_bar.dart';
import '../../../data/passcode_service.dart';

class PasscodeSettingsScreen extends StatefulWidget {
  const PasscodeSettingsScreen({super.key});

  @override
  State<PasscodeSettingsScreen> createState() => _PasscodeSettingsScreenState();
}

class _PasscodeSettingsScreenState extends State<PasscodeSettingsScreen> {
  bool _hasPasscode = false;
  bool _biometrics = false;
  int _autoLockSec = 0;

  static const _autoLockOptions = <int>[
    0, // Выключено
    1, // Сразу
    60,
    300,
    1800,
    3600,
  ];

  @override
  void initState() {
    super.initState();
    _hasPasscode = PasscodeService.instance.hasPasscode;
    _biometrics = PasscodeService.instance.biometricsEnabled;
    _autoLockSec = PasscodeService.instance.autoLockSeconds;
  }

  void _togglePasscode() async {
    if (_hasPasscode) {
      // Prompt for current passcode to disable
      final success = await _promptPasscode(isVerifying: true);
      if (success == true) {
        await PasscodeService.instance.removePasscode();
        setState(() {
          _hasPasscode = false;
          _biometrics = false;
        });
      }
    } else {
      // Set new passcode
      final code = await _promptPasscode(isVerifying: false);
      if (code != null) {
        await PasscodeService.instance.setPasscode(code);
        setState(() => _hasPasscode = true);
      }
    }
  }

  Future<dynamic> _promptPasscode({required bool isVerifying}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PasscodePrompt(isVerifying: isVerifying),
    );
  }

  String _autoLockLabel(VibeLocalizations l, [int? sec]) {
    switch (sec ?? _autoLockSec) {
      case 0:
        return l.autoLockOff;
      case 1:
        return l.autoLockImmediately;
      case 60:
        return l.locale.languageCode == 'ru' ? 'через 1 минуту' : 'after 1 minute';
      case 300:
        return l.locale.languageCode == 'ru' ? 'через 5 минут' : 'after 5 minutes';
      case 1800:
        return l.locale.languageCode == 'ru' ? 'через 30 минут' : 'after 30 minutes';
      default:
        return l.locale.languageCode == 'ru' ? 'через 1 час' : 'after 1 hour';
    }
  }

  Future<void> _pickAutoLock() async {
    final l = VibeLocalizations.of(context);
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? VibeColors.surface2Dark
          : VibeColors.surface2Light,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: VibeSpacing.lg),
            Text(
              l.autoLock,
              style: VibeTypography.title.copyWith(
                color: sheetCtx.vibeTextPrimary,
              ),
            ),
            const SizedBox(height: VibeSpacing.sm),
            for (final sec in _autoLockOptions)
              ListTile(
                title: Text(
                  _autoLockLabel(VibeLocalizations.of(sheetCtx), sec),
                  style: VibeTypography.body.copyWith(
                    color: sheetCtx.vibeTextPrimary,
                  ),
                ),
                trailing: _autoLockSec == sec
                    ? Icon(Icons.check_rounded, color: sheetCtx.vibePrimary)
                    : null,
                onTap: () => Navigator.pop(sheetCtx, sec),
              ),
            const SizedBox(height: VibeSpacing.md),
          ],
        ),
      ),
    );
    if (selected != null) {
      await PasscodeService.instance.setAutoLockSeconds(selected);
      if (!mounted) return;
      setState(() => _autoLockSec = selected);
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
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
            color: context.vibeTextPrimary,
          ),
          title: VibeTopBarTitle(l.passcodeLock),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(VibeSpacing.lg),
        children: [
          SettingsSection(
            children: [
              SettingsTile(
                icon: Icons.lock_outline_rounded,
                iconColor: context.vibePrimary,
                title: l.passcode,
                subtitle: _hasPasscode ? l.active : l.off,
                trailing: Switch(
                  value: _hasPasscode,
                  onChanged: (_) => _togglePasscode(),
                  activeTrackColor: context.vibePrimary.withValues(alpha: 0.3),
                  activeThumbColor: context.vibePrimary,
                ),
                onTap: _togglePasscode,
              ),
              if (_hasPasscode)
                SettingsTile(
                  icon: Icons.edit_outlined,
                  iconColor: context.vibePrimary,
                  title: l.changePasscode,
                  onTap: () async {
                    final success = await _promptPasscode(isVerifying: true);
                    if (success == true) {
                      final newCode = await _promptPasscode(isVerifying: false);
                      if (newCode != null) {
                        await PasscodeService.instance.setPasscode(newCode);
                      }
                    }
                  },
                ),
            ],
          ),
          if (_hasPasscode) ...[
            const SizedBox(height: VibeSpacing.lg),
            SettingsSection(
              title: l.security.toUpperCase(),
              children: [
                SettingsTile(
                  icon: Icons.fingerprint_rounded,
                  iconColor: context.vibePrimary,
                  title: l.unlockWithBiometrics,
                  trailing: Switch(
                    value: _biometrics,
                    onChanged: (v) async {
                      if (v) {
                        final can = await PasscodeService.instance.canUseBiometrics();
                        if (!context.mounted) return;
                        if (!can) {
                          VibeToast.show(context, 'Биометрия не поддерживается вашим устройством');
                          return;
                        }
                      }
                      await PasscodeService.instance.setBiometricsEnabled(v);
                      setState(() => _biometrics = v);
                    },
                    activeTrackColor: context.vibePrimary.withValues(alpha: 0.3),
                    activeThumbColor: context.vibePrimary,
                  ),
                ),
                SettingsTile(
                  icon: Icons.timer_outlined,
                  iconColor: context.vibePrimary,
                  title: l.autoLock,
                  subtitle: _autoLockLabel(l),
                  onTap: () => _pickAutoLock(),
                ),
              ],
            ),
          ],
          const SizedBox(height: VibeSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
            child: Text(
              l.locale.languageCode == 'ru'
                  ? 'Когда код-пароль включен, над списком чатов появится значок замка. Нажмите на него, чтобы заблокировать приложение.'
                  : 'When a passcode is set, a lock icon will appear above your chat list. Tap it to lock the app.',
              style: VibeTypography.caption.copyWith(color: context.vibeTextSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasscodePrompt extends StatefulWidget {
  const _PasscodePrompt({required this.isVerifying});
  final bool isVerifying;

  @override
  State<_PasscodePrompt> createState() => _PasscodePromptState();
}

class _PasscodePromptState extends State<_PasscodePrompt> {
  final _controller = TextEditingController();
  String? _firstAttempt;
  bool _isSecondStep = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: context.vibeSurfaceHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(VibeRadius.bottomSheet)),
      ),
      padding: EdgeInsets.fromLTRB(VibeSpacing.xl, VibeSpacing.xl, VibeSpacing.xl, MediaQuery.of(context).viewInsets.bottom + VibeSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.isVerifying
                ? 'Введите код-пароль'
                : (_isSecondStep ? 'Повторите код-пароль' : 'Придумайте код-пароль'),
            style: VibeTypography.title.copyWith(color: context.vibeTextPrimary),
          ),
          const SizedBox(height: VibeSpacing.xl),
          Pinput(
            controller: _controller,
            length: PasscodeService.passcodeLength,
            obscureText: true,
            autofocus: true,
            hapticFeedbackType: HapticFeedbackType.lightImpact,
            defaultPinTheme: PinTheme(
              width: 56,
              height: 60,
              textStyle: const TextStyle(fontSize: 24, color: Colors.white),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onCompleted: (pin) async {
              if (widget.isVerifying) {
                final ok = await PasscodeService.instance.verifyPasscode(pin);
                if (!context.mounted) return;
                if (ok) {
                  Navigator.pop(context, true);
                } else {
                  _controller.clear();
                  HapticFeedback.vibrate();
                }
              } else {
                if (!_isSecondStep) {
                  setState(() {
                    _firstAttempt = pin;
                    _isSecondStep = true;
                    _controller.clear();
                  });
                } else {
                  if (pin == _firstAttempt) {
                    Navigator.pop(context, pin);
                  } else {
                    _controller.clear();
                    HapticFeedback.vibrate();
                    VibeToast.show(context, 'Коды не совпадают');
                  }
                }
              }
            },
          ),
          const SizedBox(height: VibeSpacing.xl),
        ],
      ),
    );
  }
}
