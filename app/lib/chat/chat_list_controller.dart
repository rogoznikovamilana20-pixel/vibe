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

  // ─── Подписки ───
  StreamSubscription<dynamic>? _streamSub;
  StreamSubscription<dynamic>? _chatSub;
  Timer? _reloadTimer;
  Timer? _ticker;
  bool _disposed = false;

  /// Старт: локальные статусы + слушатели + realtime + первая загрузка.
  Future<void> load() async {
    pinned.addAll(SettingsService.instance.pinnedChats);
    dnd
      ..addAll(SettingsService.instance.mutedChats)
      ..addAll(backend.mutedNotifier.value);
    archived.addAll(backend.archivedNotifier.value);

    SettingsService.instance.mutedVersion.addListener(syncMuted);
    SettingsService.instance.blockedVersion.addListener(syncBlocked);
    backend.archivedNotifier.addListener(syncCloudArchive);
    backend.mutedNotifier.addListener(syncCloudMuted);
    backend.presenceVersion.addListener(onPresenceChanged);

    // Периодическая перезагрузка, если websocket «заснул» (офлайн/фокус).
    _ticker = Timer.periodic(
      const Duration(seconds: 20),
      (_) => scheduleReload(),
    );

    _streamSub = backend.stream.listen((msg) {
      // Мгновенная подмена превью последнего сообщения (как в TG) и
      // фоновая перезагрузка списка при паузах.
      applyLivePreview(msg);
      scheduleReload();
    });
    _chatSub = backend.chatEvents.listen((_) => scheduleReload());

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

  Future<void> onPresenceChanged() async {
    if (_disposed) return;
    final fresh = await backend.listChats();
    if (_disposed) return;
    chats = fresh;
    notifyListeners();
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
      if (cached.isNotEmpty && !_disposed) {
        chats = cached;
        notifyListeners();
      }
    }

    // 2. Затем свежие данные с сервера.
    try {
      final fresh = await backend.listChats();
      if (_disposed) return;
      chats = fresh;
      notifyListeners();
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

  /// Спрятать выделенные чаты (в HMS-список).
  void markHidden() {
    hidden.addAll(selected);
    selected.clear();
    notifyListeners();
    onSnack('Скрыто: ${hidden.length}');
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
    backend.archivedNotifier.removeListener(syncCloudArchive);
    backend.mutedNotifier.removeListener(syncCloudMuted);
    backend.presenceVersion.removeListener(onPresenceChanged);
    _reloadTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}
