import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/backend.dart';
import '../data/backend_api.dart';
import '../data/settings_service.dart';

/// Владелец data-plane списка чатов: лента чатов, кэш/сеть, realtime-подписки,
/// статусы (закреп/архив/DND/скрытые/прочитано) и выделение.
/// Экран (`ChatListScreen`) только отображает состояние и собирает ввод.
///
/// Single Writer: все мутации `chats` и статусных множеств — только здесь
/// (см. docs/vibe/STATE_MACHINE.md).
class ChatListController extends ChangeNotifier {
  ChatListController({
    required this.onSnack,
    this.onReloadStories,
    VibeBackendApi? backend,
  }) : backend = backend ?? LiveVibeBackend();

  /// Snack-сообщения (экран решает, как показать).
  final void Function(String message) onSnack;

  /// Подгрузка сториз после событий чата (лента сториз живёт на экране).
  final Future<void> Function()? onReloadStories;

  /// Данные: живой бэкенд по умолчанию, фейк в unit-тестах.
  final VibeBackendApi backend;

  // ─── Лента ───
  late List<VibeChat> chats = [];

  // ─── Статусы ───
  final Set<String> selected = {};
  bool get selectionMode => selected.isNotEmpty;
  final Set<String> archived = {};
  final Set<String> dnd = {};
  final Set<String> hidden = {};
  final Set<String> read = {};
  final Set<String> pinned = {};

  /// 8.3.2: чаты, удалённые для себя на этом устройстве (в ленте не видны).
  final Set<String> deleted = {};

  // ─── Подписки ───
  StreamSubscription<dynamic>? _streamSub;
  StreamSubscription<dynamic>? _chatSub;
  Timer? _reloadTimer;
  Timer? _ticker;
  bool _disposed = false;

  /// 5.1: время последнего realtime-события — тикер перезагружает ленту
  /// только при «заснувшем» websocket (офлайн/фокус).
  DateTime _lastRealtimeEvent = DateTime.fromMillisecondsSinceEpoch(0);

  /// Тикер-пульс: перезагрузка, только если realtime молчит > 20 секунд.
  void _pulse() {
    if (DateTime.now().difference(_lastRealtimeEvent) >=
        const Duration(seconds: 20)) {
      scheduleReload();
    }
  }

  /// 5.8: дельта-обновление ленты — полная замена только при реальных
  /// изменениях (новый/выбывший чат, сдвиг порядка, смена превью/статусов).
  /// Идентичная копия (одинаковые id, превью, онлайн-статусы) не вызывает
  /// пересборку списка.
  void _mergeChats(List<VibeChat> fresh) {
    fresh.removeWhere((c) => deleted.contains(c.id));
    if (_sameChats(chats, fresh)) return;
    chats = fresh;
    notifyListeners();
  }

