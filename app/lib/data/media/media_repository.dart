// PR1 facade: media — подписанные URL, сториз.
// Исправлен bucket-баг в media_backend.dart (bucket = path.split). Здесь — интерфейс для изоляции.
import '../backend.dart';
import '../backend_api.dart';

class MediaRepository {
  const MediaRepository(this._api);
  final VibeBackendApi _api;

  Future<String?> mediaUrl(String? source) async {
    if (_api is LiveVibeBackend) {
      // ignore: avoid_dynamic_calls
      return await (_api as dynamic).mediaUrl(source) as String?;
    }
    return null;
  }

  Future<List<VibeStory>> listStories() async {
    if (_api is LiveVibeBackend) {
      // ignore: avoid_dynamic_calls
      return await (_api as dynamic).listStories() as List<VibeStory>;
    }
    return [];
  }
}
