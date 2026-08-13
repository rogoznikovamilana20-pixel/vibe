import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_collapsible_screen.dart';
import '../core/widgets/vibe_top_bar.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Одна находка поиска по сообщениям чата.
class ChatSearchItem {
  const ChatSearchItem({
    required this.serverId,
    required this.text,
    required this.incoming,
    required this.time,
  });

  final String serverId;
  final String text;
  final bool incoming;
  final String time;
}

/// Поиск по сообщениям чата — как в Telegram: ищем на лету, переходы
/// стрелками по «1 из N», возвращаем serverId выбранного сообщения.
class ChatSearchScreen extends StatefulWidget {
  const ChatSearchScreen({super.key, required this.items});

  final List<ChatSearchItem> items;

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  int _current = 0;
  String? _flashId;
  Timer? _flashTimer;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _flashTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<ChatSearchItem> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return widget.items
        .where((m) => m.text.toLowerCase().contains(q))
        .toList();
  }

  void _jump(int index) {
    if (_results.isEmpty) return;
    final safe = index.clamp(0, _results.length - 1);
    setState(() => _current = safe);
    _scroll.animateTo(
      (safe * 76.0).clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _flashTimer?.cancel();
    final id = _results[safe].serverId;
    setState(() => _flashId = id);
    _flashTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _flashId = null);
    });
  }

  void _pick(int index) {
    Navigator.of(context).pop(_results[index].serverId);
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

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
              actions: [
                if (_controller.text.isNotEmpty)
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
                  const VibeTopBarTitle('Поиск'),
                  const SizedBox(height: 2),
                  Text(
                    results.isEmpty
                        ? 'Введите запрос'
                        : '1 из ${results.length}',
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                VibeSpacing.lg,
                VibeSpacing.sm,
                VibeSpacing.lg,
                VibeSpacing.sm,
              ),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(
                  horizontal: VibeSpacing.md,
                ),
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
                          hintText: 'Поиск сообщений',
                          hintStyle: VibeTypography.body.copyWith(
                            color: context.vibeTextTertiary,
                          ),
                        ),
                      ),
                    ),
                    if (results.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _jump(_current - 1),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 20,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _jump(_current + 1),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (results.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: VibeSpacing.xxl * 2),
                child: Center(
                  child: Text(
                    'Сообщения не найдены',
                    style: VibeTypography.body,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final r = results[i];
                final isFlash = r.serverId == _flashId;
                return Material(
                  color: isFlash
                      ? context.vibePrimary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  child: ListTile(
                    onTap: () => _pick(i),
                    leading: Icon(
                      r.incoming
                          ? VibeIcons.back
                          : Icons.arrow_forward_rounded,
                      size: 18,
                      color: context.vibeTextTertiary,
                    ),
                    title: Text(
                      r.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VibeTypography.bodyMedium.copyWith(
                        color: context.vibeTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      r.time,
                      style: VibeTypography.caption.copyWith(
                        color: context.vibeTextTertiary,
                      ),
                    ),
                  ),
                );
              }, childCount: results.length),
            ),
        ],
        collapsedBarBuilder: (_, progress) => VibeCollapsedTopBar(
          progress: progress,
          leading: VibeTopBarIcon(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
            tooltip: 'Назад',
          ),
          title: const VibeTopBarTitle('Поиск'),
          actions: [
            if (results.isNotEmpty)
              VibeTopBarIcon(
                icon: Icons.keyboard_arrow_down_rounded,
                tooltip: 'Следующее',
                onTap: () => _jump(_current + 1),
              ),
          ],
        ),
      ),
    );
  }
}