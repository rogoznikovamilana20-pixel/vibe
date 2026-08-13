import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/localization/vibe_localizations.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/vibe_button.dart';
import '../core/widgets/vibe_chat_icon.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_collapsible_screen.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../core/widgets/settings_widgets.dart';
import '../main.dart';
import '../core/profile_avatar.dart';
import '../data/backend.dart';
import '../data/settings_service.dart';
import 'settings/appearance_settings.dart';
import 'settings/notifications_settings.dart';
import 'settings/privacy_settings.dart';
import 'settings/data_settings.dart';
import 'settings/language_settings.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Настройки в стиле Telegram (вкладка «Настройки»).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.onOpenProfile,
  });

  final VoidCallback? onOpenProfile;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VibeCollapsibleScreen(
        slivers: [
          SliverToBoxAdapter(
            child: VibeTopBar(
              leading: IconButton(
                icon: const Icon(VibeIcons.back),
                onPressed: () {}, // Заглушка, т.к. это вкладка
                color: context.vibeTextPrimary,
              ),
              title: VibeTopBarTitle(l.settings),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: VibeSpacing.md),
                _buildAccountCard(context),
                const SizedBox(height: VibeSpacing.lg),
                SettingsSection(
                  title: l.generalSettings,
                  children: [
                    SettingsTile(
                      icon: Icons.notifications_none_rounded,
                      iconColor: context.vibeError,
                      title: l.notifications,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen()),
                      ),
                    ),
                    SettingsTile(
                      icon: Icons.lock_outline_rounded,
                      iconColor: VibeColors.primary,
                      title: l.privacy,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
                      ),
                    ),
                    SettingsTile(
                      icon: Icons.pie_chart_outline_rounded,
                      iconColor: VibeColors.primary,
                      title: l.data,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DataSettingsScreen()),
                      ),
                    ),
                    _buildThemeToggleTile(context, l),
                    SettingsTile(
                      icon: Icons.language_rounded,
                      iconColor: VibeColors.primary,
                      title: l.language,
                      trailing: Text(
                        l.locale.languageCode == 'ru' ? 'Русский' : 'English',
                        style: TextStyle(color: context.vibePrimary),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
                      ),
                    ),
                  ],
                ),
                SettingsSection(
                  title: l.support,
                  children: [
                    SettingsTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      iconColor: VibeColors.primary,
                      iconWidget: const VibeChatIcon(
                        size: 18,
                        filled: true,
                        color: VibeColors.primary,
                      ),
                      title: l.askQuestion,
                      onTap: () => _askQuestion(context, l),
                    ),
                    SettingsTile(
                      icon: Icons.help_outline_rounded,
                      iconColor: VibeColors.primary,
                      title: l.faq,
                      onTap: () => _showFaq(context, l),
                    ),
                    SettingsTile(
                      icon: Icons.policy_outlined,
                      iconColor: VibeColors.primary,
                      title: l.policy,
                      onTap: () => _showPolicy(context, l),
                    ),
                  ],
                ),
                const SizedBox(height: VibeSpacing.xl),
                VibeButton(
                  type: VibeButtonType.outline,
                  label: l.logout,
                  onPressed: () => _confirmLogout(context, l),
                ),
                const SizedBox(height: VibeSpacing.xxl),
              ]),
            ),
          ),
        ],
        collapsedBarBuilder: (_, progress) => VibeCollapsedTopBar(
          progress: progress,
          leading: IconButton(
            icon: const Icon(VibeIcons.back),
            onPressed: () {},
            color: context.vibeTextPrimary,
          ),
          title: VibeTopBarTitle(l.settings),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, VibeLocalizations l) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.logout),
        content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await VibeBackend.instance.logout();
              await ProfileAvatar.remove();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            child: Text(l.logout, style: TextStyle(color: context.vibeError)),
          ),
        ],
      ),
    );
  }

  /// Карточка «Аккаунт» сверху — ведёт на вкладку «Профиль».
  Widget _buildAccountCard(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: VibeBackend.myProfileNotifier,
      builder: (context, profile, _) {
        final name = profile?.displayName ?? 'Пользователь';
        final username = profile?.username != null
            ? '@${profile!.username}'
            : 'аккаунт';
        return Material(
          color: context.vibeSurfaceVariant,
          borderRadius: BorderRadius.circular(VibeRadius.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(VibeRadius.card),
            onTap: widget.onOpenProfile,
            child: Padding(
              padding: const EdgeInsets.all(VibeSpacing.md),
              child: Row(
                children: [
                  ValueListenableBuilder(
                    valueListenable: ProfileAvatar.myPhoto,
                    builder: (context, photo, _) => VibeAvatar(
                      name: name,
                      size: VibeSizes.avatarMd,
                      emoji: profile?.emoji,
                      photo: photo,
                    ),
                  ),
                  const SizedBox(width: VibeSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: VibeTypography.bodyMedium.copyWith(
                            color: context.vibeTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          username,
                          style: VibeTypography.caption.copyWith(
                            color: context.vibeTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: context.vibeTextTertiary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeToggleTile(BuildContext context, VibeLocalizations l) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: VibeApp.themeModeNotifier,
      builder: (context, mode, _) {
        final dark = mode != ThemeMode.light;
        return SettingsTile(
          icon: dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          iconColor: VibeColors.primary,
          title: l.appearance,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dark ? (l.locale.languageCode == 'ru' ? 'Тёмное' : 'Dark') : (l.locale.languageCode == 'ru' ? 'Светлое' : 'Light'),
                style: TextStyle(color: context.vibeTextSecondary),
              ),
              const SizedBox(width: 8),
              Switch(
                value: dark,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  VibeApp.themeModeNotifier.value =
                      v ? ThemeMode.dark : ThemeMode.light;
                  SettingsService.instance.setThemeMode(VibeApp.themeModeNotifier.value);
                },
                activeTrackColor: context.vibePrimary.withValues(alpha: 0.3),
                activeThumbColor: context.vibePrimary,
              ),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AppearanceSettingsScreen()),
          ),
        );
      },
    );
  }

  void _snack(String msg) {
    VibeToast.show(context, msg);
  }

  Future<void> _askQuestion(BuildContext context, VibeLocalizations l) async {
    final controller = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.askQuestion),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(hintText: 'Опишите вопрос или проблему…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отправить', style: TextStyle(color: VibeColors.primary)),
          ),
        ],
      ),
    );
    if (sent == true && controller.text.trim().isNotEmpty) {
      _snack('Вопрос отправлен команде Vibe');
    }
  }

  Future<void> _showFaq(BuildContext context, VibeLocalizations l) async {
    const faq = [
      ('Как войти в Vibe?', 'Введите номер телефона и пароль на экране входа. Новый номер можно зарегистрировать там же.'),
      ('Как найти друга?', 'Нажмите «Новое сообщение» и введите имя, никнейм или ID пользователя в поиске.'),
      ('Меня нет в списке чатов?', 'Проверьте, что друг добавил вас в контакты, или напишите ему сначала вы.'),
      ('Фото не синхронизируется?', 'Проверьте подключение к интернету — фото загружаются в облако автоматически.'),
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.faq),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (q, a) in faq) ...[
                Text(q, style: VibeTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(a, style: VibeTypography.body.copyWith(color: context.vibeTextSecondary)),
                const SizedBox(height: VibeSpacing.md),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Future<void> _showPolicy(BuildContext context, VibeLocalizations l) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.policy),
        content: const SingleChildScrollView(
          child: Text(
            'Vibe заботится о вашей приватности.\n\n'
            '1. Ваши сообщения шифруются при передаче и хранятся только для доставки.\n\n'
            '2. Аватары и вложения хранятся в вашем облачном аккаунте Vibe.\n\n'
            '3. Мы не продаём ваши данные третьим лицам.\n\n'
            '4. Вы можете в любой момент удалить аккаунт и все данные из настроек.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }
}
