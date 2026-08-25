import 'package:get_it/get_it.dart';

import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/message_repository.dart';

final GetIt getIt = GetIt.instance;

/// DI-контейнер Vibe (Single Writer + Repository).
/// Регистрирует ChatRepository/MessageRepository как singleton'ы.
/// Вызывать в main() до runApp() после Supabase init.
Future<void> setupServiceLocator() async {
  if (!getIt.isRegistered<ChatRepository>()) {
    getIt.registerLazySingleton<ChatRepository>(() => ChatRepository());
  }
  if (!getIt.isRegistered<MessageRepository>()) {
    getIt.registerLazySingleton<MessageRepository>(() => MessageRepository());
  }
}
