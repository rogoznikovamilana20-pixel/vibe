import 'package:flutter/material.dart';

import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/confetti.dart';
import '../core/widgets/vibe_orb.dart';
import 'auth/auth_screen.dart';

/// Онбординг Vibe — в стиле Telegram: крупный визуал, заголовок, описание,
/// точки-индикаторы и одна кнопка. PageView с плавным переходом.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _showConfetti = false;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.shield_outlined,
      title: 'Квантовая безопасность',
      text:
          'Каждое сообщение шифруется постквантово. Даже квантовый '
          'компьютер будущего не прочитает твою переписку.',
      accent: VibeColors.vivid,
    ),
    _OnboardingPage(
      icon: Icons.storefront_outlined,
      title: 'Бизнес прямо в чатах',
      text:
          'Витрина, заказы и AI-менеджер — без сайта и CRM. Твой магазин '
          'живёт там, где общаются клиенты.',
      accent: VibeColors.workBlue,
    ),
    _OnboardingPage(
      icon: Icons.auto_awesome_outlined,
      title: 'Своя экономика и вайб',
      text:
          'Искры, студия креатора и репутация — мини-экономика '
          'внутри мессенджера.',
      accent: Color(0xFFE8A33D),
    ),
  ];

  void _openAuth() {
    if (_showConfetti) return;
    setState(() => _showConfetti = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const AuthScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: VibeAnimations.fadeIn,
        ),
      );
    });
  }

  void _next() {
    if (_showConfetti) return;
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: VibeAnimations.slideUp,
        curve: VibeAnimations.standard,
      );
    } else {
      _openAuth();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _pages[i],
          ),
          if (_showConfetti) const ConfettiBurst(),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(VibeSpacing.lg),
                    child: TextButton(
                      onPressed: _openAuth,
                      child: Text(
                        'Пропустить',
                        style: VibeTypography.bodyMedium
                            .copyWith(color: context.vibeTextSecondary),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                _buildBottomBar(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VibeSpacing.md,
        0,
        VibeSpacing.md,
        VibeSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: VibeAnimations.pulse,
                curve: VibeAnimations.pulseEasing,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 26 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? context.vibePrimary
                      : context.vibeSurfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: VibeSpacing.xl),
          SizedBox(
            width: double.infinity,
            height: VibeSizes.buttonHeight,
            child: FilledButton(
              onPressed: _next,
              style: FilledButton.styleFrom(
                backgroundColor: context.vibePrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VibeRadius.button),
                ),
                textStyle: VibeTypography.button,
              ),
              child: Text(_page == _pages.length - 1 ? 'Начать' : 'Дальше'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.text,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          VibeSpacing.xxl,
          0,
          VibeSpacing.xxl,
          160,
        ),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Expanded(
              child: Center(
                child: VibeOrb(size: 220, icon: icon, accent: accent),
              ),
            ),
            const SizedBox(height: VibeSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: VibeTypography.headline.copyWith(
                color: context.vibeTextPrimary,
              ),
            ),
            const SizedBox(height: VibeSpacing.md),
            SizedBox(
              width: 300,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: VibeTypography.body.copyWith(
                  color: context.vibeTextSecondary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: VibeSpacing.xl),
          ],
        ),
      ),
    );
  }
}