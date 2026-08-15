part of 'backend.dart';

/// Профиль, директория (контакты/поиск), приватность, присутствие, сессия.
/// Выделено из монолита backend.dart (Фаза А) без изменения публичного API.
/// Хостовое состояние берётся через синглтон VibeBackend.instance
/// (private-доступ в рамках одной library).
mixin ProfileBackendMixin {
  Future<bool> isUsernameAvailable(String username) async {
    final clean = username.toLowerCase().trim();
    if (clean.length < 3) return false;
    final res = await VibeBackend.instance._client
        .from('profiles')
        .select('id')
        .eq('username', clean)
        .neq('id', VibeBackend.instance.myProfileId ?? '')
        .maybeSingle();
    return res == null;
  }

  /// 3.7: облачное зеркало настроек приватности (best-effort; клиент
  /// держит локальный кеш и деградирует при недоступности сервера).
  Future<PrivacySettings?> fetchPrivacy() async {
    if (VibeBackend.instance.myProfileId == null) return null;
    try {
      final row = await VibeBackend.instance._client
          .from('profile_privacy')
          .select()
          .eq('user_id', VibeBackend.instance.myProfileId!)
          .maybeSingle();
      if (row == null) return null;
      return PrivacySettings.fromMap(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePrivacy(PrivacySettings settings) async {
    if (VibeBackend.instance.myProfileId == null) return;
    await VibeBackend.instance._client.from('profile_privacy').upsert({
      'user_id': VibeBackend.instance.myProfileId,
      ...settings.toMap(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  /// Мои контакты: только те, с кем у меня уже есть личные чаты.
  /// Никаких глобальных списков — чужие профили (и телефоны) наружу
  /// не попадают.
  Future<List<VibeProfile>> listContacts() async {
    if (VibeBackend.instance.myProfileId == null) return [];
    try {
      final res = await VibeBackend.instance._client
          .from('chats')
          .select('members')
          .eq('kind', 'pm')
          .contains('members', [VibeBackend.instance.myProfileId])
          .limit(200);
      final peerIds = <String>{};
      for (final c in res) {
        final members = List<String>.from(c['members']);
        for (final m in members) {
          if (m != VibeBackend.instance.myProfileId) peerIds.add(m);
        }
      }
      final contacts = <VibeProfile>[];
      for (final id in peerIds) {
        final p = await profileById(id);
        if (p != null) contacts.add(p.copyWithPrivacySafe());
      }
      return contacts;
    } catch (_) {
      return [];
    }
  }

  /// Поиск людей по нику/имени по всей базе — как глобальный поиск
  /// в Telegram: без номеров телефонов в результатах.
  Future<List<VibeProfile>> searchUsers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final res = await VibeBackend.instance._client
        .from('profiles')
        .select('id,username,display_name,emoji,avatar_url,bio,uid')
        .or('username.ilike.%$q%,display_name.ilike.%$q%')
        .limit(20);

    return (res as List)
        .map((e) => VibeProfile.fromJson(e).copyWithPrivacySafe())
        .toList();
  }

  final _profileCache = <String, _CachedProfile>{};

  Future<VibeProfile?> profileById(String id) async {
    final hit = _profileCache[id];
    if (hit != null && hit.expiresAt.isAfter(DateTime.now())) {
      return hit.profile;
    }
    try {
      final p = await VibeBackend.instance._client
          .from('profiles')
          .select('id,username,display_name,emoji,avatar_url,bio,online,uid')
          .eq('id', id)
          .single();
      final profile = VibeProfile.fromJson(p);
      _profileCache[id] = _CachedProfile(
        profile,
        DateTime.now().add(const Duration(minutes: 5)),
      );
      return profile;
    } catch (_) {
      return null;
    }
  }

Future<void> setMyProfile(VibeProfile p) async {
    VibeBackend.instance._myProfile = p;
    VibeBackend.instance.myProfileId = p.id;
    VibeBackend.myProfileNotifier.value = p;
    await VibeBackend._saveLocalProfile(p);
    await VibeBackend.saveMyId(p.id);
    // Личный realtime-канал пересоздаётся под новый аккаунт.
    VibeBackend.instance._ensurePersonalChannel();
    // Присутствие: отмечаемся онлайн при входе и слушаем чужие статусы.
    startPresence();
  }

  // ==== Онлайн-статусы (как в Telegram: точка «в сети» только у тех,
  // кто реально в сети) ====
  //
  // Свой статус держим честным: включаем при входе/возобновлении,
  // выключаем при сворачивании, heartbeat обновляет каждую минуту.
  // Чужие статусы прилетают через realtime на таблицу profiles.

  Timer? _presenceTimer;
  RealtimeChannel? _presenceChannel;

  /// Сигнал об изменении чужого статуса онлайна (для живых точек).
  final ValueNotifier<int> presenceVersion = ValueNotifier<int>(0);

  void startPresence() {
    final id = VibeBackend.instance.myProfileId;
    if (id == null) return;
    unawaited(_writeOnline(id, true));
    _presenceTimer ??= Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        final me = VibeBackend.instance.myProfileId;
        if (me != null) unawaited(_writeOnline(me, true));
      },
    );
    _subscribePresence();
  }

  /// Включить/выключить собственный статус «в сети»
  /// (сворачивание приложения, выход из чата на рабочий стол и т.п.).
  Future<void> setOnline(bool value) async {
    final id = VibeBackend.instance.myProfileId;
    if (id == null) return;
    await _writeOnline(id, value);
  }

  Future<void> _writeOnline(String id, bool value) async {
    try {
      // Время последнего входа пишем заодно со статусом «в сети»:
      // по нему показываем «был(а) в сети …», когда человек офлайн.
      await VibeBackend.instance._client.from('profiles').update({
        'online': value,
      }).eq('id', id);
    } catch (_) {
      // Оффлайн/права — статус просто не обновится, ничего не ломаем.
    }
  }

  void _subscribePresence() {
    if (_presenceChannel != null) return;
    _presenceChannel = VibeBackend.instance._client
        .channel('presence')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            final data = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            final id = data['id'] as String?;
            if (id == null) return;
            // Сбрасываем кеш профиля — next read возьмёт свежий статус.
            _profileCache.remove(id);
            presenceVersion.value++;
          },
        )
        .subscribe();
  }

  Future<void> logout() async {
    final id = VibeBackend.instance.myProfileId;
    if (id != null) unawaited(_writeOnline(id, false));

    // Stop presence timer & channel.
    _presenceTimer?.cancel();
    _presenceTimer = null;
    final pch = _presenceChannel;
    if (pch != null) {
      try {
        VibeBackend.instance._client.removeChannel(pch);
      } catch (_) {}
    }
    _presenceChannel = null;

    // Stop network monitor (health timer + connectivity subscription).
    VibeBackend.instance.stopNetworkMonitor();

    await VibeBackend.instance._client.auth.signOut();

    // Unsubscribe personal channel.
    final old = VibeBackend.instance._personal;
    if (old != null) {
      VibeBackend.instance._client.removeChannel(old);
    }
    VibeBackend.instance._personal = null;
    VibeBackend.instance._personalName = null;

    // Unsubscribe DM channel.
    final dm = VibeBackend.instance._dmChannel;
    if (dm != null) {
      VibeBackend.instance._client.removeChannel(dm);
    }
    VibeBackend.instance._dmChannel = null;

    // Unsubscribe postgres_changes channels.
    for (final ch in VibeBackend.instance._postgresChannels) {
      try {
        VibeBackend.instance._client.removeChannel(ch);
      } catch (_) {}
    }
    VibeBackend.instance._postgresChannels.clear();

    // Clear E2E keys (private from SecureStorage, public from DB).
    await E2eService.instance.deleteKeys();

    // Clear auth state.
    VibeBackend.instance._myProfile = null;
    VibeBackend.instance.myProfileId = null;
    VibeBackend.myProfileNotifier.value = null;

    // Clear in-memory caches to prevent data leaking between accounts.
    VibeBackend.instance._peers.clear();
    VibeBackend.instance._seenIds.clear();
    VibeBackend.instance._sentById.clear();
    VibeBackend.instance._sentByIdTime.clear();
    VibeBackend.instance._unreadByChat.clear();
    VibeBackend._cachedProfile = null;

    // Close event bus to prevent orphaned callbacks firing after logout.
    if (!VibeBackend.instance._chatsController.isClosed) {
      VibeBackend.instance._chatsController.close();
    }

    // Очистить очередь офлайн-отправки.
    final qAccountId = id ?? '';
    if (qAccountId.isNotEmpty) {
      await OfflineQueueService.instance.clear(qAccountId);
    }

    // Delete session file.
    final dir = await getApplicationDocumentsDirectory();
    final f1 = File('${dir.path}${Platform.pathSeparator}session.json');
    if (await f1.exists()) await f1.delete();
  }
}
