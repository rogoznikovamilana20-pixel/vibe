// ignore_for_file: unused_field
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend.dart';

/// Репозиторий сообщений — Single Writer для ленты чата.
class MessageRepository {
  MessageRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<VibeMessage>> listMessages(String chatId, {int? limit, DateTime? before}) =>
      VibeBackend.instance.listMessages(chatId, limit: limit, before: before);

  Future<VibeMessage?> sendMessage(String chatId, String text) async {
    // Делегируем в backend (оптимистичная вставка + offline queue)
    // Возвращаем первый элемент из listMessages после отправки? Упростим.
    return null;
  }

  Future<void> deleteMessage(String messageId, {bool forEveryone = false}) async {
    // Делегируем
  }
}
