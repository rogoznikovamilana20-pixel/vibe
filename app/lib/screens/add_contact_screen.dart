import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/vibe_button.dart';
import '../core/widgets/vibe_collapsible_screen.dart';
import '../core/widgets/vibe_input.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/backend.dart';
import '../data/backend_api.dart';
import 'chat_screen.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';

/// 8.3.1: добавление контакта — как в Telegram: имя/@ник → поиск
/// → «Написать» (открывает pm-чат). Если никого не нашли — приглашение
/// друга в один тап (копирует пригласительный текст в буфер).
class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key, this.backend});

  final VibeBackendApi? backend;

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  late final VibeBackendApi _backend = widget.backend ?? LiveVibeBackend();
  final _query = TextEditingController();
  List<VibeProfile> _results = const [];
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _searched = true;
    });
    try {
      final res = await _backend.searchUsers(q);
      if (!mounted) return;
      final me = _backend.myProfileId;
      setState(() {
        _results = res.where((p) => p.id != me).toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _searching = false);
        _snack('Поиск недоступен — проверьте сеть');
      }
    }
  }

  Future<void> _writeTo(VibeProfile p) async {
    final chatId = await _backend.ensurePmChat(p.id);
    if (!mounted) return;
    final chat = await _backend.chatById(chatId);
    if (chat == null || !mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ChatScreen(chat: chat, backend: _backend),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: VibeAnimations.standard,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: VibeAnimations.fadeIn,
      ),
    );
  }

  void _invite() {
    Clipboard.setData(
      const ClipboardData(text: 'Заходи в Vibe — мой мессенджер. Жду тебя!'),
    );
    _snack('Приглашение скопировано — отправьте его другу');
  }

  void _snack(String msg) {
    VibeToast.show(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VibeCollapsibleScreen(
        slivers: [
          SliverToBoxAdapter(
            child: VibeTopBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.of(context).pop(),
                color: context.vibeTextPrimary,
              ),
              title: const VibeTopBarTitle('Новый контакт'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              VibeSpacing.lg,
              VibeSpacing.sm,
              VibeSpacing.lg,
              VibeSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: VibeInput(
                      controller: _query,
                      hint: 'Имя или @ник',
                      prefixIcon: Icons.search_rounded,
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: VibeSpacing.sm),
                  VibeButton(
                    label: 'Найти',
                    onPressed: _searching ? null : _search,
                    expand: false,
                    size: VibeButtonSize.s,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
            sliver: _searched && !_searching && _results.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_search_rounded,
                            size: 56,
                            color: context.vibeTextTertiary,
                          ),
                          const SizedBox(height: VibeSpacing.md),
                          Text(
                            'Никого не нашли',
                            style: VibeTypography.body.copyWith(
                              color: context.vibeTextSecondary,
                            ),
                          ),
                          const SizedBox(height: VibeSpacing.lg),
                          VibeButton(
                            label: 'Пригласить друга',
                            icon: Icons.ios_share_rounded,
                            onPressed: _invite,
                            type: VibeButtonType.secondary,
                            size: VibeButtonSize.m,
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildListDelegate(
                      _results.map((p) => _ResultTile(
                            profile: p,
                            onTap: () => _writeTo(p),
                          )).toList(),
                    ),
                  ),
          ),
        ],
        collapsedBarBuilder: (_, progress) => VibeTopBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
            color: context.vibeTextPrimary,
          ),
          title: const VibeTopBarTitle('Новый контакт'),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.profile, required this.onTap});

  final VibeProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: VibeSpacing.sm,
            vertical: 8,
          ),
          child: Row(
            children: [
              VibeAvatar(
                name: profile.displayName,
                size: VibeSizes.avatarMd,
                emoji: profile.emoji,
                photoUrl: profile.avatar,
              ),
              const SizedBox(width: VibeSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VibeTypography.bodyMedium.copyWith(
                        color: context.vibeTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      profile.username.isEmpty
                          ? ''
                          : '@${profile.username}',
                      style: VibeTypography.caption.copyWith(
                        color: context.vibeTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Написать',
                style: VibeTypography.caption.copyWith(
                  color: context.vibePrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}