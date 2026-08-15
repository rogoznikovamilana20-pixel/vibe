import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pinput/pinput.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env_config.dart';
import '../../core/localization/vibe_localizations.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_backdrop.dart';
import '../../core/widgets/vibe_button.dart';
import '../../core/widgets/vibe_toast.dart';
import '../../data/backend.dart';

/// Экран ввода OTP-кода, подтверждённого по SMS.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.phone});

  final String phone;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _pinController = TextEditingController();
  bool _loading = false;
  bool _sending = false;
  int _resendSeconds = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _sending = true);
    try {
      // Вызов Edge Function для отправки SMS
      final url = Uri.parse(
        '${EnvConfig.supabaseUrl}/functions/v1/send-otp',
      );
      await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${EnvConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
        body: '{"phone": "${widget.phone}"}',
      );

      if (mounted) {
        setState(() {
          _sending = false;
          _resendSeconds = 60;
        });
        _startResendTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        VibeToast.show(context, 'Не удалось отправить SMS');
      }
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_resendSeconds > 0) {
          setState(() => _resendSeconds--);
        } else {
          timer.cancel();
        }
      }
    });
  }

  Future<void> _verify() async {
    final code = _pinController.text.trim();
    if (code.length != 6) {
      VibeToast.show(context, 'Введите 6-значный код');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await Supabase.instance.client
          .rpc('verify_phone_otp', params: {'p_phone': widget.phone, 'p_code': code});

      if (result == true) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        if (mounted) {
          VibeToast.show(context, 'Неверный или просроченный код');
          _pinController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        VibeToast.show(context, 'Ошибка проверки');
        _pinController.clear();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);

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
                  Center(
                    child: Text(
                      'VIBE',
                      style: VibeTypography.headline.copyWith(
                        color: context.vibeTextPrimary,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Код подтверждения',
                    style: VibeTypography.display.copyWith(
                      color: context.vibeTextPrimary,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: VibeSpacing.sm),
                  Text(
                    'Введите код из SMS, отправленный на ${widget.phone}',
                    style: VibeTypography.body.copyWith(
                      color: context.vibeTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Pinput(
                      controller: _pinController,
                      length: 6,
                      autofocus: true,
                      onCompleted: (_) => _verify(),
                      defaultPinTheme: PinTheme(
                        width: 48,
                        height: 56,
                        textStyle: VibeTypography.headline.copyWith(
                          color: context.vibeTextPrimary,
                          fontSize: 22,
                        ),
                        decoration: BoxDecoration(
                          color: context.vibeSurfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.vibeBorder),
                        ),
                      ),
                      focusedPinTheme: PinTheme(
                        width: 48,
                        height: 56,
                        textStyle: VibeTypography.headline.copyWith(
                          color: context.vibeTextPrimary,
                          fontSize: 22,
                        ),
                        decoration: BoxDecoration(
                          color: context.vibeSurfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.vibePrimary, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: VibeSpacing.xl),
                  if (_resendSeconds > 0)
                    Center(
                      child: Text(
                        'Отправить повторно через ${_resendSeconds}с',
                        style: VibeTypography.body.copyWith(
                          color: context.vibeTextSecondary,
                        ),
                      ),
                    )
                  else
                    Center(
                      child: GestureDetector(
                        onTap: _sendOtp,
                        child: Text(
                          _sending ? 'Отправка...' : 'Отправить повторно',
                          style: VibeTypography.body.copyWith(
                            color: context.vibePrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  VibeButton(
                    label: _loading ? 'Проверяем...' : 'Подтвердить',
                    onPressed: _loading ? null : _verify,
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
}
