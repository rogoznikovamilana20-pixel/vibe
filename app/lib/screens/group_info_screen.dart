import 'package:flutter/material.dart';

import '../core/localization/vibe_localizations.dart';

import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_collapsible_screen.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/backend.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Результат закрытия инфо-группы.
class GroupInfoResult {
  const GroupInfoResult({this.renamedTitle, this.left = false});

  /// Группу переименовали (новое название).
  final String? renamedTitle;

  /// Участник вышел из группы — экран чата закрываем.
  final bool left;
}

/// Инфо о группе — как в Telegram: состав участников, переименование,
/// выход. Открывается тапом по пилюле в шапке группового чата.
class GroupInfoScreen extends StatefulWidget {
  const GroupInfoScreen({
    super.key,
    required this.chatId,
    required this.title,
  });

  final String chatId;

  /// Текущее название (кастомное или сгенерированное из имён).
  final String title;

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  List<VibeProfile> _members = const [];
  bool _loading = true;
  bool _busy = false;

  String? get _myId => VibeBackend.instance.myProfileId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await VibeBackend.instance.groupMembers(widget.chatId);
      if (mounted) setState(() => _members = members);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _rename() async {
    final l = VibeLocalizations.of(context);
    final controller = TextEditingController(text: widget.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.vibeSurface,
        title: Text(l.groupNameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          style: VibeTypography.body.copyWith(
            color: context.vibeTextPrimary,
          ),
          cursorColor: context.vibePrimary,
          decoration: InputDecoration(
            hintText: l.groupInfoNameHint,
            hintStyle: VibeTypography.body.copyWith(
              color: context.vibeTextTertiary,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.dialogCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: context.vibePrimary,
            ),
            child: Text(l.dialogSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newTitle == null || newTitle.isEmpty || newTitle == widget.title) {
      return;
    }
    setState(() => _busy = true);
    final ok = await VibeBackend.instance.renameGroup(widget.chatId, newTitle);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop(GroupInfoResult(renamedTitle: newTitle));
    } else {
      _snack(l.groupRenameFailed);
    }
  }

  Future<void> _leave() async {
    final l = VibeLocalizations.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          VibeSpacing.xl,
          VibeSpacing.xs,
          VibeSpacing.xl,
          VibeSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.groupLeaveTitle,
              style: VibeTypography.subtitle.copyWith(
                color: context.vibeTextPrimary,
              ),
            ),
            const SizedBox(height: VibeSpacing.xs),
            Text(
              'Вы перестанете получать сообщения этой группы. '
              'Историю можно будет посмотреть заново, если вас пригласят.',
              style: VibeTypography.body.copyWith(
                color: context.vibeTextSecondary,
              ),
            ),
            const SizedBox(height: VibeSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: VibeSizes.buttonHeight,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: context.vibeError,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VibeRadius.button),
                  ),
                  textStyle: VibeTypography.button,
                ),
                child: Text(l.groupLeaveConfirm),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final ok = await VibeBackend.instance.leaveGroup(widget.chatId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop(const GroupInfoResult(left: true));
    } else {
      _snack(l.groupLeaveFailed);
    }
  }

  void _snack(String text) {
    VibeToast.show(context, text);
  }

  Widget _groupAvatar(BuildContext context) {
    final shown = _members.take(4).toList();
    if (shown.isEmpty) {
      return Container(
        width: VibeSizes.avatarXl,
        height: VibeSizes.avatarXl,
        decoration: BoxDecoration(
          color: context.vibeSurfaceVariant,
          borderRadius: BorderRadius.circular(VibeRadius.avatar),
        ),
        child: Icon(
          VibeIcons.group,
          size: 36,
          color: context.vibePrimary,
        ),
      );
    }
    const size = 96.0;
    const overlap = 26.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i == 0
                  ? 0
                  : (i == 1
                      ? size - overlap
                      : (i == 2 ? (size - overlap) / 2 - 12 : size - overlap)),
              top: i < 2 ? 0 : size - overlap,
              child: Container(
                width: overlap + 10,
                height: overlap + 10,
                decoration: BoxDecoration(
                  color: context.vibeSurface,
                  shape: BoxShape.circle,
                ),
                child: VibeAvatar(
                  name: shown[i].displayName,
                  size: overlap,
                  photoUrl: shown[i].avatar,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    final members = _members;

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
              title: VibeTopBarTitle(l.groupInfoTitle),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: VibeSpacing.lg),
                _groupAvatar(context),
                const SizedBox(height: VibeSpacing.md),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: VibeTypography.title.copyWith(
                    color: context.vibeTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _loading
                      ? l.groupLoading
                      : '${members.length} участник(а)',
                  style: VibeTypography.bodyMedium.copyWith(
                    color: context.vibeTextTertiary,
                  ),
                ),
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
                    child: _GroupAction(
                      icon: VibeIcons.edit,
                      label: l.groupInfoRename,
                      onTap: _busy ? null : _rename,
                    ),
                  ),
                  const SizedBox(width: VibeSpacing.md),
                  Expanded(
                    child: _GroupAction(
                      icon: Icons.logout_rounded,
                      label: l.groupInfoLeave,
                      color: context.vibeError,
                      onTap: _busy ? null : _leave,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                VibeSpacing.xl,
                VibeSpacing.sm,
                VibeSpacing.xl,
                VibeSpacing.sm,
              ),
              child: Text(
                l.groupMembers,
                style: VibeTypography.subtitle.copyWith(
                  color: context.vibeTextPrimary,
                ),
              ),
            ),
          ),
          if (members.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: VibeSpacing.xl),
                child: Center(
                   child: Text(l.groupNoMembers, style: VibeTypography.body),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final p = members[i];
                final isMe = p.id == _myId;
                final isOnline = p.online;
                return ListTile(
                  leading: VibeAvatar(
                    name: p.displayName,
                    size: VibeSizes.avatarMd,
                    online: isOnline,
                    photoUrl: p.avatar,
                  ),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          p.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: VibeTypography.bodyMedium.copyWith(
                            color: context.vibeTextPrimary,
                          ),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Text(
                          l.chatYou,
                          style: VibeTypography.caption.copyWith(
                            color: context.vibeTextTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    isOnline ? l.statusOnline : l.statusRecently,
                    style: VibeTypography.caption.copyWith(
                      color: isOnline
                          ? VibeColors.success
                          : context.vibeTextTertiary,
                    ),
                  ),
                );
              }, childCount: members.length),
            ),
        ],
        collapsedBarBuilder: (_, progress) => VibeCollapsedTopBar(
          progress: progress,
          leading: VibeTopBarIcon(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
            tooltip: l.tooltipBack,
          ),
              title: VibeTopBarTitle(l.groupInfoTitle),
        ),
      ),
    );
  }
}

class _GroupAction extends StatelessWidget {
  const _GroupAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

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
              Icon(icon, size: 22, color: color ?? context.vibePrimary),
              const SizedBox(height: 4),
              Text(
                label,
                style: VibeTypography.caption.copyWith(
                  color: color ?? context.vibeTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}