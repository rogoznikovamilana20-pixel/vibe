import 'dart:async';
import 'package:flutter/material.dart';

import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_collapsible_screen.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/backend.dart';
import '../core/localization/vibe_localizations.dart';
import 'chat_screen.dart';

/// Экран поиска по чатам и контактам. Фильтрация по запросу в реальном времени.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  String _query = '';
  final _controller = TextEditingController();
  List<VibeProfile> _results = [];
  List<VibeChat> _chatResults = [];
  bool _loading = false;
  Timer? _debounce;
  late final AnimationController _fieldAnim = AnimationController(
    vsync: this,
    duration: VibeAnimations.fadeIn,
  );

  @override
  void initState() {
    super.initState();
    _fieldAnim.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _fieldAnim.dispose();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    setState(() {
      _query = v;
      if (v.isEmpty) {
        _results = [];
        _chatResults = [];
        _loading = false;
        return;
      }
      // Сразу показываем индикатор, а не «Ничего не найдено»:
      // результат появится через короткий дебаунс.
      _results = [];
      _chatResults = [];
      _loading = true;
    });

    if (v.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (_query.isEmpty || !mounted) return;
      final needle = _query.trim().toLowerCase();
      try {
        // Секция «Чаты» — фильтр локального списка (как в Telegram).
        List<VibeChat> chats = [];
        try {
          chats = await VibeBackend.instance.listChats();
        } catch (_) {
          chats = await VibeBackend.instance.getOfflineChats();
        }
        final chatMatches = chats
            .where(
              (c) =>
                  c.title.toLowerCase().contains(needle) ||
                  (c.peerName?.toLowerCase().contains(needle) ?? false),
            )
            .toList();
        final users = await VibeBackend.instance.searchUsers(_query);
        if (!mounted) return;
        setState(() {
          _chatResults = chatMatches;
          _results = users;
          _loading = false;
        });
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VibeCollapsibleScreen(
        slivers: [
          SliverToBoxAdapter(
            child: VibeTopBar(
              leading: VibeTopBarIcon(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).pop(),
                tooltip: l.tooltipBack,
              ),
              actions: [
                if (_query.isEmpty)
                  const SizedBox.shrink()
                else
                  VibeTopBarIcon(
                    icon: Icons.clear_rounded,
                    onTap: () {
                      _controller.clear();
                      _onQueryChanged('');
                    },
                    tooltip: l.tooltipClear,
                  ),
              ],
              title: _buildSearchField(context, VibeTypography.body),
            ),
          ),
          if (_query.isEmpty)
            ..._buildSuggestions()
          else if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ..._buildResults(_results),
        ],
        collapsedBarBuilder: (_, progress) => VibeCollapsedTopBar(
          progress: progress,
          leading: VibeTopBarIcon(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
            tooltip: l.tooltipBack,
          ),
          title: _buildSearchField(context, VibeTypography.bodyMedium),
          actions: [
            if (_query.isNotEmpty)
              VibeTopBarIcon(
                icon: Icons.clear_rounded,
                onTap: () {
                  _controller.clear();
                  _onQueryChanged('');
                },
                tooltip: l.tooltipClear,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, TextStyle style) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _fieldAnim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.96,
          end: 1,
        ).animate(CurvedAnimation(parent: _fieldAnim, curve: Curves.easeOut)),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.md),
          decoration: BoxDecoration(
            color: context.vibeSurfaceVariant,
            borderRadius: BorderRadius.circular(VibeRadius.input),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textAlignVertical: TextAlignVertical.center,
            onChanged: _onQueryChanged,
            style: style.copyWith(color: context.vibeTextPrimary),
            cursorColor: context.vibePrimary,
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              hintText: VibeLocalizations.of(context).searchByNickHint,
              hintStyle: style.copyWith(
                color: context.vibeTextTertiary,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSuggestions() {
    return [
      const SliverToBoxAdapter(child: SizedBox(height: VibeSpacing.sm)),
      SliverToBoxAdapter(
        child: _SectionTitle(VibeLocalizations.of(context).searchGlobalTitle),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(VibeSpacing.lg),
          child: Text(
            VibeLocalizations.of(context).searchGlobalSubtitle,
            style: VibeTypography.caption.copyWith(
              color: context.vibeTextSecondary,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildResults(List<VibeProfile> results) {
    final l = VibeLocalizations.of(context);
    if (_chatResults.isEmpty && results.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: VibeSpacing.xxl * 2),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 56,
                  color: context.vibeTextTertiary,
                ),
                const SizedBox(height: VibeSpacing.md),
                Text(
                  VibeLocalizations.of(context).searchNothingFound,
                  style: VibeTypography.subtitle.copyWith(
                    color: context.vibeTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      if (_chatResults.isNotEmpty) ...[
        SliverToBoxAdapter(child: _SectionTitle(l.searchChats)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _ChatTile(chat: _chatResults[i]),
            childCount: _chatResults.length,
          ),
        ),
      ],
      if (results.isNotEmpty) ...[
        SliverToBoxAdapter(child: _SectionTitle(l.searchPeople)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _ContactTile(profile: results[i]),
            childCount: results.length,
          ),
        ),
      ],
    ];
  }
}

/// Переход в чат (единый для всех плиток поиска).
void _openChatScreen(BuildContext context, VibeChat chat) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (_, _, _) => ChatScreen(chat: chat),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.3, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: VibeAnimations.standard,
                  ),
                ),
            child: child,
          ),
        );
      },
      transitionDuration: VibeAnimations.fadeIn,
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VibeSpacing.lg,
        VibeSpacing.md,
        VibeSpacing.lg,
        VibeSpacing.xs,
      ),
      child: Text(
        title.toUpperCase(),
        style: VibeTypography.caption.copyWith(
          color: context.vibeTextTertiary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat});

  final VibeChat chat;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: VibeAvatar(
        name: chat.title,
        size: VibeSizes.avatarMd,
        online: chat.peerOnline,
        photoUrl: chat.peerAvatar,
      ),
      title: Text(
        chat.title,
        style: VibeTypography.subtitle.copyWith(color: context.vibeTextPrimary),
      ),
      subtitle: Text(
        chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: VibeTypography.body.copyWith(
          color: context.vibeTextSecondary,
          fontSize: 13,
        ),
      ),
      trailing: Text(
        chat.lastTime,
        style: VibeTypography.caption.copyWith(
          color: context.vibeTextTertiary,
          fontSize: 11,
        ),
      ),
      onTap: () => _openChatScreen(context, chat),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.profile});

  final VibeProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: VibeAvatar(
        name: profile.displayName,
        size: VibeSizes.avatarMd,
        online: profile.online,
        photoUrl: profile.avatar,
      ),
      title: Text(
        profile.displayName,
        style: VibeTypography.subtitle.copyWith(color: context.vibeTextPrimary),
      ),
      subtitle: Text(
        '@${profile.username}',
        style: VibeTypography.body.copyWith(
          color: context.vibeTextSecondary,
          fontSize: 13,
        ),
      ),
      onTap: () async {
        // Логика перехода в чат
        final chatId = await VibeBackend.instance.ensurePmChat(profile.id);
        if (context.mounted) {
          final chat = VibeChat(
            id: chatId,
            title: profile.displayName,
            kind: 'pm',
            lastMessage: '',
            lastTime: '',
            unread: 0,
            peerName: profile.displayName,
            peerAvatar: profile.avatar,
          );
          _openChatScreen(context, chat);
        }
      },
    );
  }
}
