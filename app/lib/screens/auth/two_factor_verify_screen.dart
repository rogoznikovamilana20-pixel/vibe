import 'package:flutter/material.dart';

import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_backdrop.dart';
import '../../core/widgets/vibe_button.dart';
import '../../core/widgets/vibe_input.dart';
import '../../core/widgets/vibe_toast.dart';
import '../../data/backend.dart';

/// Экран проверки пароля 2FA после входа.
class TwoFactorVerifyScreen extends StatefulWidget {
  const TwoFactorVerifyScreen({super.key, this.hint});

  final String? hint;

  @override
  State<TwoFactorVerifyScreen> createState() => _TwoFactorVerifyScreenState();
}

class _TwoFactorVerifyScreenState extends State<TwoFactorVerifyScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_loading) return;
    if (_controller.text.isEmpty) {
      setState(() => _error = 'Введите пароль');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await VibeBackend.instance.verifyTwoFactorPassword(_controller.text);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _loading = false;
          _error = 'Неверный пароль';
        });
        _controller.clear();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Ошибка проверки';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        body: Stack(
          children: [
            const VibeBackdrop(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),
                    Center(
                      child: Icon(
                        Icons.shield_rounded,
                        size: 64,
                        color: context.vibePrimary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      l.twoStep,
                      style: VibeTypography.display.copyWith(
                        color: context.vibeTextPrimary,
                        fontSize: 28,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: VibeSpacing.sm),
                    Text(
                      'Введите пароль двухэтапной аутентификации для входа',
                      style: VibeTypography.body.copyWith(
                        color: context.vibeTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.hint != null && widget.hint!.isNotEmpty) ...[
                      const SizedBox(height: VibeSpacing.lg),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(VibeSpacing.md),
                        decoration: BoxDecoration(
                          color: context.vibeSurfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Подсказка: ${widget.hint}',
                          style: VibeTypography.body.copyWith(
                            color: context.vibeTextSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    VibeInput(
                      controller: _controller,
                      hint: 'Пароль',
                      obscure: true,
                      autofocus: true,
                      onSubmitted: (_) => _verify(),
                      prefixIcon: Icons.lock_outline_rounded,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: VibeSpacing.md),
                      Text(
                        _error!,
                        style: VibeTypography.body.copyWith(color: context.vibeError),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const Spacer(),
                    VibeButton(
                      label: _loading ? 'Проверяем...' : 'Войти',
                      onPressed: _loading ? null : _verify,
                    ),
                    const SizedBox(height: VibeSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
