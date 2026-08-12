import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/widgets/vibe_button.dart';
import '../core/widgets/vibe_input.dart';
import '../core/widgets/settings_widgets.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/backend.dart';
import '../data/backend_api.dart';
import 'aurion_screen.dart';

/// Редактирование данных аккаунта — аналог экрана
/// «Изменить данные» в профиле Telegram.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.backend});

  /// Инжектируемый бэкенд (widget-тесты); null — живой `VibeBackend`.
  final VibeBackendApi? backend;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final VibeBackendApi _backend = widget.backend ?? LiveVibeBackend();
  bool _saving = false;
  bool _usernameTaken = false;
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    final p = VibeBackend.myProfileNotifier.value;
    _name = TextEditingController(text: p?.displayName ?? '');
    _username = TextEditingController(text: p?.username ?? '');
    _bio = TextEditingController(text: p?.bio ?? '');
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  /// Живая проверка ника на занятость (с дебаунсом, как в Telegram).
  Future<void> _checkUsername(String val) async {
    _checkTimer?.cancel();
    final clean = val.trim();
    final mine = VibeBackend.myProfileNotifier.value?.username ?? '';
    if (clean.isEmpty || clean.toLowerCase() == mine.toLowerCase()) {
      setState(() => _usernameTaken = false);
      return;
    }
    _checkTimer = Timer(const Duration(milliseconds: 300), () async {
      final available = await _backend.isUsernameAvailable(clean);
      if (!mounted) return;
      setState(() => _usernameTaken = !available);
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Введите имя');
      return;
    }
    if (_usernameTaken) {
      _snack('Этот никнейм уже занят');
      return;
    }
    setState(() => _saving = true);
    try {
      await _backend.updateProfile(
        username: _username.text.trim().isEmpty
            ? (VibeBackend.myProfileNotifier.value?.username ?? 'user')
            : _username.text.trim(),
        displayName: name,
        bio: _bio.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack('Данные сохранены и синхронизированы');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Не удалось сохранить — проверьте соединение');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final userName =
        VibeBackend.myProfileNotifier.value?.displayName ?? 'Пользователь';
    return Scaffold(
      body: Column(
        children: [
          VibeTopBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
              color: context.vibeTextPrimary,
            ),
            title: const VibeTopBarTitle('Изменить данные'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: VibeSpacing.lg,
                vertical: VibeSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VibeInput(
                    controller: _name,
                    hint: 'Имя и фамилия',
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: VibeSpacing.md),
                  VibeInput(
                    controller: _username,
                    hint: 'Имя пользователя (@ник)',
                    errorText: _usernameTaken ? 'Этот никнейм уже занят' : null,
                    onChanged: _checkUsername,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: VibeSpacing.md),
                  VibeInput(
                    controller: _bio,
                    hint: 'О себе (до 70 символов)',
                    maxLines: 3,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: VibeSpacing.md),
                  SettingsSection(
                    children: [
                      SettingsTile(
                        icon: Icons.badge_outlined,
                        iconColor: context.vibePrimary,
                        title: 'Инфо о пользователе',
                        subtitle: 'Дата рождения, город, пол',
                        onTap: () => _snack('Инфо о пользователе — скоро'),
                      ),
                      SettingsTile(
                        icon: Icons.campaign_outlined,
                        iconColor: context.vibePrimary,
                        title: 'Личный канал',
                        subtitle: 'Рассказывай о себе подписчикам',
                        onTap: () => _snack('Создание канала — скоро'),
                      ),
                      SettingsTile(
                        icon: Icons.auto_awesome_rounded,
                        iconColor: context.vibePrimary,
                        title: 'Автоматизация чатов',
                        subtitle: 'Aurion — твой AI-ассистент',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AurionScreen(userName: userName),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: VibeSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: VibeButton(
                      type: VibeButtonType.primary,
                      label: _saving ? 'Сохраняем…' : 'Сохранить',
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
