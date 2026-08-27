import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

import '../core/localization/vibe_localizations.dart';
import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_backdrop.dart';
import '../core/widgets/vibe_glass_surface.dart';
import '../core/widgets/vibe_orb.dart';
import '../data/passcode_service.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Полноэкранная блокировка приложения: ввод код-пароля, биометрия,
/// лимит попыток (5) с временной блокировкой ввода.
///
/// Возвращает `true` через Navigator.pop при успешной разблокировке.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _controller = TextEditingController();
  bool _showError = false;
  Timer? _lockTimer;
  Duration? _lockLeft;

  @override
  void initState() {
    super.initState();
    _syncLock();
    _maybeBiometrics();
    debugPrint('[lock] LockScreen показан (hasPasscode=${PasscodeService.instance.hasPasscode})');
  }

  void _syncLock() {
    final left = PasscodeService.instance.lockRemaining;
    final locked = left != null && left.inSeconds > 0;
    _lockTimer?.cancel();
    if (!locked) {
      setState(() {
        _lockLeft = null;
        _showError = false;
      });
      return;
    }
    setState(() => _lockLeft = left);
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = PasscodeService.instance.lockRemaining;
      if (now == null || now.inSeconds <= 0) {
        _lockTimer?.cancel();
        if (!mounted) return;
        setState(() => _lockLeft = null);
        return;
      }
      setState(() => _lockLeft = now);
    });
  }

  Future<void> _maybeBiometrics() async {
    if (!PasscodeService.instance.biometricsEnabled) return;
    if (PasscodeService.instance.isLocked) {
      _syncLock();
      return;
    }
    final ok = await PasscodeService.instance.authenticateWithBiometrics();
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onCompleted(String pin) async {
    if (PasscodeService.instance.isLocked) {
      _syncLock();
      return;
    }
    final ok = await PasscodeService.instance.verifyPasscode(pin);
    if (!mounted) return;
    if (ok) {
      debugPrint('[lock] разблокирован (PIN)');
      Navigator.of(context).pop(true);
      return;
    }
    debugPrint('[lock] неверный PIN, осталось попыток: ${PasscodeService.instance.attemptsRemaining}, заблокирован: ${PasscodeService.instance.isLocked}');
    _controller.clear();
    HapticFeedback.vibrate();
    setState(() => _showError = true);
    _syncLock();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locked = _lockLeft != null;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: VibeColors.bgDark,
        body: Stack(
        children: [
          const Positioned.fill(child: VibeBackdrop()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(VibeSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const VibeOrb(size: 92, icon: VibeIcons.lock),
                    const SizedBox(height: VibeSpacing.xl),
                    VibeGlassSurface(
                      radius: VibeRadius.pill,
                      blur: VibeBlur.panel,
                      padding: const EdgeInsets.all(VibeSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l.lockTitle,
                            style: VibeTypography.title.copyWith(
                              color: context.vibeTextPrimary,
                            ),
                          ),
                          const SizedBox(height: VibeSpacing.xs),
                          Text(
                            l.lockEnterPasscode,
                            style: VibeTypography.body.copyWith(
                              color: context.vibeTextSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: VibeSpacing.xl),
                          if (locked) ...[
                            _LockedPill(secondsLeft: _lockLeft!.inSeconds),
                          ] else ...[
                            Pinput(
                              controller: _controller,
                              length: PasscodeService.passcodeLength,
                              obscureText: true,
                              autofocus: true,
                              hapticFeedbackType: HapticFeedbackType.lightImpact,
                              enabled: !locked,
                              errorText: _showError ? l.lockWrongPasscode : null,
                              errorTextStyle: VibeTypography.caption.copyWith(
                                color: context.vibeError,
                              ),
                              defaultPinTheme: PinTheme(
                                width: 36,
                                height: 44,
                                textStyle: VibeTypography.subtitle.copyWith(
                                  color: context.vibeTextPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.04),
                                  borderRadius:
                                      BorderRadius.circular(22),
                                  border: Border.all(
                                    color: context.vibeGlassBorder,
                                  ),
                                ),
                              ),
                              focusedPinTheme: PinTheme(
                                width: 36,
                                height: 44,
                                textStyle: VibeTypography.subtitle.copyWith(
                                  color: context.vibeTextPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: BoxDecoration(
                                  color: context.vibePrimary
                                      .withValues(alpha: isDark ? 0.16 : 0.10),
                                  borderRadius:
                                      BorderRadius.circular(22),
                                  border: Border.all(
                                    color: context.vibePrimary,
                                    width: 1.6,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.vibePrimary
                                          .withValues(alpha: 0.25),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                              onCompleted: _onCompleted,
                            ),
                            if (_showError && !locked) ...[
                              const SizedBox(height: VibeSpacing.md),
                              _ErrorPill(
                                text: l.lockAttemptsLeft(
                                  PasscodeService.instance.attemptsRemaining,
                                ),
                              ),
                            ],
                          ],
                          if (PasscodeService.instance.biometricsEnabled) ...[
                            const SizedBox(height: VibeSpacing.xl),
                            _BiometricsPill(onTap: _maybeBiometrics),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

/// Пилюля «слишком много попыток» с таймером блокировки.
class _LockedPill extends StatelessWidget {
  const _LockedPill({required this.secondsLeft});

  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    return VibeGlassSurface(
      radius: VibeRadius.pill,
      blur: VibeBlur.nav,
      padding: const EdgeInsets.symmetric(
        horizontal: VibeSpacing.lg,
        vertical: VibeSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.lockTooManyAttempts,
            style: VibeTypography.body.copyWith(
              color: context.vibeError,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: VibeSpacing.xs),
          Text(
            '$secondsLeft с',
            style: VibeTypography.subtitle.copyWith(
              color: context.vibeTextPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Пилюля ошибки: осталось N попыток.
class _ErrorPill extends StatelessWidget {
  const _ErrorPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeSpacing.lg,
        vertical: VibeSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.vibeError.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(VibeRadius.pill),
        border: Border.all(
          color: context.vibeError.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        text,
        style: VibeTypography.captionMedium.copyWith(
          color: context.vibeError,
        ),
      ),
    );
  }
}

/// Стеклянная пилюля входа по биометрии.
class _BiometricsPill extends StatelessWidget {
  const _BiometricsPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      child: VibeGlassSurface(
        radius: VibeRadius.pill,
        blur: VibeBlur.nav,
        padding: const EdgeInsets.symmetric(
          horizontal: VibeSpacing.xl,
          vertical: VibeSpacing.md,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fingerprint_rounded,
              size: 22,
              color: context.vibePrimary,
            ),
            const SizedBox(width: VibeSpacing.sm),
            Flexible(
              child: Text(
                l.unlockWithBiometrics,
                style: VibeTypography.button.copyWith(
                  color: context.vibePrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
