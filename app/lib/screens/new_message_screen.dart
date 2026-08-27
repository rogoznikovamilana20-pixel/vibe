// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';

import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_collapsible_screen.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/backend.dart';
import 'chat_screen.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';
import 'package:vibe_app/core/localization/vibe_localizations.dart';

/// Экран «Новое сообщение» — как в Telegram: поле поиска контакта сверху
/// и список контактов; тап открывает переписку.
class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  String _query = '';
  final _controller = TextEditingController();
  List<VibeProfile> _profiles = [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      final all = await VibeBackend.instance.listContacts();
      final me = VibeBackend.instance.myProfileId;
      if (!mounted) return;
      setState(() => _profiles =
          all.where((p) => p.id != me).toList());
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openChat(VibeProfile peer) async {
    String chatId;
    try {
      chatId = await VibeBackend.instance.ensurePmChat(peer.id);
    } catch (_) {
      _snack(VibeLocalizations.of(context).errorServerUnavailable);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ChatScreen(
          chat: VibeChat(
            id: chatId,
            title: peer.displayName,
            kind: 'pm',
            lastMessage: '',
            lastTime: '',
            unread: 0,
            peerName: peer.displayName,
            peerAvatar: peer.avatar,
          ),
        ),
        transitionsBuilder: (_, animation, _, child) => SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: VibeAnimations.standard,
            ),
          ),
          child: child,
        ),
        transitionDuration: VibeAnimations.slideUp,
      ),
    );
  }

  void _snack(String msg) {
    VibeToast.show(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? _profiles
        : _profiles
            .where((p) =>
                p.displayName.toLowerCase().contains(q) ||
                p.username.toLowerCase().contains(q) ||
                p.id.toLowerCase().contains(q))
            .toList();

    final l = VibeLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.vibeBackground,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 0),
              child: VibeCollapsibleScreen(
                slivers: [
                  SliverToBoxAdapter(
                    child: VibeTopBar(
                      leading: VibeTopBarIcon(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).pop(),
                        tooltip: l.tooltipBack,
                      ),
                      actions: [
                        if (_query.isNotEmpty)
                          VibeTopBarIcon(
                            icon: Icons.clear_rounded,
                            onTap: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                            tooltip: l.tooltipClear,
                          ),
                      ],
                      title: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VibeTopBarTitle(l.newMessageTitle),
                          const SizedBox(height: 2),
                          Text(
                            l.newMessageSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VibeTypography.caption.copyWith(
                              color: context.vibeTextTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildSearchRow(context),
                  ),
                  if (results.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: VibeSpacing.xxl * 2),
                        child: Center(
                          child: Text(
                            l.searchNothingFound,
                            style: VibeTypography.body.copyWith(
                              color: context.vibeTextTertiary,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, i) {
                        if (i.isOdd) {
                          return Divider(
                            height: 1,
                            indent: 76,
                            color: context.vibeDivider,
                          );
                        }
                        final peer = results[i ~/ 2];
                        return ListTile(
                          onTap: () => _openChat(peer),
                          leading: VibeAvatar(
                            name: peer.displayName,
                            size: VibeSizes.avatarMd,
                            online: peer.online,
                            photoUrl: peer.avatar,
                          ),
                          title: Text(
                            peer.displayName,
                            style: VibeTypography.bodyMedium.copyWith(
                              color: context.vibeTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            peer.online ? l.statusOnline : l.statusRecently,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VibeTypography.caption.copyWith(
                              color: context.vibeTextSecondary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: VibeColors.textTertiaryDark,
                          ),
                        );
                      }, childCount: results.length * 2 - 1),
                    ),
                ],
                collapsedBarBuilder: (_, progress) => VibeCollapsedTopBar(
                  progress: progress,
                  leading: VibeTopBarIcon(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop(),
                    tooltip: l.tooltipBack,
                  ),
                  title: VibeTopBarTitle(l.newMessageTitle),
                  actions: [
                    if (_query.isNotEmpty)
                      VibeTopBarIcon(
                        icon: Icons.clear_rounded,
                        onTap: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                        tooltip: l.tooltipClear,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow(BuildContext context) {
    final l = VibeLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VibeSpacing.lg,
        VibeSpacing.sm,
        VibeSpacing.lg,
        VibeSpacing.sm,
      ),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.md),
        decoration: BoxDecoration(
          color: context.vibeSurfaceVariant,
          borderRadius: BorderRadius.circular(VibeRadius.input),
        ),
        child: Row(
          children: [
            Icon(
              VibeIcons.search,
              size: 20,
              color: context.vibeTextTertiary,
            ),
            const SizedBox(width: VibeSpacing.sm),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                textAlignVertical: TextAlignVertical.center,
                onChanged: (v) => setState(() => _query = v),
                style: VibeTypography.body.copyWith(
                  color: context.vibeTextPrimary,
                ),
                cursorColor: context.vibePrimary,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: l.searchHint,
                  hintStyle: VibeTypography.body.copyWith(
                    color: context.vibeTextTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