  static bool _sameChats(List<VibeChat> a, List<VibeChat> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id ||
          x.title != y.title ||
          x.kind != y.kind ||
          x.lastMessage != y.lastMessage ||
          x.lastTime != y.lastTime ||
          x.unread != y.unread ||
          x.peerName != y.peerName ||
          x.peerAvatar != y.peerAvatar ||
          x.peerId != y.peerId ||
          x.peerOnline != y.peerOnline ||
          x.peerLastSeen != y.peerLastSeen) {
        return false;
      }
    }
    return true;
  }

  /// Старт: локальные статусы + слушатели + realtime + первая загрузка.
  Future<void> load() async {
    pinned.addAll(SettingsService.instance.pinnedChats);
    dnd
      ..addAll(SettingsService.instance.mutedChats)
      ..addAll(backend.mutedNotifier.value);
    archived.addAll(backend.archivedNotifier.value);
    hidden.addAll(SettingsService.instance.hiddenChats);
    deleted.addAll(SettingsService.instance.deletedChats);

    SettingsService.instance.mutedVersion.addListener(syncMuted);
    SettingsService.instance.blockedVersion.addListener(syncBlocked);
    SettingsService.instance.hiddenVersion.addListener(syncHidden);
    SettingsService.instance.deletedVersion.addListener(syncDeleted);
    backend.archivedNotifier.addListener(syncCloudArchive);
    backend.mutedNotifier.addListener(syncCloudMuted);
    backend.presenceVersion.addListener(onPresenceChanged);

    // 5.1: realtime-пульс. Периодическая перезагрузка — только если
    // websocket «заснул» (нет realtime-событий дольше 20 секунд).
    _lastRealtimeEvent = DateTime.now();
    _ticker = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _pulse(),
    );

    _streamSub = backend.stream.listen((msg) {
      // Мгновенная подмена превью последнего сообщения (как в TG) и
      // фоновая перезагрузка списка при паузах.
      _lastRealtimeEvent = DateTime.now();
      applyLivePreview(msg);
      scheduleReload();
    });
    _chatSub = backend.chatEvents.listen((_) {
      _lastRealtimeEvent = DateTime.now();
      scheduleReload();
    });

    await loadChats();
  }

  void syncMuted() {
    if (_disposed) return;
    final muted = SettingsService.instance.mutedChats.toSet();
    if (muted.length != dnd.length || muted.difference(dnd).isNotEmpty) {
      dnd
        ..clear()
        ..addAll(muted);
      notifyListeners();
    }
  }

  /// Синхронизация скрытых чатов (другой экран скрыл/показал).
  void syncHidden() {
    if (_disposed) return;
    final hiddenNow = SettingsService.instance.hiddenChats.toSet();
    if (hiddenNow.length != hidden.length || hiddenNow.difference(hidden).isNotEmpty) {
      hidden
        ..clear()
        ..addAll(hiddenNow);
      notifyListeners();
    }
  }

  /// 8.3.2: чат удалён для себя из меню чата — убираем его из ленты.
  void syncDeleted() {
    if (_disposed) return;
    final deletedNow = SettingsService.instance.deletedChats.toSet();
    if (deletedNow.length == deleted.length &&
        deletedNow.difference(deleted).isEmpty) {
      return;
    }
    deleted
      ..clear()
      ..addAll(deletedNow);
    chats.removeWhere((c) => deleted.contains(c.id));
    notifyListeners();
  }

  /// Синхронизация архива (удалённые с сервера / изменения) для локального списка.
  void syncCloudArchive() {
    if (_disposed) return;
    final cloud = backend.archivedNotifier.value;
    if (cloud.length != archived.length || cloud.difference(archived).isNotEmpty) {
      archived
        ..clear()
        ..addAll(cloud);
      notifyListeners();
    }
  }

  /// Синхронизация DND (удалённые с сервера / изменения) для локального списка.
  void syncCloudMuted() {
    if (_disposed) return;
    final cloud = backend.mutedNotifier.value;
    if (cloud.length != dnd.length || cloud.difference(dnd).isNotEmpty) {
      dnd
        ..clear()
        ..addAll(cloud);
      notifyListeners();
      SettingsService.instance.setMutedChats(dnd.toList());
    }
  }

  /// Обновление после изменения списка заблокированных пользователей.
  void syncBlocked() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Троттлинг presence-перезагрузок (5.2): при шквале событий онлайн-
  /// статусов (пачкой меняется несколько контактов) полный `listChats`
  /// выполняется не чаще раза в [_presenceInterval]; хвостовые события
  /// сливаются в один отложенный перезапрос.
  static const _presenceInterval = Duration(seconds: 2);
  Timer? _presenceTimer;
  DateTime? _lastPresenceReload;

  Future<void> onPresenceChanged() async {
    if (_disposed) return;
    final last = _lastPresenceReload;
    if (last != null &&
        DateTime.now().difference(last) < _presenceInterval) {
      _presenceTimer?.cancel();
      _presenceTimer = Timer(_presenceInterval, () => _reloadFromPresence());
      return;
    }
    await _reloadFromPresence();
  }

  Future<void> _reloadFromPresence() async {
    if (_disposed) return;
    _presenceTimer?.cancel();
    _lastPresenceReload = DateTime.now();
    final fresh = await backend.listChats();
    if (_disposed) return;
    _mergeChats(fresh);
  }

  void scheduleReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 400), () {
      loadChats();
      onReloadStories?.call();
    });
  }

  Future<void> loadChats() async {
    // 1. Сначала кэш (мгновенно, как в Telegram) — при первом входе,
    //    чтобы не было пустого экрана при плохой сети.
    if (chats.isEmpty) {
      final cached = await backend.getOfflineChats();
      cached.removeWhere((c) => deleted.contains(c.id));
      if (cached.isNotEmpty && !_disposed) {
        chats = cached;
        notifyListeners();
      }
    }

    // 2. Затем свежие данные с сервера.
    try {
      final fresh = await backend.listChats();
      if (_disposed) return;
      _mergeChats(fresh);
    } catch (_) {
      // Сеть недоступна — остаёмся на кэше.
    }
  }

  /// Превью-текст последнего сообщения по его типу (как в TG).
  String _previewOf(VibeMessage msg) {
    if (msg.text != null && msg.text!.isNotEmpty) return msg.text!;
    if (msg.photoPath != null ||
        msg.voicePath != null ||
        msg.videoPath != null) {
      return msg.photoPath != null
          ? 'Медиа'
          : msg.voicePath != null
          ? 'Голосовое'
          : 'Видеокружок';
    }
    return 'Медиа';
  }

  /// Мгновенная подмена превью последнего сообщения в тайле чата.
  void applyLivePreview(VibeMessage msg) {
    final i = chats.indexWhere((c) => c.id == msg.chatId);
    if (i < 0 || _disposed) return;
    final old = chats[i];
    final updated = VibeChat(
      id: old.id,
      title: old.title,
      kind: old.kind,
      lastMessage: _previewOf(msg),
      lastTime: backend.formatTime(msg.created.toIso8601String()),
      unread: old.unread,
      peerName: old.peerName,
      peerAvatar: old.peerAvatar,
      peerId: old.peerId,
      peerOnline: old.peerOnline,
    );
    chats.removeAt(i);
    chats.insert(0, updated);
    notifyListeners();
  }

  /// Непрочитанное с учётом локальной пометки «прочитано».
  int unreadOf(VibeChat chat) {
    if (read.contains(chat.id)) return 0;
    return chat.unread;
  }

  // ─── Действия ───

  /// Пометить выделенные чаты прочитанными.
  void markRead() {
    read.addAll(selected);
    selected.clear();
    notifyListeners();
    onSnack('Прочитано');
  }

  /// Пометить выделенные чаты (убрать из основного списка).
  void markArchived() {
    archived.addAll(selected);
    selected.clear();
    for (final id in archived) {
      backend.setChatArchived(id, archived: true);
    }
    notifyListeners();
    onSnack('В архив: ${archived.length}');
  }

  /// Спрятать выделенные чаты (в скрытую папку, защищённую пасскодом).
  void markHidden() {
    hidden.addAll(selected);
    selected.clear();
    _persistHidden();
    notifyListeners();
    onSnack('Скрыто: ${hidden.length}');
  }

  /// Скрыть/показать один чат (из меню чата).
  void setHidden(String id, {required bool hiddenNow}) {
    if (hiddenNow) {
      hidden.add(id);
    } else {
      hidden.remove(id);
    }
    _persistHidden();
    notifyListeners();
  }

  void _persistHidden() {
    SettingsService.instance.setHiddenChats(hidden.toList());
  }

  void togglePin(String id) {
    if (pinned.contains(id)) {
      pinned.remove(id);
    } else {
      pinned.add(id);
    }
    SettingsService.instance.setPinnedChats(pinned.toList());
    notifyListeners();
  }

  void toggleSelect(String id) {
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      selected.add(id);
    }
    notifyListeners();
  }

  void setMuted(String id, {required bool muted}) {
    if (muted) {
      dnd.add(id);
    } else {
      dnd.remove(id);
    }
    SettingsService.instance.setMutedChats(dnd.toList());
    backend.setChatMuted(id, muted: muted);
    notifyListeners();
  }

  void setArchived(String id, {required bool archivedNow}) {
    if (archivedNow) {
      archived.add(id);
    } else {
      archived.remove(id);
    }
    backend.setChatArchived(id, archived: archivedNow);
    notifyListeners();
  }

  /// Отметить чат прочитанным (из меню чата).
  void markChatRead(String id) {
    read.add(id);
    notifyListeners();
  }

  /// Свайп влево: переключить «не беспокоить».
  void toggleDnd(String id) {
    setMuted(id, muted: !dnd.contains(id));
  }

  /// Свайп вправо: переключить архив.
  void toggleArchived(String id) {
    setArchived(id, archivedNow: !archived.contains(id));
  }

  /// Удалить выделенные чаты из локального списка.
  void removeSelected() {
    chats.removeWhere((c) => selected.contains(c.id));
    selected.clear();
    notifyListeners();
    onSnack('Удалено');
  }

  void clearSelection() {
    selected.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _streamSub?.cancel();
    _chatSub?.cancel();
    SettingsService.instance.mutedVersion.removeListener(syncMuted);
    SettingsService.instance.blockedVersion.removeListener(syncBlocked);
    SettingsService.instance.hiddenVersion.removeListener(syncHidden);
    SettingsService.instance.deletedVersion.removeListener(syncDeleted);
    backend.archivedNotifier.removeListener(syncCloudArchive);
    backend.mutedNotifier.removeListener(syncCloudMuted);
    backend.presenceVersion.removeListener(onPresenceChanged);
    _reloadTimer?.cancel();
    _ticker?.cancel();
    _presenceTimer?.cancel();
    super.dispose();
  }
}
