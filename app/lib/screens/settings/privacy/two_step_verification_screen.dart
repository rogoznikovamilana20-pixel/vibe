// ignore_for_file: use_build_context_synchronously

import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/vibe_localizations.dart';
import '../../../core/theme/vibe_spacing.dart';
import '../../../core/theme/vibe_theme.dart';
import '../../../core/theme/vibe_typography.dart';
import '../../../core/widgets/vibe_button.dart';
import '../../../core/widgets/vibe_input.dart';
import '../../../core/widgets/vibe_top_bar.dart';
import '../../../data/backend.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

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
  bool _enabled = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final enabled = await VibeBackend.instance.isTwoFactorEnabled();
      final hint = await VibeBackend.instance.getTwoFactorHint();
      if (mounted) {
        setState(() {
          _enabled = enabled;
          _checking = false;
        });
        if (hint != null) _hintController.text = hint;
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _next() {
    if (_step == 0) {
      if (_passwordController.text.length < 4) {
        _snack(VibeLocalizations.of(context).twoStepPasswordTooShort);
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      if (_passwordController.text != _confirmController.text) {
        _snack(VibeLocalizations.of(context).twoStepPasswordsDontMatch);
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
      await VibeBackend.instance.setTwoFactorPassword(
        password: _passwordController.text,
        hint: _hintController.text.isEmpty ? null : _hintController.text,
      );
      if (mounted) {
        Navigator.pop(context);
        _snack(VibeLocalizations.of(context).twoStepEnabled);
      }
    } catch (_) {
      _snack(VibeLocalizations.of(context).twoStepSaveError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disable() async {
    final l = VibeLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.vibeSurface,
        title: Text(l.twoStep, style: TextStyle(color: context.vibeTextPrimary)),
        content: Text('Отключить двухэтапную аутентификацию?',
            style: TextStyle(color: context.vibeTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.dialogCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.dialogDelete, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await VibeBackend.instance.disableTwoFactor();
      if (mounted) {
        setState(() => _enabled = false);
        _snack('Двухэтапная аутентификация отключена');
      }
    } catch (_) {
      _snack(VibeLocalizations.of(context).twoStepSaveError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    VibeToast.show(context, msg);
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
          title: VibeTopBarTitle(l.twoStep),
        ),
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : _enabled
              ? _buildEnabled(l)
              : _buildSetup(l),
    );
  }

  Widget _buildEnabled(VibeLocalizations l) {
    return Padding(
      padding: const EdgeInsets.all(VibeSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(VibeSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, color: Colors.greenAccent, size: 28),
                const SizedBox(width: VibeSpacing.md),
                Expanded(
                  child: Text(
                    l.twoStepEnabled,
                    style: VibeTypography.headline.copyWith(color: context.vibeTextPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: VibeSpacing.xxl),
          VibeButton(
            label: _loading ? 'Отключение...' : 'Отключить',
            onPressed: _loading ? null : _disable,
          ),
        ],
      ),
    );
  }

  Widget _buildSetup(VibeLocalizations l) {
    return Padding(
      padding: const EdgeInsets.all(VibeSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_step == 0) ...[
            Text(l.twoStepCreatePassword, style: VibeTypography.headline.copyWith(color: context.vibeTextPrimary)),
            const SizedBox(height: VibeSpacing.sm),
            Text(l.twoStepPasswordDescription, style: VibeTypography.body.copyWith(color: context.vibeTextSecondary)),
            const SizedBox(height: 40),
            VibeInput(
              controller: _passwordController,
              hint: 'Пароль',
              obscure: true,
              autofocus: true,
            ),
          ] else if (_step == 1) ...[
            Text(l.twoStepConfirmPassword, style: VibeTypography.headline.copyWith(color: context.vibeTextPrimary)),
            const SizedBox(height: 40),
            VibeInput(
              controller: _confirmController,
              hint: 'Повторите пароль',
              obscure: true,
              autofocus: true,
            ),
          ] else ...[
            Text(l.twoStepHint, style: VibeTypography.headline.copyWith(color: context.vibeTextPrimary)),
            const SizedBox(height: VibeSpacing.sm),
            Text(l.twoStepHintDescription, style: VibeTypography.body.copyWith(color: context.vibeTextSecondary)),
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
    );
  }
}
