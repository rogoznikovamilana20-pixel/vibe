// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_button.dart';
import '../core/widgets/vibe_icon_button.dart';
import '../core/widgets/vibe_input.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../data/backend.dart';
import '../data/chat_folder.dart';
import '../data/settings_service.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';
import '../core/localization/vibe_localizations.dart';

/// 8.3.7: экран «Папки» — список пользовательских папок чатов.
/// Каждая папка — название + эмодзи; состав чатов назначается вручную.
class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key, required this.chats});

  /// Снимок списка чатов для показа состава папок.
  final List<VibeChat> chats;

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    final settings = SettingsService.instance;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: VibeTopBarAppBar(
        topInset: MediaQuery.paddingOf(context).top,
        child: VibeTopBar(
          leading: VibeIconButton(
            icon: VibeIcons.back,
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: l.tooltipBack,
          ),
          title: VibeTopBarTitle(l.foldersTitle),
        ),
      ),
      body: ListenableBuilder(
        listenable: settings.foldersVersion,
        builder: (context, _) {
          final folders = settings.chatFolders;
          if (folders.isEmpty) {
            return _buildEmpty(context);
          }
          return Column(
            children: [
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    VibeSpacing.lg,
                    VibeSpacing.sm,
                    VibeSpacing.lg,
                    VibeSpacing.sm,
                  ),
                  buildDefaultDragHandles: false,
                  itemCount: folders.length,
                  onReorder: (oldIndex, newIndex) => settings.reorderFolders(oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final f = folders[index];
                    return ReorderableDragStartListener(
                      key: ValueKey(f.id),
                      index: index,
                      child: _folderTile(context, f),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  VibeSpacing.lg,
                  0,
                  VibeSpacing.lg,
                  VibeSpacing.xxl,
                ),
                child: VibeButton(
                  label: l.foldersNewFolder,
                  icon: Icons.create_new_folder_outlined,
                  size: VibeButtonSize.s,
                  expand: true,
                  onPressed: () => _openEditor(context, null),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final l = VibeLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: context.vibePrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 40,
                color: context.vibePrimary,
              ),
            ),
            const SizedBox(height: VibeSpacing.lg),
            Text(
              l.foldersEmptyTitle,
              style: VibeTypography.subtitle.copyWith(
                color: context.vibeTextPrimary,
              ),
            ),
            const SizedBox(height: VibeSpacing.sm),
            Text(
              l.foldersEmptySubtitle,
              textAlign: TextAlign.center,
              style: VibeTypography.bodyMedium.copyWith(
                color: context.vibeTextSecondary,
              ),
            ),
            const SizedBox(height: VibeSpacing.xl),
            VibeButton(
              label: l.foldersCreateFolder,
              icon: Icons.create_new_folder_outlined,
              onPressed: () => _openEditor(context, null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _folderTile(BuildContext context, VibeChatFolder folder) {
    final settings = SettingsService.instance;
    final chatsInFolder = widget.chats.where((c) => settings.folderOf(c.id) == folder.id).toList();
    final count = chatsInFolder.length;
    final unread = chatsInFolder.fold(0, (s, c) => s + c.unread);
    return Padding(
      padding: const EdgeInsets.only(bottom: VibeSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(VibeRadius.card),
          onTap: () => _openEditor(context, folder.id),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: VibeSpacing.lg,
              vertical: VibeSpacing.md,
            ),
            decoration: BoxDecoration(
              color: context.vibeSurfaceHigh,
              borderRadius: BorderRadius.circular(VibeRadius.card),
            ),
            child: Row(
              children: [
                Text(folder.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: VibeSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.title,
                        style: VibeTypography.body.copyWith(
                          color: context.vibeTextPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _plural(count),
                            style: VibeTypography.caption.copyWith(
                              color: context.vibeTextTertiary,
                            ),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: VibeColors.unreadBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$unread',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.drag_handle_rounded, color: context.vibeTextTertiary, size: 20),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.vibeTextTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _plural(int n) {
    if (n % 10 == 1 && n % 100 != 11) return '$n чат';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14)) {
      return '$n чата';
    }
    return '$n чатов';
  }

  Future<void> _openEditor(BuildContext context, String? folderId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FolderEditScreen(
          folderId: folderId,
          chats: widget.chats,
        ),
      ),
    );
  }
}

/// Редактор папки: название, эмодзи, состав чатов (и удаление).
class FolderEditScreen extends StatefulWidget {
  const FolderEditScreen({
    super.key,
    required this.folderId,
    required this.chats,
  });

  /// null — создание новой папки.
  final String? folderId;
  final List<VibeChat> chats;

  @override
  State<FolderEditScreen> createState() => _FolderEditScreenState();
}

class _FolderEditScreenState extends State<FolderEditScreen> {
  static const _emojis = ['📁', '⭐', '💼', '🎮', '🎵', '📚', '✈️', '❤️', '🌙'];

  late final TextEditingController _title;
  late String _emoji;
  late final Set<String> _assigned;
  late Set<String> _filters;

  bool get _isNew => widget.folderId == null;

  @override
  void initState() {
    super.initState();
    final settings = SettingsService.instance;
    final folder = _isNew
        ? null
        : settings.chatFolders.where((f) => f.id == widget.folderId).firstOrNull;
    _title = TextEditingController(text: folder?.title ?? '');
    _emoji = folder?.emoji ?? _emojis.first;
    _filters = Set<String>.from(folder?.filters ?? const <String>{});
    _assigned = {
      for (final c in widget.chats)
        if (settings.folderOf(c.id) == widget.folderId) c.id,
    };
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = SettingsService.instance;
    final title = _title.text.trim();
    if (title.isEmpty) {
      VibeToast.show(context, VibeLocalizations.of(context).foldersNameRequired);
      return;
    }
    if (_isNew) {
      // Новая папка: сначала создаём, затем назначаем выбранные чаты.
      final before = settings.chatFolders.length;
      await settings.addFolder(title, emoji: _emoji, filters: _filters);
      if (settings.chatFolders.length == before) return;
      final newId = settings.chatFolders.last.id;
      for (final c in widget.chats) {
        await settings.setFolderForChat(c.id, _assigned.contains(c.id) ? newId : null);
      }
    } else {
      await settings.renameFolder(widget.folderId!, title, emoji: _emoji, filters: _filters);
      for (final c in widget.chats) {
        final inThis = _assigned.contains(c.id);
        final now = settings.folderOf(c.id);
        if (inThis && now != widget.folderId) {
          // Перемещение из другой папки: снимаем старое назначение.
          await settings.setFolderForChat(c.id, widget.folderId);
        } else if (!inThis && now == widget.folderId) {
          await settings.setFolderForChat(c.id, null);
        }
      }
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _delete() async {
    final settings = SettingsService.instance;
    await settings.removeFolder(widget.folderId!);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: VibeTopBarAppBar(
        topInset: MediaQuery.paddingOf(context).top,
        child: VibeTopBar(
          leading: VibeIconButton(
            icon: VibeIcons.back,
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: l.tooltipBack,
          ),
          title: VibeTopBarTitle(_isNew ? l.foldersNewFolder : l.foldersTitle),
          actions: [
            if (!_isNew)
              VibeIconButton(
                icon: Icons.delete_outline_rounded,
                onPressed: _delete,
                tooltip: l.foldersDeleteFolder,
                color: context.vibeError,
              ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          VibeSpacing.lg,
          VibeSpacing.sm,
          VibeSpacing.lg,
          VibeSpacing.xxl,
        ),
        children: [
          VibeInput(
            hint: l.foldersNameHint,
            controller: _title,
            autofocus: _isNew,
          ),
          const SizedBox(height: VibeSpacing.md),
          Text(
            l.foldersEmojiLabel,
            style: VibeTypography.caption.copyWith(
              color: context.vibeTextTertiary,
            ),
          ),
          const SizedBox(height: VibeSpacing.sm),
          Wrap(
            spacing: VibeSpacing.sm,
            runSpacing: VibeSpacing.sm,
            children: [
              for (final e in _emojis)
                GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: AnimatedContainer(
                    duration: VibeAnimations.fast,
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _emoji == e
                          ? context.vibePrimary.withValues(alpha: 0.18)
                          : context.vibeSurfaceHigh,
                      borderRadius: BorderRadius.circular(VibeRadius.card),
                      border: Border.all(
                        color: _emoji == e
                            ? context.vibePrimary
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: VibeSpacing.lg),
          SwitchListTile(
            title: const Text('Только непрочитанные'),
            value: _filters.contains('unread'),
            onChanged: (v) => setState(() {
              if (v) {
                _filters.add('unread');
              } else {
                _filters.remove('unread');
              }
            }),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('Без звука'),
            subtitle: const Text('Только чаты без звука', style: TextStyle(fontSize: 12)),
            value: _filters.contains('muted'),
            onChanged: (v) => setState(() {
              if (v) {
                _filters.add('muted');
              } else {
                _filters.remove('muted');
              }
            }),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: VibeSpacing.lg),
          Text(
            'Чаты в папке — ${_assigned.length}',
            style: VibeTypography.caption.copyWith(
              color: context.vibeTextTertiary,
            ),
          ),
          const SizedBox(height: VibeSpacing.sm),
          if (widget.chats.isEmpty)
            Padding(
              padding: const EdgeInsets.all(VibeSpacing.lg),
              child: Text(
                l.foldersNoChats,
                style: VibeTypography.bodyMedium.copyWith(
                  color: context.vibeTextSecondary,
                ),
              ),
            ),
          for (final c in widget.chats)
            InkWell(
              onTap: () => setState(() {
                if (_assigned.contains(c.id)) {
                  _assigned.remove(c.id);
                } else {
                  _assigned.add(c.id);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: VibeSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      _assigned.contains(c.id)
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: _assigned.contains(c.id)
                          ? context.vibePrimary
                          : context.vibeTextTertiary,
                    ),
                    const SizedBox(width: VibeSpacing.md),
                    Expanded(
                      child: Text(
                        c.title,
                        style: VibeTypography.body.copyWith(
                          color: context.vibeTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: VibeSpacing.xl),
          VibeButton(
            label: _isNew ? l.foldersCreateFolder : l.dialogSave,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}