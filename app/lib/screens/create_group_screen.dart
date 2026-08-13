import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_collapsible_screen.dart';
import '../core/widgets/vibe_input.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/backend.dart';
import 'chat_screen.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// «Создать группу» как в Telegram: выбираем участников из контактов,
/// создаём групповой чат и сразу открываем его.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  List<VibeProfile> _contacts = const [];
  List<VibeProfile> _remote = const [];
  final Set<String> _selected = {};
  bool _creating = false;
  bool _loading = true;
  Timer? _debounce;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await VibeBackend.instance.listContacts();
      final me = VibeBackend.instance.myProfileId;
      final sorted = [...list]
        ..removeWhere((p) => p.id == me)
        ..sort((a, b) => (a.displayName)
            .toLowerCase()
            .compareTo((b.displayName).toLowerCase()));
      if (mounted) setState(() => _contacts = sorted);
    } catch (_) {
      if (mounted) _snack('Не удалось загрузить контакты');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String v) {
    setState(() {});
    _debounce?.cancel();
    final q = v.trim();
    if (q.isEmpty) {
      if (_remote.isNotEmpty) setState(() => _remote = const []);
      return;
    }
    // Глобальный поиск по Vibe (на случай, если контактов ещё нет).
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final r = await VibeBackend.instance.searchUsers(q);
        if (mounted && q == _searchController.text.trim()) {
          setState(() => _remote = r);
        }
      } catch (_) {}
    });
  }

  Future<void> _create() async {
    if (_selected.isEmpty || _creating) return;
    HapticFeedback.lightImpact();
    setState(() => _creating = true);
    final chatId =
        await VibeBackend.instance.createGroupChat(_selected.toList());
    if (!mounted) return;
    if (chatId.isEmpty) {
      setState(() => _creating = false);
      _snack('Не удалось создать группу');
      return;
    }
    final chat = await VibeBackend.instance.chatById(chatId);
    if (!mounted) return;
    if (chat == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
    );
  }

  void _snack(String msg) {
    VibeToast.show(context, msg);
  }

  List<VibeProfile> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _contacts;
    if (_contacts.isEmpty) return _remote;
    return _contacts
        .where((p) =>
            p.displayName.toLowerCase().contains(q) ||
            p.username.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final count = _selected.length;
    return Scaffold(
      backgroundColor: context.vibeSurfaceLow,
      body: Column(
        children: [
          VibeCollapsibleScreen(
            collapseStart: 100,
            bottomPadding: VibeSpacing.xxl,
            slivers: [
              SliverToBoxAdapter(
                child: VibeTopBar(
                  leading: VibeTopBarIcon(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop(),
                    tooltip: 'Назад',
                  ),
                  title: const VibeTopBarTitle('Новая группа'),
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
                    prefixIcon: VibeIcons.search,
                    onChanged: _onSearchChanged,
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
                              Icons.group_add_outlined,
                              size: 56,
                              color: context.vibeTextTertiary,
                            ),
                            const SizedBox(height: VibeSpacing.md),
                            Text(
                              _contacts.isEmpty
                                  ? 'Пока нет контактов для добавления'
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
                        _MemberTile(
                          profile: p,
                          selected: _selected.contains(p.id),
                          onTap: () => setState(() {
                            if (!_selected.add(p.id)) {
                              _selected.remove(p.id);
                            }
                            HapticFeedback.selectionClick();
                          }),
                        ),
                  ]),
                ),
              ),
            ],
            collapsedBarBuilder: (_, progress) => VibeCollapsedTopBar(
              progress: progress,
              leading: VibeTopBarIcon(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).pop(),
                tooltip: 'Назад',
              ),
              title: const VibeTopBarTitle('Новая группа'),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                VibeSpacing.lg,
                VibeSpacing.sm,
                VibeSpacing.lg,
                VibeSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                height: VibeSizes.buttonHeight,
                child: FilledButton(
                  onPressed: count == 0 || _creating ? null : _create,
                  child: _creating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          count == 0
                              ? 'Выберите участников'
                              : 'Создать группу ($count)',
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final VibeProfile profile;
  final bool selected;
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
                    if (profile.username.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        '@${profile.username}',
                        style: VibeTypography.caption.copyWith(
                          color: context.vibeTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedContainer(
                duration: VibeAnimations.pulse,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? context.vibePrimary
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? context.vibePrimary
                        : context.vibeBorder,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(
                        VibeIcons.check,
                        size: 17,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}