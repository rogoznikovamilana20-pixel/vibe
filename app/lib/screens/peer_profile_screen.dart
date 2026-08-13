import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_collapsible_screen.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/backend.dart';
import '../data/settings_service.dart';

/// Один медиафайл из переписки (фото или видеокружок).
class PeerMedia {
  const PeerMedia({required this.isVideo, this.url, this.localPath});

  final bool isVideo;

  /// Сетевой URL (входящие файлы).
  final String? url;

  /// Локальный файл (свои записи).
  final String? localPath;
}

/// Профиль собеседника — как в Telegram: аватар, имя/ник, статус, био,
/// быстрые действия и лента общих медиа. Открывается тапом по пилюле в
/// шапке чата (меню остаётся на кнопке ⋯).
class PeerProfileScreen extends StatefulWidget {
  const PeerProfileScreen({
    super.key,
    required this.chat,
    required this.media,
  });

  final VibeChat chat;
  final List<PeerMedia> media;

  @override
  State<PeerProfileScreen> createState() => _PeerProfileScreenState();
}

class _PeerProfileScreenState extends State<PeerProfileScreen> {
  VibeProfile? _profile;
  bool _loading = true;
  late bool _isBlocked;

  @override
  void initState() {
    super.initState();
    _isBlocked = SettingsService.instance.isBlocked(widget.chat.peerId ?? '');
    _load();
  }

  void _toggleBlock(BuildContext context) {
    final id = widget.chat.peerId;
    if (id == null) return;
    HapticFeedback.lightImpact();
    final current = SettingsService.instance.blockedUsers;
    final next = _isBlocked
        ? current.where((x) => x != id).toList()
        : [...current, id];
    SettingsService.instance.setBlockedUsers(next);
    setState(() => _isBlocked = !_isBlocked);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(_isBlocked ? 'Пользователь заблокирован' : 'Пользователь разблокирован')),
      );
  }

  Future<void> _load() async {
    final peerId = widget.chat.peerId;
    if (peerId == null) return;
    try {
      final p = await VibeBackend.instance.profileById(peerId);
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String get _statusText {
    final chat = widget.chat;
    return chat.peerOnline
        ? 'в сети'
        : (chat.peerLastSeen != null
            ? 'был(а) в сети ${VibeBackend.formatTime(chat.peerLastSeen)}'
            : 'был(а) недавно');
  }

  Widget _mediaTile(PeerMedia m) {
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(VibeRadius.md),
      child: SizedBox.expand(
        child: ColoredBox(
          color: context.vibeSurfaceVariant,
          child: m.localPath != null && m.localPath!.isNotEmpty
              ? Image.file(
                  File(m.localPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _mediaPlaceholder(m),
                )
              : m.url != null && m.url!.isNotEmpty
                  ? VibeNetImage(
                      source: m.url,
                      errorBuilder: (_, _, _) => _mediaPlaceholder(m),
                    )
                  : _mediaPlaceholder(m),
        ),
      ),
    );
    if (!m.isVideo) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        const Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            size: 34,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _mediaPlaceholder(PeerMedia m) {
    return Center(
      child: Icon(
        m.isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
        size: 30,
        color: context.vibeTextTertiary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final username = _profile?.username;
    final bio = _profile?.bio ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VibeCollapsibleScreen(
        slivers: [
          SliverToBoxAdapter(
            child: VibeTopBar(
              leading: VibeTopBarIcon(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).pop(),
                tooltip: 'Назад',
              ),
              title: const VibeTopBarTitle('Профиль'),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: VibeSpacing.lg),
                Hero(
                  tag: 'avatar_${chat.id}',
                  child: VibeAvatar(
                    name: chat.title,
                    size: VibeSizes.avatarXl,
                    online: chat.peerOnline,
                    photoUrl: chat.peerAvatar,
                  ),
                ),
                const SizedBox(height: VibeSpacing.md),
                Text(
                  chat.title,
                  textAlign: TextAlign.center,
                  style: VibeTypography.title.copyWith(
                    color: context.vibeTextPrimary,
                  ),
                ),
                if (!_loading && username != null && username.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    style: VibeTypography.bodyMedium.copyWith(
                      color: context.vibeTextTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _statusText,
                  style: VibeTypography.bodyMedium.copyWith(
                    color: chat.peerOnline
                        ? VibeColors.success
                        : context.vibeTextTertiary,
                  ),
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: VibeSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: VibeSpacing.xl,
                    ),
                    child: Text(
                      bio,
                      textAlign: TextAlign.center,
                      style: VibeTypography.body.copyWith(
                        color: context.vibeTextSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: VibeSpacing.xl,
                vertical: VibeSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ProfileAction(
                      icon: Icons.message_rounded,
                      label: 'Сообщение',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: VibeSpacing.md),
                  Expanded(
                    child: _ProfileAction(
                      icon: Icons.call_rounded,
                      label: 'Аудио',
                      onTap: () {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(content: Text('Аудиозвонок — в v2.0')),
                          );
                      },
                    ),
                  ),
                  const SizedBox(width: VibeSpacing.md),
                  Expanded(
                    child: _ProfileAction(
                      icon: Icons.videocam_rounded,
                      label: 'Видео',
                      onTap: () {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(content: Text('Видеозвонок — в v2.0')),
                          );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (chat.peerId != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  VibeSpacing.xl,
                  VibeSpacing.xs,
                  VibeSpacing.xl,
                  VibeSpacing.sm,
                ),
                child: Row(
                  children: [
                    Text(
                      'Медиа',
                      style: VibeTypography.subtitle.copyWith(
                        color: context.vibeTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.media.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: VibeSpacing.xl),
                  child: Center(
                    child: Text(
                      'Пока нет общих медиа',
                      style: VibeTypography.body,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: VibeSpacing.lg,
                ),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _mediaTile(widget.media[i]),
                    childCount: widget.media.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  VibeSpacing.lg,
                  VibeSpacing.xl,
                  VibeSpacing.lg,
                  VibeSpacing.xl,
                ),
                child: Material(
                  color: context.vibeSurfaceElevated.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(VibeRadius.xl),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Icon(
                      Icons.block_rounded,
                      color: _isBlocked ? VibeColors.success : context.vibeError,
                    ),
                    title: Text(
                      _isBlocked ? 'Разблокировать' : 'Заблокировать',
                      style: VibeTypography.body.copyWith(
                        color:
                            _isBlocked ? VibeColors.success : context.vibeError,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: _isBlocked
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: VibeColors.success,
                            size: 20,
                          )
                        : null,
                    onTap: () => _toggleBlock(context),
                  ),
                ),
              ),
            ),
          ],
        ],
        collapsedBarBuilder: (_, progress) => VibeCollapsedTopBar(
          progress: progress,
          leading: VibeTopBarIcon(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
            tooltip: 'Назад',
          ),
          title: VibeTopBarTitle(chat.title),
        ),
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.vibeSurfaceVariant,
      borderRadius: BorderRadius.circular(VibeRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(VibeRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: VibeSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: context.vibePrimary),
              const SizedBox(height: 4),
              Text(
                label,
                style: VibeTypography.caption.copyWith(
                  color: context.vibeTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}