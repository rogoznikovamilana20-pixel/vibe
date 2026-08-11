import 'package:flutter/material.dart';

import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_collapsible_screen.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/backend.dart';

/// Экран «Переслать» — как в Telegram: выбор одного или нескольких чатов
/// галочками, внизу кнопка «Отправить» (переслать выбранным).
class ForwardPickerScreen extends StatefulWidget {
  const ForwardPickerScreen({super.key, required this.chats});

  final List<VibeChat> chats;

  @override
  State<ForwardPickerScreen> createState() => _ForwardPickerScreenState();
}

class _ForwardPickerScreenState extends State<ForwardPickerScreen> {
  final Set<String> _selected = {};
  String _query = '';
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(VibeChat c) {
    setState(() {
      if (!_selected.add(c.id)) {
        _selected.remove(c.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? widget.chats
        : widget.chats
            .where((c) =>
                c.title.toLowerCase().contains(q) ||
                (c.peerName ?? '').toLowerCase().contains(q))
            .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: VibeCollapsibleScreen(
              slivers: [
                SliverToBoxAdapter(
                  child: VibeTopBar(
                    leading: VibeTopBarIcon(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                      tooltip: 'Назад',
                    ),
                    actions: [
                      if (_query.isNotEmpty)
                        VibeTopBarIcon(
                          icon: Icons.clear_rounded,
                          onTap: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                          tooltip: 'Очистить',
                        ),
                    ],
                    title: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const VibeTopBarTitle('Переслать'),
                        const SizedBox(height: 2),
                        Text(
                          'Выберите чаты',
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
                          'Никого не нашли',
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
                      final chat = results[i ~/ 2];
                      final isChecked = _selected.contains(chat.id);
                      return ListTile(
                        onTap: () => _toggle(chat),
                        leading: VibeAvatar(
                          name: chat.title,
                          size: VibeSizes.avatarMd,
                          online: chat.peerOnline,
                          photoUrl: chat.peerAvatar,
                        ),
                        title: Text(
                          chat.title,
                          style: VibeTypography.bodyMedium.copyWith(
                            color: context.vibeTextPrimary,
                          ),
                        ),
                        trailing: Icon(
                          isChecked
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: isChecked
                              ? context.vibePrimary
                              : context.vibeTextTertiary,
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
                  tooltip: 'Назад',
                ),
                title: const VibeTopBarTitle('Переслать'),
                actions: [
                  if (_selected.isNotEmpty)
                    VibeTopBarIcon(
                      icon: Icons.send_rounded,
                      tooltip: 'Отправить',
                      onTap: () =>
                          Navigator.of(context).pop(_selected.toList()),
                    ),
                ],
              ),
            ),
          ),
          if (_selected.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  VibeSpacing.lg,
                  VibeSpacing.sm,
                  VibeSpacing.lg,
                  VibeSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: VibeSizes.buttonHeight,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_selected.toList()),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.vibePrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          VibeRadius.button,
                        ),
                      ),
                      textStyle: VibeTypography.button,
                    ),
                    child: Text(
                      _selected.length == 1
                          ? 'Отправить'
                          : 'Отправить (${_selected.length})',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchRow(BuildContext context) {
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
              Icons.search_rounded,
              size: 20,
              color: context.vibeTextTertiary,
            ),
            const SizedBox(width: VibeSpacing.sm),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: false,
                textAlignVertical: TextAlignVertical.center,
                onChanged: (v) => setState(() => _query = v),
                style: VibeTypography.body.copyWith(
                  color: context.vibeTextPrimary,
                ),
                cursorColor: context.vibePrimary,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: 'Поиск',
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