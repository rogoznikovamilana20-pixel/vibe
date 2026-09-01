// PR1 facade: auth — делегат к VibeBackend, без дублирования логики.
// Цель: изолировать 80 .from() и 3 .rpc() за интерфейсом VibeBackendApi,
// чтобы UI зависел от абстракции, а не от монолита 140KB.
// Пока — thin wrapper, следующим шагом вынести реальную логику из backend.dart части profile_backend.
import '../backend.dart';
import '../backend_api.dart';

class AuthService {
  const AuthService(this._api);
  final VibeBackendApi _api;

  String? get myProfileId => _api.myProfileId;

  Future<VibeProfile?> get myProfile async {
    final id = myProfileId;
    if (id == null) return null;
    return _api is LiveVibeBackend ? await ( _api as dynamic).fetchMyProfile?.call() : null;
  }

  // Делегируем к существующему LiveVibeBackend — не дублируем RPC.
  Future<String> ensurePmChat(String peerId) => _api.ensurePmChat(peerId);
}
