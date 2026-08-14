part of 'backend.dart';

/// Media/stories: подпись приватных URL через edge-fn media-sign,
/// лента публичных сториз, публикация/удаление сториз.
mixin MediaBackendMixin {
  /// Кэш подписанных URL: ключ — путь в бакете, значение — URL и срок.
  final _signedUrls = <String, ({String url, DateTime expires})>{};

  /// Резолвер приватных медиа: относительный путь (или старый публичный URL)
  /// превращает в подписанный URL через edge-функцию media-sign.
  ///
  /// Аргумент может быть:
  ///  - путём в бакете: `avatars/…`, `stories/…`, `media/…`, `messages/…`;
  ///  - старым публичным URL `…/storage/v1/object/public/avatars/<path>`;
  ///  - локальным путём файла (приводится как есть).
  Future<String?> mediaUrl(String? source) async {
    if (source == null || source.isEmpty) return null;
    var path = source;
    final publicIdx = source.indexOf('/storage/v1/object/public/avatars/');
    if (publicIdx >= 0) {
      path = source.substring(publicIdx + '/storage/v1/object/public/avatars/'.length);
    }
    final isBucketPath = path.startsWith('avatars/') ||
        path.startsWith('stories/') ||
        path.startsWith('media/') ||
        path.startsWith('messages/');
    if (!isBucketPath) return source;

    final cached = _signedUrls[path];
    if (cached != null && cached.expires.isAfter(DateTime.now())) return cached.url;

    try {
      final res = await VibeBackend.instance._client.functions
          .invoke('media-sign', body: {'bucket': 'avatars', 'path': path});
      final data = res.data;
      final url = data is Map<String, dynamic> ? data['url'] as String? : null;
      if (url != null) {
        _signedUrls[path] = (
          url: url,
          expires: DateTime.now().add(const Duration(minutes: 50)),
        );
        return url;
      }
    } catch (_) {}
    return null;
  }

  /// Лента публичных сториз (чужие; свои клиент показывает локально).
  Future<List<VibeStory>> listStories() async {
    final myId = VibeBackend.instance.myProfileId;
    if (myId == null) return [];
    final res = await VibeBackend.instance._client
        .from('stories')
        .select('*, author:profiles(display_name)')
        .neq('profile_id', myId)
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List)
        .map((row) => VibeStory.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Публикация стори: фото в storage + запись в stories.
  Future<void> uploadStory(Uint8List bytes) async {
    if (VibeBackend.instance.myProfileId == null) return;
    final path =
        'stories/$VibeBackend.instance.myProfileId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await VibeBackend.instance._client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        upsert: false,
        contentType: 'image/jpeg',
      ),
    );
    await VibeBackend.instance._client.from('stories').insert({
      'profile_id': VibeBackend.instance.myProfileId,
      'photo_url': path,
    });

    // Мгновенно обновляем карусель у всех: появилась новая история.
    unawaited(VibeBackend.instance._dmChannel?.sendBroadcastMessage(
      event: 'new_story',
      payload: {'profile_id': VibeBackend.instance.myProfileId},
    ));
  }

  /// Удаление своей стори.
  Future<void> deleteStory(String storyId) async {
    if (VibeBackend.instance.myProfileId == null) return;
    await VibeBackend.instance._client.from('stories').delete().eq('id', storyId);
  }
}
