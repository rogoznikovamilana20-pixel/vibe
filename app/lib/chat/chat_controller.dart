import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/backend.dart';
import '../data/backend_api.dart';
import '../data/settings_service.dart';
import 'models.dart';

/// Владелец data-plane чата: лента сообщений, пагинация, realtime-подписки,
/// статусы (отправка/правка/реакции), typing и все команды над лентой.
/// Экран (`ChatScreen`) только отображает состояние и собирает ввод.
///
/// Single Writer: все мутации списка `messages` происходят только здесь,
/// экран читает `messages` без изменений (см. docs/vibe/STATE_MACHINE.md).
class ChatController extends ChangeNotifier {
  ChatController({
    required this.chatId,
    required this.chatTitle,
    required this.onError,
    this.initialUnread = 0,
    VibeBackendApi? backend,
  }) : backend = backend ?? LiveVibeBackend();

  final String chatId;
  final String chatTitle;

  /// Ошибка операции (snack на экране решает, как показать).
  final void Function(String message) onError;

  /// Данные: живой бэкенд по умолчанию, фейк в unit-тестах.
  final VibeBackendApi backend;

  /// Непрочитанные на момент входа в чат (из карточки чата) — для
  /// плашки «N непрочитанных» и прыжка к первому (как в Telegram).
  final int initialUnread;

  // ─── Лента ───
  /// Сообщения в reverse-порядке: index 0 — самое новое (низ экрана).
  final List<ChatMsg> messages = [];

  /// Фильтрация сообщений от заблокированных пользователей.
  List<ChatMsg> get visibleMessages {
    // ChatMsg doesn't have senderId, so return all messages for now.
    // Full blocked user filtering requires sender identification in the model.
    return messages;
  }

  static const int _pageSize = 80;
  bool _loadingOlder = false;
  bool _hasMoreOlder = true;
  bool _initialLoadDone = false;

  bool get loadingOlder => _loadingOlder;
  bool get hasMoreOlder => _hasMoreOlder;

  // ─── Статусы интерфейса ───
  bool atBottom = true;
  int newIncoming = 0;
  int? editingIdx;
  int? replyTo;
  String? pinFlashId;
  String? groupTitle;
  bool peerTyping = false;

  // ─── Multi-select (V4.1) ───
  bool get selectionMode => _selectedMsgIds.isNotEmpty;
  final Set<String> _selectedMsgIds = {};
  Set<String> get selectedMsgIds => Set.unmodifiable(_selectedMsgIds);

