import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/profile_avatar.dart';
import '../core/services/notification_service.dart';
import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/avatar_action_sheet.dart';
import '../core/widgets/vibe_button.dart';
import '../core/widgets/vibe_input.dart';
import '../data/backend.dart';
import 'avatar_editor_screen.dart';
import 'root_shell.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Создание профиля: имя + эмодзи-аватарка.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  String? _emoji;
  bool _loading = false;
  bool _usernameAvailable = true;
  Timer? _debounce;

  static const _emojis = [
    '😎', '🦄', '🚀', '🐸', '🌸', '🔥', '💜', '🍕',
    '🤖', '🐙', '👽', '⚡', '🦊', '🍩', '🌈', '🐼',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _checkUsername(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (val.length < 3) return;
      final available = await VibeBackend.instance.isUsernameAvailable(val);
      setState(() => _usernameAvailable = available);
    });
  }

  Future<void> _continueToApp() async {
    if (_loading || !_usernameAvailable) return;
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    
    setState(() => _loading = true);
    try {
      await VibeBackend.instance.updateProfile(
        username: username,
        displayName: name,
        emoji: _emoji,
      );
    } catch (e) {
      _snack('Ошибка сохранения профиля. Проверьте БД.');
    }
    
    if (!mounted) return;
    setState(() => _loading = false);

    // Инициализируем пуши после регистрации
    try {
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint('Push init error: $e');
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => RootShell(userName: name, userEmoji: _emoji),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _snack(String msg) {
    VibeToast.show(context, msg);
  }

  /// Клик по аватарке: галерея / камера / удалить (как в профиле).
  Future<void> _changeAvatar() async {
    HapticFeedback.lightImpact();
    final action = await AvatarActionSheet.show(context);
    if (action == null || !mounted) return;
    Uint8List? bytes;
    if (action == 'gal') {
      bytes = await AvatarEditorScreen.pickAndEdit(context);
    } else if (action == 'cam') {
      bytes = await AvatarEditorScreen.takeAndEdit(context);
    } else if (action == 'del') {
      await ProfileAvatar.remove();
      try {
        await VibeBackend.instance.removeRemoteAvatar();
      } catch (_) {}
      if (mounted) _snack('Аватар удалён');
      return;
    }
    if (bytes != null) {
      await ProfileAvatar.save(bytes);
      try {
        await VibeBackend.instance.uploadAvatar(bytes);
        if (mounted) _snack('Аватар обновлён · синхронизирован');
      } catch (_) {
        if (mounted) _snack('Аватар обновлён (без синхронизации)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(VibeSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Твой профиль',
                style: VibeTypography.display.copyWith(color: context.vibeTextPrimary, fontSize: 32),
              ),
              const SizedBox(height: VibeSpacing.sm),
              Text(
                'Никнейм нужен, чтобы тебя могли найти без номера телефона.',
                style: VibeTypography.body.copyWith(color: context.vibeTextSecondary),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _changeAvatar,
                child: ValueListenableBuilder<Uint8List?>(
                  valueListenable: ProfileAvatar.myPhoto,
                  builder: (context, photo, _) => Container(
                    width: 100,
                    height: 100,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.vibeSurfaceVariant,
                      border: Border.all(
                        color: context.vibePrimary,
                        width: photo == null ? 1.5 : 2,
                      ),
                    ),
                    child: photo != null
                        ? Image.memory(photo, fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              _emoji ?? '🙂',
                              style: const TextStyle(fontSize: 48),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              VibeInput(
                controller: _nameController,
                hint: 'Как тебя зовут?',
                prefixIcon: VibeIcons.user,
              ),
              const SizedBox(height: 16),
              VibeInput(
                controller: _usernameController,
                hint: 'Никнейм (например, alex_vibe)',
                prefixIcon: Icons.alternate_email_rounded,
                onChanged: _checkUsername,
                errorText: _usernameAvailable ? null : 'Этот никнейм уже занят',
              ),
              const SizedBox(height: 32),
              Text('Выбери аватарку', style: VibeTypography.subtitle.copyWith(color: context.vibeTextPrimary)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _emojis.map((e) {
                  final sel = e == _emoji;
                  return GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: AnimatedContainer(
                      duration: VibeAnimations.fast,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: sel ? context.vibePrimary.withValues(alpha: 0.2) : context.vibeSurfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sel ? context.vibePrimary : Colors.transparent),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 48),
              VibeButton(
                label: _loading ? 'Сохранение...' : 'Начать общение',
                onPressed: _loading || _nameController.text.isEmpty || _usernameController.text.length < 3 || _emoji == null
                    ? null 
                    : _continueToApp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
