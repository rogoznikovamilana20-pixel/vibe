/// 8.3.7: пользовательская папка чатов (локальная, как удалённые чаты).
/// Папка — название + эмодзи; состав — ручное назначение чатов.
class VibeChatFolder {
  const VibeChatFolder({
    required this.id,
    required this.title,
    this.emoji = '📁',
    this.filters = const {},
  });

  final String id;
  final String title;
  final String emoji;
  final Set<String> filters; // e.g. {'unread','muted'}

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'emoji': emoji, 'filters': filters.toList()};

  factory VibeChatFolder.fromJson(Map<String, dynamic> json) => VibeChatFolder(
        id: json['id'] as String,
        title: json['title'] as String,
        emoji: (json['emoji'] as String?) ?? '📁',
        filters: ((json['filters'] as List?)?.cast<String>() ?? const <String>[]).toSet(),
      );
}