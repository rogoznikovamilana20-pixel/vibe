// ignore_for_file: unused_field
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend.dart';
import '../message_cache.dart';

/// Репозиторий чатов — Single Writer для списка чатов.
/// Сейчас — тонкая обвязка над VibeBackend (God Object 3388 строк),
/// постепенно мигрируем сюда логику из backend.dart для Android+Desktop параллельно.
class ChatRepository {
  ChatRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<VibeChat>> getOfflineChats() async {
    // Hive-шифр + файл fallback уже внутри backend._readCache, но для
    // репозитория идём напрямую через VibeMessageCache (быстрее, без файлов)
    try {
      if (VibeMessageCache.instance.isReady) {
        final cached = VibeMessageCache.instance.getChats();
        if (cached != null) {
          return cached.map((m) => _chatFromCacheRow(m)).toList();
        }
      }
    } catch (_) {}
    return VibeBackend.instance.getOfflineChats();
  }

  Future<List<VibeChat>> listChats() => VibeBackend.instance.listChats();

  Future<VibeChat?> chatById(String id) => VibeBackend.instance.chatById(id);

  Future<String> ensureSavedChat() => VibeBackend.instance.ensureSavedChat();

  // ── локальные мапперы (копия из backend для независимости) ──────────
  VibeChat _chatFromCacheRow(Map<String, dynamic> m) {
    return VibeChat(
      id: m['id'] ?? '',
      title: m['title'] ?? '',
      kind: m['kind'] ?? 'pm',
      lastMessage: m['lastMessage'] ?? '',
      lastTime: m['lastTime'] ?? '',
      unread: m['unread'] ?? 0,
      peerName: m['peerName'] as String?,
      peerAvatar: m['peerAvatar'] as String?,
      peerId: m['peerId'] as String?,
      peerOnline: m['peerOnline'] ?? false,
    );
  }
}
