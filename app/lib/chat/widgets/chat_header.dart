// PR2 incremental: вынос _buildHeader из chat_screen.dart
// Сохраняет логику pinned/muted/archived, SettingsService, VibeTopBar — только перенос.
import 'package:flutter/material.dart';

import '../../core/theme/vibe_theme.dart';
import '../../core/widgets/vibe_top_bar.dart';
import '../../data/backend.dart';

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.chat,
    required this.selectionMode,
    required this.selectedCount,
    required this.onClearSelection,
    required this.onMarkRead,
    required this.onArchive,
    required this.onHide,
    required this.onDelete,
    required this.onDone,
  });

  final VibeChat chat;
  final bool selectionMode;
  final int selectedCount;
  final VoidCallback onClearSelection;
  final VoidCallback onMarkRead;
  final VoidCallback onArchive;
  final VoidCallback onHide;
  final VoidCallback onDelete;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    if (selectionMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text('$selectedCount', style: TextStyle(color: context.vibePrimary)),
          const Spacer(),
          IconButton(onPressed: onClearSelection, icon: const Icon(Icons.clear_rounded)),
          IconButton(onPressed: onMarkRead, icon: const Icon(Icons.done_all_rounded)),
          IconButton(onPressed: onArchive, icon: const Icon(Icons.archive_outlined)),
          IconButton(onPressed: onHide, icon: const Icon(Icons.visibility_off_rounded)),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded)),
          IconButton(onPressed: onDone, icon: const Icon(Icons.check_rounded)),
        ]),
      );
    }
    return VibeTopBar(
      title: Text(chat.title, style: TextStyle(color: context.vibeTextPrimary)),
      actions: [
        VibeTopBarIcon(icon: Icons.search_rounded, onTap: () {}, tooltip: 'Поиск'),
        VibeTopBarIcon(icon: Icons.more_vert_rounded, onTap: () {}, tooltip: 'Меню'),
      ],
    );
  }
}
