// PR1 facade: chats — лента, пины, архив, скрытые.
// Thin wrapper над ChatListController/VibeBackend, чтобы chat_list_screen не зависел от backend напрямую.
import '../backend.dart';
import '../backend_api.dart';

class ChatRepository {
  const ChatRepository(this._api);
  final VibeBackendApi _api;

  Future<List<VibeChat>> listChats() async {
    // Пока делегируем к VibeBackend — реальный split будет выносить SQL/Realtime из backend.dart
    if (_api is LiveVibeBackend) {
      // ignore: avoid_dynamic_calls
      return await (_api as dynamic).listChats() as List<VibeChat>;
    }
    return [];
  }

  Future<VibeChat?> chatById(String id) => _api.chatById(id);
}
