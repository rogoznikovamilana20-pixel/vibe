import 'package:flutter/material.dart';
import '../../../core/localization/vibe_localizations.dart';
import '../../../core/theme/vibe_spacing.dart';
import '../../../core/theme/vibe_theme.dart';
import '../../../core/theme/vibe_typography.dart';
import '../../../core/widgets/vibe_button.dart';
import '../../../core/widgets/vibe_input.dart';
import '../../../core/widgets/vibe_top_bar.dart';

class TwoStepVerificationScreen extends StatefulWidget {
  const TwoStepVerificationScreen({super.key});

  @override
  State<TwoStepVerificationScreen> createState() => _TwoStepVerificationScreenState();
}

class _TwoStepVerificationScreenState extends State<TwoStepVerificationScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _hintController = TextEditingController();
  
  int _step = 0; // 0: Enter pass, 1: Confirm, 2: Hint
  bool _loading = false;

  void _next() {
    if (_step == 0) {
      if (_passwordController.text.length < 4) {
        _snack('Пароль слишком короткий');
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      if (_passwordController.text != _confirmController.text) {
        _snack('Пароли не совпадают');
        return;
      }
      setState(() => _step = 2);
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      // В реальном PocketBase это будет смена пароля пользователя
      // Для прототипа — имитируем сохранение
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context);
        _snack('Двухэтапная аутентификация включена');
      }
    } catch (_) {
      _snack('Ошибка при сохранении');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
          title: VibeTopBarTitle(l.twoStep),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(VibeSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_step == 0) ...[
              Text('Придумайте пароль', style: VibeTypography.headline.copyWith(color: context.vibeTextPrimary)),
              const SizedBox(height: VibeSpacing.sm),
              Text('Этот пароль будет запрашиваться при входе на новом устройстве в дополнение к коду из SMS.', style: VibeTypography.body.copyWith(color: context.vibeTextSecondary)),
              const SizedBox(height: 40),
              VibeInput(
                controller: _passwordController,
                hint: 'Пароль',
                obscure: true,
                autofocus: true,
              ),
            ] else if (_step == 1) ...[
              Text('Повторите пароль', style: VibeTypography.headline.copyWith(color: context.vibeTextPrimary)),
              const SizedBox(height: 40),
              VibeInput(
                controller: _confirmController,
                hint: 'Повторите пароль',
                obscure: true,
                autofocus: true,
              ),
            ] else ...[
              Text('Подсказка для пароля', style: VibeTypography.headline.copyWith(color: context.vibeTextPrimary)),
              const SizedBox(height: VibeSpacing.sm),
              Text('Вы можете оставить подсказку, которая поможет вспомнить пароль.', style: VibeTypography.body.copyWith(color: context.vibeTextSecondary)),
              const SizedBox(height: 40),
              VibeInput(
                controller: _hintController,
                hint: 'Подсказка',
                autofocus: true,
              ),
            ],
            const Spacer(),
            VibeButton(
              label: _loading ? 'Сохранение...' : (_step == 2 ? 'Готово' : 'Далее'),
              onPressed: _loading ? null : _next,
            ),
            const SizedBox(height: VibeSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

