import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/profile_avatar.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/vibe_animations.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_backdrop.dart';
import '../../core/widgets/vibe_button.dart';
import '../../core/widgets/vibe_input.dart';
import '../../data/backend.dart';
import '../profile_setup_screen.dart';
import '../root_shell.dart';

/// Вход/регистрация по номеру телефона и паролю (без SMS-кодов).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _signup = false;
  bool _obscure = true;
  bool _loading = false;
  String _phone = '';
  bool _phoneValid = false;
  String _error = '';

  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _passwordValid => _password.text.length >= 6;
  bool get _confirmValid => !_signup || _password.text == _confirm.text;

  void _switchMode() {
    setState(() {
      _signup = !_signup;
      _error = '';
      _confirm.clear();
    });
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_phoneValid || !_passwordValid || !_confirmValid) {
      setState(() => _error = 'Проверьте номер и пароль (минимум 6 символов).');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final backend = VibeBackend.instance;
      VibeProfile profile;
      if (_signup) {
        profile = await backend.register(
          phone: _phone,
          password: _password.text,
        );
      } else {
        final res = await backend.login(
          phone: _phone,
          password: _password.text,
        );
        if (res == null) {
          throw Exception('Неверный номер или пароль.');
        }
        profile = res;
      }

      if (!mounted) return;
      if (profile.displayName.isEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(phoneNumber: _phone),
          ),
        );
        return;
      }

      final avatar = await backend.downloadMyAvatar();
      if (avatar != null) await ProfileAvatar.save(avatar);
      try {
        await NotificationService.instance.init();
        await NotificationService.instance.syncToken();
      } catch (e) {
        debugPrint('Push init error: $e');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RootShell(
            userName: profile.displayName,
            userEmoji: profile.emoji,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final detail = e is PostgrestException ? e.message : e.toString();
      setState(() {
        _loading = false;
        _error = detail.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const VibeBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'VIBE',
                        style: VibeTypography.headline.copyWith(
                          color: context.vibeTextPrimary,
                          letterSpacing: 6,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildSegmentedSwitch(),
                  const SizedBox(height: 32),
                  Expanded(
                    child: SingleChildScrollView(
                      child: AnimatedSwitcher(
                        duration: VibeAnimations.fadeIn,
                        switchInCurve: VibeAnimations.standard,
                        child: Column(
                          key: ValueKey(_signup),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _signup
                                  ? 'Создать аккаунт'
                                  : 'С возвращением',
                              style: VibeTypography.display.copyWith(
                                color: context.vibeTextPrimary,
                                fontSize: 32,
                              ),
                            ),
                            const SizedBox(height: VibeSpacing.sm),
                            Text(
                              _signup
                                  ? 'Номер и пароль — всё, что нужно. Пароль можно сменить позже в настройках.'
                                  : 'Войди по номеру телефона и паролю.',
                              style: VibeTypography.body.copyWith(
                                color: context.vibeTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildPhoneField(),
                            const SizedBox(height: VibeSpacing.lg),
                            VibeInput(
                              hint: 'Пароль',
                              controller: _password,
                              obscure: _obscure,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _submit(),
                              prefixIcon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: context.vibeTextSecondary,
                                ),
                              ),
                            ),
                            AnimatedSize(
                              duration: VibeAnimations.pulse,
                              curve: VibeAnimations.standard,
                              child: _signup
                                  ? Padding(
                                      padding: const EdgeInsets.only(
                                        top: VibeSpacing.lg,
                                      ),
                                      child: VibeInput(
                                        hint: 'Повторите пароль',
                                        controller: _confirm,
                                        obscure: _obscure,
                                        onChanged: (_) => setState(() {}),
                                        onSubmitted: (_) => _submit(),
                                        prefixIcon:
                                            Icons.verified_outlined,
                                        errorText: _confirmValid
                                            ? null
                                            : 'Пароли не совпадают',
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            if (_error.isNotEmpty) ...[
                              const SizedBox(height: VibeSpacing.lg),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(VibeSpacing.md),
                                decoration: BoxDecoration(
                                  color: context.vibeError.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    VibeRadius.card,
                                  ),
                                  border: Border.all(
                                    color: context.vibeError.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _error,
                                  textAlign: TextAlign.center,
                                  style: VibeTypography.bodyMedium.copyWith(
                                    color: context.vibeError,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: VibeSpacing.xxl),
                          ],
                        ),
                      ),
                    ),
                  ),
                  VibeButton(
                    label: _loading
                        ? 'Проверяем…'
                        : (_signup ? 'Создать аккаунт' : 'Войти'),
                    onPressed: _loading ? null : _submit,
                  ),
                  const SizedBox(height: VibeSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.vibeSurfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _segLabel('Вход', !_signup, () => _switchMode()),
          _segLabel('Регистрация', _signup, () => _switchMode()),
        ],
      ),
    );
  }

  Widget _segLabel(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: VibeAnimations.pulse,
          curve: VibeAnimations.standard,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? context.vibePrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: VibeTypography.bodyMedium.copyWith(
              color: active ? Colors.white : context.vibeTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: context.vibeSurfaceVariant,
        borderRadius: BorderRadius.circular(VibeRadius.input),
        border: Border.all(
          color: _phoneValid ? context.vibePrimary : context.vibeBorder,
        ),
      ),
      child: IntlPhoneField(
        decoration: const InputDecoration(
          labelText: 'Номер телефона',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.symmetric(
            horizontal: VibeSpacing.lg,
            vertical: VibeSpacing.lg,
          ),
        ),
        initialCountryCode: 'RU',
        showCountryFlag: false,
        onChanged: (phone) {
          setState(() {
            _phone = phone.completeNumber;
            _phoneValid = phone.number.length >= 10;
          });
        },
        style: VibeTypography.bodyMedium.copyWith(
          color: context.vibeTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        dropdownTextStyle: TextStyle(color: context.vibeTextPrimary),
        cursorColor: context.vibePrimary,
      ),
    );
  }
}
