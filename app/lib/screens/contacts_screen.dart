import 'package:flutter/material.dart';

import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/vibe_chat_icon.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_collapsible_screen.dart';
import '../core/widgets/vibe_input.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/backend.dart';
import 'chat_screen.dart';

/// Вкладка «Контакты» — как в Telegram: поиск и список людей.
/// Тап по контакту открывает чат с ним.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<VibeProfile> _all = const [];
  List<VibeProfile> _filtered = const [];
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await VibeBackend.instance.listContacts();
      final me = VibeBackend.instance.myProfileId;
      final sorted = [...list]
        ..removeWhere((p) => p.id == me)
        ..sort((a, b) =>
            (a.displayName).toLowerCase().compareTo((b.displayName).toLowerCase()));
      setState(() {
        _all = sorted;
        _applyFilter();
      });
    } catch (_) {
      _snack('Не удалось загрузить контакты');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((p) {
              return p.displayName.toLowerCase().contains(q) ||
                  p.username.toLowerCase().contains(q);
            }).toList();
    });
  }

  Future<void> _openChat(VibeProfile p) async {
    final chatId = await VibeBackend.instance.ensurePmChat(p.id);
    if (!mounted) return;
    final chat = await VibeBackend.instance.chatById(chatId);
    if (chat == null || !mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ChatScreen(chat: chat),
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

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
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
                icon: const Icon(Icons.person_add_alt_1_rounded),
                onPressed: () => _snack('Добавление контакта — скоро'),
                color: context.vibeTextPrimary,
                tooltip: 'Добавить контакт',
              ),
              title: const VibeTopBarTitle('Контакты'),
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
              child: VibeInput(
                controller: _searchController,
                hint: 'Поиск по имени или @нику',
                prefixIcon: Icons.search_rounded,
                onChanged: (_) => _applyFilter(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 56,
                          color: context.vibeTextTertiary,
                        ),
                        const SizedBox(height: VibeSpacing.md),
                        Text(
                          _all.isEmpty
                              ? 'Пока нет контактов'
                              : 'Ничего не найдено',
                          style: VibeTypography.body.copyWith(
                            color: context.vibeTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final p in _filtered)
                    _ContactTile(profile: p, onTap: () => _openChat(p)),
              ]),
            ),
          ),
        ],
        collapsedBarBuilder: (_, progress) => VibeCollapsedTopBar(
          progress: progress,
          leading: IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => _snack('Добавление контакта — скоро'),
            color: context.vibeTextPrimary,
          ),
          title: const VibeTopBarTitle('Контакты'),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.profile, required this.onTap});

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
                online: profile.online,
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
                    const SizedBox(height: 1),
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
              VibeChatIcon(
                size: 20,
                color: context.vibeTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}