import 'package:flutter/foundation.dart';

/// Простой стек последних экранов для long-press back (PRD 2.3.3),
/// как в Telegram: лонг-тап по стрелке назад показывает последние N чатов/экранов.
class BackHistoryService {
  BackHistoryService._();
  static final instance = BackHistoryService._();

  static const int maxSize = 10;

  final List<BackHistoryEntry> _entries = [];

  List<BackHistoryEntry> get entries => List.unmodifiable(_entries);

  final ValueNotifier<int> version = ValueNotifier<int>(0);

  void push(BackHistoryEntry entry) {
    // Убираем дубликат того же chatId/route, затем вставляем в начало.
    _entries.removeWhere((e) => e.key == entry.key);
    _entries.insert(0, entry);
    if (_entries.length > maxSize) _entries.removeRange(maxSize, _entries.length);
    version.value++;
  }

  void pushChat({required String chatId, required String title}) {
    push(BackHistoryEntry(
      key: 'chat:$chatId',
      title: title,
      subtitle: 'Чат',
      chatId: chatId,
    ));
  }

  void pushTab(int index, String title) {
    push(BackHistoryEntry(
      key: 'tab:$index',
      title: title,
      subtitle: 'Вкладка',
      tabIndex: index,
    ));
  }

  void clear() {
    _entries.clear();
    version.value++;
  }
}

class BackHistoryEntry {
  const BackHistoryEntry({
    required this.key,
    required this.title,
    required this.subtitle,
    this.chatId,
    this.tabIndex,
  });

  final String key;
  final String title;
  final String subtitle;
  final String? chatId;
  final int? tabIndex;
}
