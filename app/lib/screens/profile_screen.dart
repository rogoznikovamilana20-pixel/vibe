import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/localization/vibe_localizations.dart';
import '../core/profile_avatar.dart';
import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/avatar_action_sheet.dart';
import '../core/widgets/vibe_button.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_collapsible_screen.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/backend.dart';
import 'avatar_editor_screen.dart';
import 'chat_screen.dart';
import 'edit_profile_screen.dart';
import 'my_links_screen.dart';
import 'settings_screen.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Вкладка «Профиль» — как раздел профиля в Telegram:
/// QR-код, аватарка, имя, кнопки «Выбрать фото / Изменить данные /
/// Добавить аккаунт / Выйти».
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.userName,
    this.userEmoji,
    this.onOpenSettings,
  });

  final String userName;
  final String? userEmoji;
  final VoidCallback? onOpenSettings;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int? _profileGradientIndex;

  List<Color>? get _profileGradient => _profileGradientIndex == null
      ? null
      : VibeAvatarGradients.pairs[_profileGradientIndex!];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VibeCollapsibleScreen(
        slivers: [
          SliverToBoxAdapter(
            child: VibeTopBar(
              leading: IconButton(
                icon: const Icon(Icons.qr_code_2_rounded),
                onPressed: () => _showQrSheet(context),
                color: context.vibeTextPrimary,
                tooltip: 'QR-код профиля',
              ),
              title: VibeTopBarTitle(_displayName()),
              actions: [
                IconButton(
                  icon: const Icon(VibeIcons.moreVertical),
                  onPressed: () => _showProfileMenu(context),
                  color: context.vibeTextPrimary,
                  tooltip: 'Ещё',
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: VibeSpacing.md),
                _buildHeader(context),
                const SizedBox(height: VibeSpacing.lg),
                _buildActions(context),
                const SizedBox(height: VibeSpacing.xl),
              ]),
            ),
          ),
        ],
        collapsedBarBuilder: (_, progress) => VibeCollapsedTopBar(
          progress: progress,
          leading: Padding(
            padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.xs),
            child: ValueListenableBuilder(
              valueListenable: ProfileAvatar.myPhoto,
              builder: (context, photo, _) => VibeAvatar(
                name: _displayName(),
                size: VibeSizes.avatarSm,
                emoji: widget.userEmoji,
                photo: photo,
                gradientOverride: _profileGradient,
              ),
            ),
          ),
          title: VibeTopBarTitle(_displayName()),
        ),
      ),
    );
  }

  String _displayName() =>
      VibeBackend.myProfileNotifier.value?.displayName ?? widget.userName;

  String _username() {
    final u = VibeBackend.myProfileNotifier.value?.username;
    return u != null ? '@$u' : '@${widget.userName.toLowerCase()}';
  }

  String _profileLink() {
    final u = VibeBackend.myProfileNotifier.value?.username;
    return 'vibe.me/@${u ?? widget.userName.toLowerCase()}';
  }

  Widget _buildHeader(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: VibeBackend.myProfileNotifier,
      builder: (context, profile, _) {
        final phone = profile?.phone;
        final bio = profile?.bio;
        final hasPhone = phone != null && phone.isNotEmpty;
        final hasBio = bio != null && bio.isNotEmpty;
        return Column(
          children: [
            ValueListenableBuilder(
              valueListenable: ProfileAvatar.myPhoto,
              builder: (context, photo, _) {
                return GestureDetector(
                  onTap: () => _changeAvatar(context),
                  child: VibeAvatar(
                    name: _displayName(),
                    size: 108,
                    emoji: profile?.emoji ?? widget.userEmoji,
                    photo: photo,
                    online: true,
                    gradientOverride: _profileGradient,
                  ),
                );
              },
            ),
            const SizedBox(height: VibeSpacing.md),
            Text(
              _displayName(),
              style: VibeTypography.title.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _username(),
              style: VibeTypography.caption.copyWith(
                color: context.vibeTextSecondary,
              ),
            ),
            if (hasPhone) ...[
              const SizedBox(height: 2),
              Text(
                phone,
                style: VibeTypography.caption.copyWith(
                  color: context.vibeTextSecondary,
                ),
              ),
            ],
            if (hasBio) ...[
              const SizedBox(height: VibeSpacing.sm),
              Text(
                bio,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: VibeTypography.body.copyWith(
                  color: context.vibeTextSecondary,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 2),
            Text(
              VibeLocalizations.of(context).online,
              style: VibeTypography.caption.copyWith(
                color: VibeColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        // Контактные данные: клик — копировать (телефон / @username).
        ValueListenableBuilder(
          valueListenable: VibeBackend.myProfileNotifier,
          builder: (context, profile, _) {
            final phone = profile?.phone;
            final hasPhone = phone != null && phone.isNotEmpty;
            return Column(
              children: [
                if (hasPhone)
                  _ProfileActionTile(
                    icon: Icons.call_outlined,
                    title: 'Телефон',
                    trailing: phone,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: phone));
                      _snack('Номер скопирован');
                    },
                  ),
                _ProfileActionTile(
                  icon: Icons.alternate_email_rounded,
                  title: 'Имя пользователя',
                  trailing: _username(),
                  onTap: () => _copyProfileLink(context),
                ),
                _ProfileActionTile(
                  icon: Icons.link_rounded,
                  title: 'Мои ссылки',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MyLinksScreen(
                        userName: widget.userName,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: VibeSpacing.lg),
        const _SectionHeader('Разное'),
        _ProfileActionTile(
          icon: Icons.bookmark_outline_rounded,
          title: 'Сохранённое',
          onTap: () => _openSaved(context),
        ),
        _ProfileActionTile(
          icon: Icons.settings_outlined,
          title: 'Настройки',
          onTap: () {
            final cb = widget.onOpenSettings;
            if (cb != null) {
              cb();
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            }
          },
        ),
        _ProfileActionTile(
          icon: Icons.qr_code_2_rounded,
          title: 'QR-код',
          onTap: () => _showQrSheet(context),
        ),
        const SizedBox(height: VibeSpacing.lg),
        const _SectionHeader('Прочее'),
        _ProfileActionTile(
          icon: Icons.add_a_photo_outlined,
          title: 'Выбрать фото',
          onTap: () => _changeAvatar(context),
        ),
        _ProfileActionTile(
          icon: VibeIcons.edit,
          title: 'Изменить данные',
          onTap: () => _openEditProfile(context),
        ),
        _ProfileActionTile(
          icon: Icons.person_add_alt_1_rounded,
          title: 'Добавить аккаунт',
          onTap: () => _snack('Мультиаккаунты появятся позже'),
        ),
        _ProfileActionTile(
          icon: Icons.logout_rounded,
          title: 'Выйти',
          destructive: true,
          onTap: () =>
              _confirmLogout(context, VibeLocalizations.of(context)),
        ),
        const SizedBox(height: VibeSpacing.xs),
        Text(
          _profileLink(),
          style: VibeTypography.caption.copyWith(
            color: context.vibeTextTertiary,
          ),
        ),
      ],
    );
  }

  Future<void> _openSaved(BuildContext context) async {
    final chatId = await VibeBackend.instance.ensureSavedChat();
    if (chatId.isEmpty || !context.mounted) return;
    final chat = await VibeBackend.instance.chatById(chatId);
    if (chat == null || !context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)));
  }

  // ── Меню «⋯» в шапке (как в профиле Telegram) ───────────────────────

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.vibeSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Изменить цвет профиля'),
              onTap: () {
                Navigator.pop(ctx);
                _changeProfileColor(context);
              },
            ),
            ListTile(
              leading: const Icon(VibeIcons.edit),
              title: const Text('Изменить имя'),
              onTap: () {
                Navigator.pop(ctx);
                _changeName(context);
              },
            ),
            ListTile(
              leading: const Icon(VibeIcons.copy),
              title: const Text('Копировать ссылку'),
              onTap: () {
                Navigator.pop(ctx);
                _copyProfileLink(context);
              },
            ),
            const SizedBox(height: VibeSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _changeProfileColor(BuildContext context) async {
    final idx = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.vibeSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(VibeSpacing.lg),
          child: Wrap(
            spacing: VibeSpacing.md,
            runSpacing: VibeSpacing.md,
            children: [
              for (var i = 0; i < VibeAvatarGradients.pairs.length; i++)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(ctx, i),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: VibeAvatarGradients.pairs[i],
                      ),
                      border: _profileGradientIndex == i
                          ? Border.all(color: context.vibePrimary, width: 3)
                          : null,
                    ),
                    child: _profileGradientIndex == i
                        ? const Icon(VibeIcons.check, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (idx != null && mounted) {
      setState(() => _profileGradientIndex = idx);
      _snack('Цвет профиля обновлён');
    }
  }

  Future<void> _changeName(BuildContext context) async {
    final current = _displayName();
    final controller = TextEditingController(text: current);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Изменить имя'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          decoration: const InputDecoration(
            hintText: 'Имя и фамилия',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    try {
      final p = VibeBackend.myProfileNotifier.value;
      await VibeBackend.instance.updateProfile(
        username: p?.username ?? widget.userName.toLowerCase(),
        displayName: name,
      );
      _snack('Имя обновлено');
    } catch (_) {
      _snack('Не удалось обновить имя');
    }
  }

  Future<void> _copyProfileLink(BuildContext context) async {
    final link = _profileLink();
    await Clipboard.setData(ClipboardData(text: link));
    _snack('Ссылка скопирована: $link');
  }

  // ── QR-код профиля ──────────────────────────────────────────────────

  void _showQrSheet(BuildContext context) {
    final link = _profileLink();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.vibeSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(VibeSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(VibeSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(VibeRadius.card),
                ),
                child: QrImageView(
                  data: link,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: VibeSpacing.lg),
              Text(
                link,
                style: VibeTypography.bodyMedium.copyWith(
                  color: context.vibeTextPrimary,
                ),
              ),
              const SizedBox(height: VibeSpacing.xs),
              Text(
                'Покажи этот код — по нему найдут твой профиль',
                style: VibeTypography.caption.copyWith(
                  color: context.vibeTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: VibeSpacing.lg),
              VibeButton(
                type: VibeButtonType.outline,
                label: 'Копировать ссылку',
                onPressed: () {
                  Navigator.pop(ctx);
                  _copyProfileLink(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditProfile(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  Future<void> _changeAvatar(BuildContext context) async {
    HapticFeedback.lightImpact();
    final action = await AvatarActionSheet.show(context);
    if (action == null || !context.mounted) return;
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
      _snack('Аватар удалён');
      return;
    }
    if (bytes != null) {
      await ProfileAvatar.save(bytes);
      try {
        await VibeBackend.instance.uploadAvatar(bytes);
        _snack('Аватар обновлён · синхронизирован');
        return;
      } catch (_) {
        _snack('Аватар обновлён (без синхронизации)');
      }
    }
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
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            child:
                Text(l.logout, style: TextStyle(color: context.vibeError)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    VibeToast.show(context, msg);
  }
}

/// Кнопка-пункт под аватаркой профиля (как в Telegram).
class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.vibeError : context.vibePrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: VibeSpacing.sm),
      decoration: BoxDecoration(
        color: context.vibeSurfaceVariant,
        borderRadius: BorderRadius.circular(VibeRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: VibeSpacing.lg,
              vertical: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: VibeSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: VibeTypography.bodyMedium.copyWith(
                      color: destructive
                          ? context.vibeError
                          : context.vibeTextPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: VibeSpacing.sm),
                  Flexible(
                    child: Text(
                      trailing!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VibeTypography.caption.copyWith(
                        color: context.vibeTextSecondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: VibeSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: destructive
                      ? context.vibeError.withValues(alpha: 0.6)
                      : context.vibeTextTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Заголовок секции блок-списка профиля.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: VibeSpacing.sm,
        bottom: VibeSpacing.xs,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: VibeTypography.caption.copyWith(
            color: context.vibeTextSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}