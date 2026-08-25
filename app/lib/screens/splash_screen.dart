import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/widgets/vibe_backdrop.dart';
import '../core/widgets/vibe_glass_surface.dart';
import '../core/widgets/vibe_orb.dart';
import '../data/backend.dart';
import '../data/passcode_service.dart';
import '../data/e2e_service.dart';
import '../core/services/notification_service.dart';
import 'lock_screen.dart';
import 'onboarding_screen.dart';
import 'profile_setup_screen.dart';
import 'root_shell.dart';

/// Заставка Vibe: энерго-орб + слово VIBE.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _fade;
  late final Animation<double> _rise;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _fade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _rise = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.15, 1.0, curve: VibeAnimations.springy),
    );

    _initAndGo();
  }

  Future<void> _initAndGo() async {
    // Инициализируем бэкенд (подгрузит сессию если есть)
    final backend = await VibeBackend.init();

    // E2E: загружаем ключи шифрования
    await E2eService.instance.loadKeys();

    // Пуши — строго в фоне с таймаутом: без сети FCM может висеть,
    // и сплэш не должен ждать его (см. NotificationService.init).
    unawaited(NotificationService.instance.init());

    // Ждём минимум 1.4с для красивой анимации (не блокируемся сетью).
    await Future.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    final profile = backend.myProfile;
    final Widget next;

    if (profile != null) {
      // PIN-блокировка: показываем экран ввода код-пароля до главного экрана.
      if (PasscodeService.instance.hasPasscode) {
        final unlocked = await Navigator.of(context).push<bool>(
          PageRouteBuilder(
            opaque: true,
            pageBuilder: (_, _, _) => const LockScreen(),
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: VibeAnimations.fadeIn,
          ),
        );
        if (!mounted) return;
        if (unlocked != true) {
          // Пользователь закрыл блокировку без ввода — не пускаем дальше.
          return;
        }
      }
      // Профиль не завершён (нет имени — как после регистрации без шага
      // «имя и аватарка»): снова показываем экран создания профиля, а не
      // кидаем сразу в чаты.
      if (profile.displayName.isEmpty) {
        next = ProfileSetupScreen(phoneNumber: profile.phone ?? '');
      } else {
        next = RootShell(
          userName: profile.displayName,
          userEmoji: profile.emoji,
        );
      }
    } else {
      next = const OnboardingScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: VibeAnimations.fadeIn,
      ),
    );
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VibeColors.bgDark,
      body: Stack(
        children: [
          const Positioned.fill(child: VibeBackdrop()),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _rise,
                child: VibeGlassSurface(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(VibeRadius.xl),
                  ),
                  blur: VibeBlur.sheet,
                  padding: const EdgeInsets.fromLTRB(
                    VibeSpacing.xl,
                    VibeSpacing.xl,
                    VibeSpacing.xl,
                    VibeSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const VibeOrb(size: 120, icon: Icons.bolt_rounded),
                      const SizedBox(height: VibeSpacing.xl),
                      const Text(
                        'VIBE',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: VibeSpacing.sm),
                      const Text(
                        'мессенджер нового поколения',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.4,
                          color: VibeColors.textPrimaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
