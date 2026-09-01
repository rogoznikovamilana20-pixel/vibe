// PR1 facade: messages — отправка, статусы, realtime.
// Пока thin wrapper, далее вынести MsgStatus lifecycle (sending→sent→delivered→read) из backend.dart.
import '../backend.dart';
import '../backend_api.dart';

class MessageRepository {
  const MessageRepository(this._api);
  final VibeBackendApi _api;

  Future<List<VibeMessage>> listMessages(String chatId) async {
    if (_api is LiveVibeBackend) {
      // ignore: avoid_dynamic_calls
      return await (_api as dynamic).listMessages(chatId) as List<VibeMessage>;
    }
    return [];
  }

  Future<void> send(String chatId, String text) async {
    if (_api is LiveVibeBackend) {
      // ignore: avoid_dynamic_calls
      await (_api as dynamic).sendMessage(chatId, text);
    }
  }
}
