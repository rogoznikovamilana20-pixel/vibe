// PR3: DiffUtil для списка чатов — как в Telegram DialogsAdapter + DiffUtil.
// Вычисляет added/removed/moved по id, чтобы избежать rebuild всего списка.
// Пока используется как helper для _visible.sort, далее — для AnimatedList.
import '../../data/backend.dart';

class ChatListDiff {
  const ChatListDiff({
    required this.added,
    required this.removed,
    required this.moved,
    required this.unchanged,
  });

  final List<VibeChat> added;
  final List<VibeChat> removed;
  final List<(VibeChat, int newIndex)> moved;
  final List<VibeChat> unchanged;

  static ChatListDiff compute(List<VibeChat> oldList, List<VibeChat> newList) {
    final oldById = {for (final c in oldList) c.id: c};
    final newById = {for (final c in newList) c.id: c};
    final newIndexById = {for (var i = 0; i < newList.length; i++) newList[i].id: i};

    final added = <VibeChat>[];
    final removed = <VibeChat>[];
    final moved = <(VibeChat, int)>[];
    final unchanged = <VibeChat>[];

    for (final c in newList) {
      if (!oldById.containsKey(c.id)) {
        added.add(c);
      } else {
        final oldIdx = oldList.indexWhere((x) => x.id == c.id);
        final newIdx = newIndexById[c.id]!;
        if (oldIdx != newIdx) {
          moved.add((c, newIdx));
        } else {
          unchanged.add(c);
        }
      }
    }
    for (final c in oldList) {
      if (!newById.containsKey(c.id)) removed.add(c);
    }
    return ChatListDiff(added: added, removed: removed, moved: moved, unchanged: unchanged);
  }

  bool get hasChanges => added.isNotEmpty || removed.isNotEmpty || moved.isNotEmpty;
}