  void toggleSelect(String msgId) {
    if (_selectedMsgIds.contains(msgId)) {
      _selectedMsgIds.remove(msgId);
    } else {
      _selectedMsgIds.add(msgId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedMsgIds.clear();
    notifyListeners();
  }

  void selectAll() {
    for (final msg in messages) {
      final id = msg.serverId;
      if (id != null) _selectedMsgIds.add(id);
    }
    notifyListeners();
  }

  List<ChatMsg> get selectedMessages =>
      messages.where((m) => _selectedMsgIds.contains(m.serverId)).toList();

  // ─── Черновик (как в Telegram: сохраняется локально) ───
  String draft = '';

  // ─── Закреплённые сообщения (множественные, облако) ───
  /// serverId закреплённых сообщений, новые сверху.
  List<String> pins = [];

  /// Верхний закреп (для меню/бейджа «Открепить»).
  String? get pinMsgId => pins.isEmpty ? null : pins.first;

  /// Локальные изменения списка закрепов не перетираются ответом облака.
  bool _pinsTouchedLocally = false;

  // ─── Unread-jump: плашка «N непрочитанных» + подсветка первого ───
  /// Индекс первого непрочитанного в ленте (reverse: 0 = низ).
  /// `null` — плашка скрыта (прыгнули или непрочитанных нет).
  int? unreadJumpIndex;
  String? unreadFlashId;

  // ─── Realtime-подписки ───
  StreamSubscription<VibeMessage>? _sub;
  StreamSubscription<VibeMsgEvent>? _msgEventsSub;
  StreamSubscription<PinChanged>? _pinSub;
  StreamSubscription<String>? _typingSub;
  Timer? _typingReset;
  Timer? _pinTimer;
  Timer? _draftTimer;
  Timer? _unreadTimer;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  /// Начальная загрузка: подписки + первая страница + отметка прочитано.
  Future<void> load() async {
    pins = List.of(SettingsService.instance.pinnedMessageIds(chatId));
    draft = SettingsService.instance.draftFor(chatId) ?? '';
    backend.markChatRead(chatId);
    _subscribe();
    await loadMessages();
    unawaited(_refreshPinsFromServer());
  }

  Future<void> loadMessages() async {
    if (_initialLoadDone) return;
    try {
      final list = await backend.listMessages(
        chatId,
        limit: _pageSize,
      );
      if (_disposed) return;
      messages
        ..clear()
        ..addAll(list.map(_toMsg));
      _initialLoadDone = true;
      _computeUnreadJump();
      notifyListeners();
      backend.refreshChatReactions(chatId);
    } catch (e, st) {
      debugPrint('[ChatController] loadMessages error: $e\n$st');
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> loadOlderIfNeeded() async {
    if (_loadingOlder || !_hasMoreOlder || messages.isEmpty) return;
    final oldest = messages.last.date;
    _loadingOlder = true;
    notifyListeners();
    try {
      final older = await backend.listMessages(
        chatId,
        limit: _pageSize,
        before: oldest,
      );
      if (_disposed) return;
      _loadingOlder = false;
      if (older.length < _pageSize) _hasMoreOlder = false;
      if (older.isNotEmpty) messages.addAll(older.map(_toMsg));
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      _loadingOlder = false;
      notifyListeners();
    }
  }

  /// Свёртка цепочек (3.10): окно группы — 7 минут.
  static const Duration groupWindow = Duration(minutes: 7);

  /// Два соседних сообщения образуют одну группу (свёртку), если они
  /// от одного автора (incoming) и разница времени <= [groupWindow].
  static bool inSameGroup(ChatMsg a, ChatMsg b) {
    final da = a.date;
    final db = b.date;
    if (da == null || db == null) return false;
    return a.incoming == b.incoming &&
        db.difference(da).abs() <= groupWindow;
  }

  /// Первое (самое старое) сообщение своей группы в списке `messages`.
  static bool isFirstInGroup(List<ChatMsg> messages, int i) =>
      i == messages.length - 1 ||
      !inSameGroup(messages[i], messages[i + 1]);

  /// Последнее (самое новое, нижнее) сообщение своей группы.
  static bool isLastInGroup(List<ChatMsg> messages, int i) =>
      i == 0 || !inSameGroup(messages[i], messages[i - 1]);

  /// Экран сообщает о положении скролла (reverse: 0 px — низ чата).
  void onScroll({required bool atBottom}) {
    if (this.atBottom == atBottom && newIncoming == 0) return;
    this.atBottom = atBottom;
    if (atBottom) newIncoming = 0;
    notifyListeners();
  }

  /// Кнопка «вниз»: прыжок к новым сообщениям.
  void jumpToBottom() {
    atBottom = true;
    newIncoming = 0;
    notifyListeners();
  }

  void _subscribe() {
    _sub = backend.stream.listen((msg) {
      if (msg.chatId != chatId || _disposed) return;
      if (msg.localId != null) {
        // Подтверждение своего сообщения (замена по мгновенному ключу):
        // забираем статус, серверный id (для удаления/правки) и эмодзи.
        final i = messages.indexWhere((m) => m.localId == msg.localId);
        if (i >= 0) {
          final sentAttach = AttachmentData.tryParse(msg.text);
          messages[i] = messages[i].copyWith(
            status: msg.status,
            serverId: msg.id,
            stickerEmoji: msg.stickerEmoji ?? messages[i].stickerEmoji,
            attachment: sentAttach ?? messages[i].attachment,
          );
        }
      } else if (msg.incoming) {
        messages.insert(0, _toMsg(msg));
        if (!atBottom) newIncoming++;
      }
      notifyListeners();
    });

    _typingSub = backend.typingEvents.listen((id) {
      if (id != chatId || _disposed) return;
      peerTyping = true;
      _typingReset?.cancel();
      _typingReset = Timer(const Duration(seconds: 4), () {
        if (_disposed) return;
        peerTyping = false;
        notifyListeners();
      });
      notifyListeners();
    });

    _msgEventsSub = backend.msgEvents.listen((ev) {
      if (ev.chatId != chatId || _disposed) return;
      switch (ev.type) {
        case VibeMsgEventType.edited:
          final upd = ev.updated;
          if (upd == null) return;
          final i = messages.indexWhere((m) => m.serverId == ev.messageId);
          if (i < 0) return;
          messages[i] = _copyEditedText(messages[i], upd.text);
        case VibeMsgEventType.deleted:
          final i = messages.indexWhere((m) => m.serverId == ev.messageId);
          if (i >= 0) messages.removeAt(i);
        case VibeMsgEventType.cleared:
          messages.clear();
        case VibeMsgEventType.reactions:
          final reac = ev.reactions;
          if (reac == null) return;
          final i = messages.indexWhere((m) => m.serverId == ev.messageId);
          if (i < 0) return;
          messages[i] = _copyReactions(
            messages[i],
            [for (final e in reac.entries) ChatReaction(e.key, e.value)],
          );
      }
      notifyListeners();
    });

    _pinSub = backend.pinEvents.listen((ev) {
      if (ev.chatId != chatId || _disposed) return;
      _pinsTouchedLocally = true;
      if (ev.pinned) {
        if (pins.any((p) => p == ev.messageId)) return;
        pins.insert(0, ev.messageId);
      } else {
        pins.remove(ev.messageId);
      }
      SettingsService.instance.setPinnedMessageIds(chatId, pins);
      notifyListeners();
    });
  }

  // ─── Typing ───

  /// Отправка «печатает…» не чаще раза в 2.5 секунды (как в Telegram).
  void notifyTyping(String inputText) {
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) < const Duration(milliseconds: 2500)) {
      return;
    }
    if (inputText.trim().isEmpty) return;
    _lastTypingSent = now;
    backend.sendTyping(chatId);
  }

  // ─── Черновик ───

  /// Сохранение черновика с дебаунсом (не пишем в prefs на каждое нажатие).
  void saveDraft(String text) {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), () {
      if (_disposed) return;
      if (text == draft) return;
      draft = text;
      SettingsService.instance.setDraft(chatId, draft.trim().isEmpty ? null : draft);
    });
  }

  /// Черновик отправлен/стёрт — убираем из хранилища.
  void clearDraft() {
    _draftTimer?.cancel();
    draft = '';
    SettingsService.instance.setDraft(chatId, null);
  }

  // ─── Unread-jump ───

  /// Индекс первого непрочитанного (0 = низ). Плашка скрывается, если
  /// непрочитанных нет или первое непрочитанное — уже внизу экрана.
  void _computeUnreadJump() {
    if (initialUnread <= 0 || messages.isEmpty) {
      unreadJumpIndex = null;
      return;
    }
    final idx = (initialUnread - 1).clamp(0, messages.length - 1);
    unreadJumpIndex = idx == 0 ? null : idx;
  }

  /// Прыжок к первому непрочитанному: сообщение временно поднимается к низу
  /// экрана с подсветкой (как в Telegram), через 3 секунды возвращается.
  void jumpToUnread() {
    final i = unreadJumpIndex;
    unreadJumpIndex = null;
    if (i == null || i <= 0 || i >= messages.length) {
      notifyListeners();
      return;
    }
    final msg = messages[i];
    final sameId = msg.localId ?? msg.serverId;
    messages.removeAt(i);
    messages.insert(0, msg);
    unreadFlashId = sameId;
    _unreadTimer?.cancel();
    _unreadTimer = Timer(const Duration(seconds: 3), () {
      if (_disposed) return;
      final j = messages.indexWhere(
        (m) => (m.localId ?? m.serverId) == sameId,
      );
      if (j == 0) {
        messages.removeAt(0);
        messages.insert(i > 0 ? i : 0, msg);
      }
      unreadFlashId = null;
      notifyListeners();
    });
    notifyListeners();
  }

  // ─── Отправка ───

  // ─── Undo-отправки (Telegram: окно 5 секунд после отправки) ───
  static const undoWindow = Duration(seconds: 5);

  /// serverId (или пока localId) последнего отправленного сообщения.
  String? undoMessageId;

  /// Текст для восстановления в композер (только у текстовых).
  String? undoText;

  /// Растёт при восстановлении черновика после «Отменить» (экран
  /// подхватывает текст в поле ввода).
  int draftRestoreVersion = 0;

  Timer? _undoTimer;

  bool get undoAvailable => undoMessageId != null;

  /// Включить окно отмены для отправленного сообщения.
  void _armUndo(String? localId) {
    final i = localId == null
        ? -1
        : messages.indexWhere((m) => m.localId == localId);
    if (i < 0) return;
    final id = messages[i].serverId ?? messages[i].localId;
    if (id == null) return;
    _undoTimer?.cancel();
    undoMessageId = id;
    undoText = (messages[i].type == MsgType.text &&
            messages[i].text.trim().isNotEmpty)
        ? messages[i].text
        : null;
    notifyListeners();
    _undoTimer = Timer(undoWindow, () {
      if (_disposed) return;
      undoMessageId = null;
      undoText = null;
      notifyListeners();
    });
  }

  /// «Отменить отправку»: удаляет сообщение для всех и, если это текст,
  /// возвращает его в поле ввода (как в Telegram).
  Future<void> undoLastSend() async {
    final id = undoMessageId;
    final restoreText = undoText;
    _undoTimer?.cancel();
    undoMessageId = null;
    undoText = null;
    if (id == null) {
      notifyListeners();
      return;
    }
    notifyListeners();

    final i = messages.indexWhere(
      (m) => m.serverId == id || m.localId == id,
    );
    if (i < 0) return;
    final msg = messages[i];
    try {
      final serverId = msg.serverId;
      if (serverId != null) {
        await backend.deleteMessage(serverId);
        if (_disposed) return;
      }
      messages.removeAt(i);
    } catch (_) {
      onError('Не удалось отменить отправку');
      return;
    }
    if (restoreText != null && restoreText.trim().isNotEmpty) {
      draft = restoreText;
      draftRestoreVersion++;
      SettingsService.instance.setDraft(chatId, restoreText);
    }
    notifyListeners();
  }

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final editIdx = editingIdx;
    if (editIdx != null) {
      final msg = messages[editIdx];
      try {
        final updated = await backend.updateMessage(
          msg.serverId!,
          t,
        );
        if (_disposed) return;
        if (updated != null) {
          messages[editIdx] = _copyEditedText(msg, t);
        }
        editingIdx = null;
        replyTo = null;
      } catch (_) {
        onError('Не удалось обновить сообщение');
      }
      notifyListeners();
      return;
    }
    final replyIdx = replyTo;
    final replyText = replyIdx == null ? null : messages[replyIdx].text;
    final replyAuthor = replyIdx == null
        ? null
        : messages[replyIdx].incoming
            ? chatTitle
            : 'Вы';
    final localId = 'c${DateTime.now().microsecondsSinceEpoch}';
    messages.insert(0, ChatMsg(
      type: MsgType.text,
      incoming: false,
      time: _fmtTime(DateTime.now()),
      text: t,
      replyText: replyText,
      replyAuthor: replyAuthor,
      status: MsgStatus.sending,
      localId: localId,
      date: DateTime.now(),
    ));
    replyTo = null;
    notifyListeners();
    try {
      await backend.sendText(
        chatId,
        t,
        localId: localId,
        replyText: replyText,
        replyAuthor: replyAuthor,
      );
      clearDraft();
      _armUndo(localId);
    } catch (_) {
      final i = messages.indexWhere((m) => m.localId == localId);
      if (i >= 0) {
        messages[i] = messages[i].copyWith(status: MsgStatus.failed);
      }
      onError('Не удалось отправить сообщение');
    }
  }

  Future<void> sendSticker(String emoji) async {
    final localId = 's${DateTime.now().microsecondsSinceEpoch}';
    messages.insert(0, ChatMsg(
      type: MsgType.text,
      incoming: false,
      time: _fmtTime(DateTime.now()),
      stickerEmoji: emoji,
      status: MsgStatus.sending,
      localId: localId,
      date: DateTime.now(),
    ));
    notifyListeners();
    try {
      await backend.sendSticker(chatId, emoji, localId: localId);
      _armUndo(localId);
    } catch (_) {
      final i = messages.indexWhere((m) => m.localId == localId);
      if (i >= 0) {
        messages[i] = messages[i].copyWith(status: MsgStatus.failed);
      }
      onError('Не удалось отправить стикер');
    }
  }

  Future<void> sendPhoto(Uint8List bytes) async {
    final localId = 'c${DateTime.now().microsecondsSinceEpoch}';
    try {
      final sent = await backend
          .sendPhoto(chatId, bytes, localId: localId);
      if (_disposed) return;
      messages.insert(0, ChatMsg(
        type: MsgType.photo,
        incoming: false,
        time: _fmtTime(sent.created),
        photoSeed: 0,
        photoUrl: sent.photoPath,
        localId: localId,
        date: sent.created,
      ));
      notifyListeners();
      _armUndo(localId);
    } catch (_) {
      onError('Не удалось отправить фото');
    }
  }

  Future<void> sendVoice({
    required String path,
    required int seconds,
  }) async {
    final localId = 'c${DateTime.now().microsecondsSinceEpoch}';
    messages.insert(0, ChatMsg(
      type: MsgType.voice,
      incoming: false,
      time: _now(),
      voiceSeconds: seconds,
      voicePath: path,
      status: MsgStatus.sending,
      localId: localId,
      date: DateTime.now(),
    ));
    notifyListeners();
    try {
      await backend.sendVoice(
        chatId,
        File(path),
        localId: localId,
        localPath: path,
        voiceSeconds: seconds,
      );
      _armUndo(localId);
    } catch (_) {
      final i = messages.indexWhere((m) => m.localId == localId);
      if (i >= 0) {
        messages[i] = messages[i].copyWith(status: MsgStatus.failed);
      }
      onError('Не удалось отправить голосовое');
    }
  }

  Future<void> sendVideo(File file) async {
    final localId = 'c${DateTime.now().microsecondsSinceEpoch}';
    messages.insert(0, ChatMsg(
      type: MsgType.video,
      incoming: false,
      time: _now(),
      videoPath: file.path,
      status: MsgStatus.sending,
      localId: localId,
      date: DateTime.now(),
    ));
    notifyListeners();
    try {
      await backend
          .sendVideo(chatId, file, localId: localId, localPath: file.path);
      _armUndo(localId);
    } catch (_) {
      final i = messages.indexWhere((m) => m.localId == localId);
      if (i >= 0) {
        messages[i] = messages[i].copyWith(status: MsgStatus.failed);
      }
      onError('Не удалось отправить видеокружок');
    }
  }

  /// Вложение «файл»: мгновенный пузырь без URL, после загрузки
  /// подстановка URL приходит подтверждением сервера.
  Future<void> sendFile(File file) async {
    final name = file.uri.pathSegments.isEmpty
        ? 'file'
        : file.uri.pathSegments.last;
    final localId = 'f${DateTime.now().microsecondsSinceEpoch}';
    messages.insert(0, ChatMsg(
      type: MsgType.file,
      incoming: false,
      time: _now(),
      status: MsgStatus.sending,
      localId: localId,
      date: DateTime.now(),
      attachment: AttachmentData(
        kind: AttachmentKind.file,
        name: name,
        size: file.lengthSync(),
      ),
    ));
    notifyListeners();
    try {
      await backend.sendFile(chatId, file, localId: localId, localPath: file.path);
      _armUndo(localId);
    } catch (_) {
      final i = messages.indexWhere((m) => m.localId == localId);
      if (i >= 0) {
        messages[i] = messages[i].copyWith(status: MsgStatus.failed);
      }
      onError('Не удалось отправить файл');
    }
  }

  /// Гифка: анимированное медиа (kind=gif), в пузыре крупный GIF.
  Future<void> sendGif(File file, String name) async {
    final localId = 'g${DateTime.now().microsecondsSinceEpoch}';
    messages.insert(0, ChatMsg(
      type: MsgType.file,
      incoming: false,
      time: _now(),
      status: MsgStatus.sending,
      localId: localId,
      date: DateTime.now(),
      attachment: AttachmentData(
        kind: AttachmentKind.gif,
        name: name,
        size: file.lengthSync(),
      ),
    ));
    notifyListeners();
    try {
      await backend.sendFile(chatId, file,
          localId: localId, localPath: file.path, mime: 'image/gif');
      _armUndo(localId);
    } catch (_) {
      final i = messages.indexWhere((m) => m.localId == localId);
      if (i >= 0) {
        messages[i] = messages[i].copyWith(status: MsgStatus.failed);
      }
      onError('Не удалось отправить гифку');
    }
  }

  /// Вложение, отправляемое JSON-строкой в text (локация/контакт/опрос/голос).
  Future<void> sendAttachmentJson(
    String json,
    MsgType type,
    AttachmentData attach,
  ) async {
    final localId = 'a${DateTime.now().microsecondsSinceEpoch}';
    messages.insert(0, ChatMsg(
      type: type,
      incoming: false,
      time: _now(),
      status: MsgStatus.sending,
      localId: localId,
      date: DateTime.now(),
      attachment: attach,
    ));
    notifyListeners();
    try {
      await backend.sendText(chatId, json, localId: localId);
    } catch (_) {
      final i = messages.indexWhere((m) => m.localId == localId);
      if (i >= 0) {
        messages[i] = messages[i].copyWith(status: MsgStatus.failed);
      }
      onError('Не удалось отправить вложение');
    }
  }

  /// Голос в опросе: служебное сообщение poll_vote (в ленте не видно).
  Future<void> sendPollVote(String pollId, int opt) {
    return sendAttachmentJson(
      AttachmentData.encode(
        kind: AttachmentKind.pollVote,
        pollId: pollId,
        opt: opt,
      ),
      MsgType.pollVote,
      AttachmentData(kind: AttachmentKind.pollVote, pollId: pollId, opt: opt),
    );
  }

  // ─── Действия над сообщениями ───

  void addReaction(int i, String emoji) {
    final serverId = messages[i].serverId;
    if (serverId != null) {
      backend.setReaction(chatId, serverId, emoji);
    }
    final m = messages[i];
    final list = [...m.reactions];
    final existing = list.indexWhere((r) => r.emoji == emoji);
    if (existing >= 0) {
      list.removeAt(existing);
      messages[i] = list.isEmpty
          ? m.copyWith(reactions: const [])
          : m.copyWith(reactions: list);
    } else {
      list.add(ChatReaction(emoji, 1));
      messages[i] = m.copyWith(reactions: list);
    }
    notifyListeners();
  }

  void heartReact(int i) {
    final m = messages[i];
    final has = m.reactions.any((r) => r.emoji == '❤️');
    if (has) {
      if (m.serverId != null) {
        backend.setReaction(chatId, m.serverId!, '❤️');
      }
      messages[i] = m.copyWith(
        reactions: m.reactions.where((r) => r.emoji != '❤️').toList(),
      );
    } else {
      addReaction(i, '❤️');
      return;
    }
    notifyListeners();
  }

  void replyToMsg(int i) {
    replyTo = i;
    notifyListeners();
  }

  void startEdit(int i) {
    editingIdx = i;
    replyTo = null;
    notifyListeners();
  }

  void cancelEdit() {
    editingIdx = null;
    notifyListeners();
  }

  void setReply(int? i) {
    replyTo = i;
    notifyListeners();
  }

  Future<void> deleteMessage(ChatMsg msg, {required bool everyone}) async {
    final idx = messages.indexOf(msg);
    if (idx < 0) return;
    if (everyone) {
      try {
        await backend.deleteMessage(msg.serverId!);
        if (_disposed) return;
        messages.removeAt(idx);
      } catch (_) {
        onError('Не удалось удалить');
        return;
      }
    } else {
      // «Удалить для меня»: скрываем локально и помечаем на сервере,
      // чтобы сообщение не вернулось при следующей загрузке/реконнекте.
      messages.removeAt(idx);
      final serverId = msg.serverId;
      if (serverId != null) {
        try {
          await backend.hideMessageForMe(serverId);
        } catch (_) {
          // Серверное скрытие не критично: сообщение уже убрано из ленты.
        }
      }
    }
    notifyListeners();
  }

  /// Bulk delete selected messages (V4.1).
  Future<void> deleteSelected({required bool everyone}) async {
    final toDelete = selectedMessages;
    for (final msg in toDelete) {
      await deleteMessage(msg, everyone: everyone);
    }
    clearSelection();
  }

  /// Bulk forward selected messages (V4.1).
  Future<void> forwardSelected(String targetChatId) async {
    final selected = selectedMessages.toList();
    final backend = VibeBackend.instance;
    for (final msg in selected) {
      final vibeMsg = VibeMessage(
        id: msg.serverId ?? '',
        chatId: chatId,
        senderId: '',
        senderName: '',
        senderAvatar: null,
        text: msg.type == MsgType.text ? msg.text : null,
        voicePath: msg.voiceUrl,
        photoPath: msg.photoUrl,
        videoPath: msg.videoUrl,
        created: DateTime.now(),
        incoming: msg.incoming,
        status: MsgStatus.sent,
        stickerEmoji: msg.stickerEmoji,
        forwardedFrom: msg.forwardedFrom,
      );
      await backend.forwardMessage(targetChatId, vibeMsg);
    }
    clearSelection();
  }

  /// Bulk copy selected messages text (V4.1).
  String copySelectedText() {
    return selectedMessages
        .where((m) => m.text.isNotEmpty)
        .map((m) => m.text)
        .join('\n');
  }

  /// Закрепить/открепить сообщение. `serverId == null` — снять верхний
  /// закреп (как кнопка «×» на плашке). Облако обновляется best-effort:
  /// миграция не применена/сеть упала — остаёмся на локальном списке.
  Future<void> setPin(String? serverId) async {
    if (serverId == null) {
      if (pins.isNotEmpty) {
        await unpin(pins.first);
      }
      return;
    }
    if (pins.contains(serverId)) {
      await unpin(serverId);
      return;
    }
    _pinsTouchedLocally = true;
    pins.insert(0, serverId);
    _persistPins();
    notifyListeners();
    try {
      await backend.pinMessage(chatId, serverId);
    } catch (_) {
      // Облако недоступно — закреп остаётся локальным (не фейк).
    }
  }

  Future<void> unpin(String serverId) async {
    if (!pins.remove(serverId)) return;
    _pinsTouchedLocally = true;
    _persistPins();
    notifyListeners();
    try {
      await backend.unpinMessage(chatId, serverId);
    } catch (_) {}
  }

  /// Облако — источник правды: если оно ответило (таблица есть), локальный
  /// список заменяется облачным; при сбое остаётся локальный (деградация).
  /// Локальные пины, сделанные во время запроса, не перетираются.
  Future<void> _refreshPinsFromServer() async {
    try {
      final list = await backend.fetchChatPins(chatId);
      if (_disposed || _pinsTouchedLocally) return;
      pins = list;
      _persistPins();
      notifyListeners();
    } catch (_) {}
  }

  void _persistPins() {
    SettingsService.instance.setPinnedMessageIds(chatId, pins);
  }

  /// «Очистить историю»: сервер удаляет сообщения чата, лента очищается
  /// локально сразу (не дожидаясь realtime-подтверждения).
  Future<void> clearHistory() async {
    try {
      await backend.clearHistory(chatId);
      if (_disposed) return;
      messages.clear();
      notifyListeners();
    } catch (_) {
      onError('Не удалось очистить историю');
    }
  }

  /// Прыжок к закреплённому: сообщение временно поднимается к низу экрана
  /// и подсвечивается (как в Telegram).
  void jumpToPinned(String id) {
    final i = messages.indexWhere((m) => m.serverId == id);
    if (i < 0) return;
    final msg = messages[i];
    _pinTimer?.cancel();
    messages.removeAt(i);
    messages.insert(0, msg);
    pinFlashId = id;
    _pinTimer = Timer(const Duration(seconds: 3), () {
      if (_disposed) return;
      final j = messages.indexWhere((m) => m.serverId == id);
      if (j == 0) {
        messages.removeAt(0);
        messages.insert(i > 0 ? i : 0, msg);
      }
      pinFlashId = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void setGroupTitle(String title) {
    groupTitle = title;
    notifyListeners();
  }

  void markRead() {
    backend.markChatRead(chatId);
  }

  // ─── Маппинг ───

  ChatMsg _toMsg(VibeMessage m) {
    final attach = AttachmentData.tryParse(m.text);
    MsgType type;
    if (attach != null) {
      switch (attach.kind) {
        case AttachmentKind.file:
          type = MsgType.file;
          break;
        case AttachmentKind.gif:
          type = MsgType.file;
          break;
        case AttachmentKind.location:
          type = MsgType.location;
          break;
        case AttachmentKind.contact:
          type = MsgType.contact;
          break;
        case AttachmentKind.poll:
          type = MsgType.poll;
          break;
        case AttachmentKind.pollVote:
          type = MsgType.pollVote;
          break;
      }
    } else if (m.stickerEmoji != null) {
      type = MsgType.text; // Стикер — тип text, рендерим по stickerEmoji.
    } else if (m.photoPath != null) {
      type = MsgType.photo;
    } else if (m.voicePath != null) {
      type = MsgType.voice;
    } else if (m.videoPath != null) {
      type = MsgType.video;
    } else {
      type = MsgType.text;
    }
    return ChatMsg(
      type: type,
      incoming: m.incoming,
      time: _fmtTime(m.created),
      text: attach == null ? (m.text ?? '') : '',
      photoSeed: 0,
      voiceSeconds: 10,
      voiceUrl: m.voicePath,
      photoUrl: m.photoPath,
      videoUrl: m.videoPath,
      status: m.status,
      localId: m.localId,
      edited: m.edited,
      forwardedFrom: m.forwardedFrom,
      serverId: m.id,
      stickerEmoji: m.stickerEmoji,
      date: m.created,
      attachment: attach,
      reactions: [
        for (final e in m.reactions.entries) ChatReaction(e.key, e.value),
      ],
    );
  }

  ChatMsg _copyEditedText(ChatMsg m, String? text) {
    return ChatMsg(
      type: m.type,
      incoming: m.incoming,
      time: m.time,
      text: text ?? m.text,
      photoSeed: m.photoSeed,
      voiceSeconds: m.voiceSeconds,
      voicePath: m.voicePath,
      voiceUrl: m.voiceUrl,
      photoUrl: m.photoUrl,
      videoPath: m.videoPath,
      videoUrl: m.videoUrl,
      reactions: m.reactions,
      replyText: m.replyText,
      replyAuthor: m.replyAuthor,
      status: m.status,
      localId: m.localId,
      edited: true,
      forwardedFrom: m.forwardedFrom,
      serverId: m.serverId,
      stickerEmoji: m.stickerEmoji,
      date: m.date,
      attachment: m.attachment,
    );
  }

  ChatMsg _copyReactions(ChatMsg m, List<ChatReaction> list) {
    return ChatMsg(
      type: m.type,
      incoming: m.incoming,
      time: m.time,
      text: m.text,
      photoSeed: m.photoSeed,
      voiceSeconds: m.voiceSeconds,
      voicePath: m.voicePath,
      voiceUrl: m.voiceUrl,
      photoUrl: m.photoUrl,
      videoPath: m.videoPath,
      videoUrl: m.videoUrl,
      reactions: list,
      replyText: m.replyText,
      replyAuthor: m.replyAuthor,
      status: m.status,
      localId: m.localId,
      edited: m.edited,
      forwardedFrom: m.forwardedFrom,
      serverId: m.serverId,
      stickerEmoji: m.stickerEmoji,
      date: m.date,
      attachment: m.attachment,
    );
  }

  static String _fmtTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  static String _now() {
    final now = DateTime.now();
    return '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _disposed = true;
    _draftTimer?.cancel();
    if (draft.trim().isNotEmpty) {
      SettingsService.instance.setDraft(chatId, draft);
    }
    _unreadTimer?.cancel();
    _undoTimer?.cancel();
    _sub?.cancel();
    _msgEventsSub?.cancel();
    _pinSub?.cancel();
    _typingSub?.cancel();
    _typingReset?.cancel();
    _pinTimer?.cancel();
    super.dispose();
  }
}
