import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/vibe_offline_banner.dart';
import '../core/services/notification_service.dart';
import '../data/backend.dart';
import '../data/settings_service.dart';
import 'chat_search_screen.dart';
import 'emoji_sticker_panel.dart';
import 'forward_message_screen.dart';
import 'group_info_screen.dart';
import 'peer_profile_screen.dart';
import 'settings/notifications_settings.dart';
import 'video_round_recorder.dart';

/// Экран диалога. Двойной тап по сообщению — реакция-сердечко с искрами.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chat});

  final VibeChat chat;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

enum _MsgType { text, photo, voice, video }

/// Разбивает текст на спаны, делая URL-ссылки кликабельными (как в TG).
final _urlPattern = RegExp(
  r'(?:(?:https?|ftp)://|www\.)[^\s<>"(){}]+',
  caseSensitive: false,
);

List<InlineSpan> buildLinkSpans(
  String text,
  Color linkColor,
  ValueChanged<String> onTap,
) {
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final match in _urlPattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    final url = text.substring(match.start, match.end);
    spans.add(
      TextSpan(
        text: url,
        style: TextStyle(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor.withValues(alpha: 0.5),
        ),
        recognizer: TapGestureRecognizer()..onTap = () => onTap(url),
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return spans;
}

class _Reaction {
  const _Reaction(this.emoji, this.count);

  final String emoji;
  final int count;
}

class _Msg {
  const _Msg({
    required this.type,
    required this.incoming,
    required this.time,
    this.text = '',
    this.photoSeed = 0,
    this.voiceSeconds = 0,
    this.voicePath,
    this.voiceUrl,
    this.photoUrl,
    this.videoPath,
    this.videoUrl,
    this.reactions = const [],
    this.replyText,
    this.replyAuthor,
    this.status = MsgStatus.sent,
    this.localId,
    this.edited = false,
    this.forwardedFrom,
    this.serverId,
    this.stickerEmoji,
    this.date,
  });

  final _MsgType type;
  final bool incoming;
  final String time;
  final String text;

  /// Полная дата сообщения — для разделителей дат (как в Telegram).
  final DateTime? date;

  /// Сид для демо-превью «фото» (если нет реального фото).
  final int photoSeed;

  /// Длительность голосового, секунды.
  final int voiceSeconds;

  /// Локальный файл записанного голосового.
  final String? voicePath;

  /// Сетевой URL голосового (входящее сообщение).
  final String? voiceUrl;

  /// Сетевой URL фото (входящее сообщение).
  final String? photoUrl;

  /// Локальный файл записанного видеокружка.
  final String? videoPath;

  /// Сетевой URL видеокружка (входящее сообщение).
  final String? videoUrl;

  final List<_Reaction> reactions;

  // Ответ/цитата.
  final String? replyText;
  final String? replyAuthor;

  /// Галочки: отправлено / доставлено / прочитано (для своих).
  final MsgStatus status;

  /// Ключ «мгновенного» сообщения — по нему заменяем пузырь на ответ сервера.
  final String? localId;

  /// Сообщение изменено автором (метка «изменено»).
  final bool edited;

  /// От кого переслано («Переслано от …»).
  final String? forwardedFrom;

  /// Серверный id — для правок/удалений из realtime-событий.
  final String? serverId;

  /// Стикер-эмодзи (у стикеров нет текста).
  final String? stickerEmoji;

  _Msg copyWith({
    List<_Reaction>? reactions,
    MsgStatus? status,
    String? localId,
    bool? edited,
  }) {
    return _Msg(
      type: type,
      incoming: incoming,
      time: time,
      text: text,
      photoSeed: photoSeed,
      voiceSeconds: voiceSeconds,
      voicePath: voicePath,
      voiceUrl: voiceUrl,
      photoUrl: photoUrl,
      videoPath: videoPath,
      videoUrl: videoUrl,
      reactions: reactions ?? this.reactions,
      replyText: replyText,
      replyAuthor: replyAuthor,
      status: status ?? this.status,
      localId: localId ?? this.localId,
      edited: edited ?? this.edited,
      forwardedFrom: forwardedFrom,
      serverId: serverId,
      date: date,
    );
  }
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  late final List<_Msg> _messages;
  StreamSubscription<VibeMessage>? _sub;
  StreamSubscription<VibeMsgEvent>? _msgEventsSub;

  /// Пагинация истории: размер страницы и флаги подгрузки старых.
  static const int _pageSize = 80;
  bool _loadingOlder = false;
  bool _hasMoreOlder = true;

  /// Режим редактирования: индекс редактируемого сообщения.
  int? _editingIdx;

  /// Закреплённое сообщение чата (локально, один на чат — как в TG).
  String? _pinMsgId;
  String? _pinFlashId;

  /// Кастомное название группы (после переименования) — поверх chat.title.
  String? _groupTitle;

  // ─── «Печатает…» ───
  bool _peerTyping = false;
  Timer? _typingReset;
  StreamSubscription<String>? _typingSub;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);

  /// Панель эмодзи/стикеров видна.
  bool _showEmojiPanel = false;
  Timer? _pinTimer;

  // Запись голосового (реальная, через record).
  bool _recording = false;
  bool _micLocked = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  final _recorder = AudioRecorder();
  String? _recordPath;

  // Запись видеокружка прямо в поле ввода (удержание камеры, как в TG).
  CameraController? _camCtrl;
  bool _camReady = false;
  bool _videoRolling = false;
  bool _videoLocked = false;
  int _videoSeconds = 0;
  Timer? _videoTimer;
  bool _justHeld = false;
  double _videoDragDy = 0;
  Timer? _holdTimer;

  // Воспроизведение голосовых.
  final _player = AudioPlayer();

  // Индекс цитируемого сообщения.
  int? _replyTo;

  // Кнопка «вниз» + счётчик новых сообщений (как в Telegram).
  bool _atBottom = true;
  int _newIncoming = 0;

  String get _chatId => widget.chat.id;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.enterChat(_chatId);
    _messages = [];
    _loadMessages();
    _pinMsgId = SettingsService.instance.pinnedMessageId(_chatId);
    _scroll.addListener(_onChatScroll);
    // Открыл чат — отправитель сразу видит синие галочки (как в TG).
    VibeBackend.instance.markChatRead(_chatId);
    _sub = VibeBackend.instance.stream.listen((msg) {
      if (msg.chatId != _chatId || !mounted) return;
      setState(() {
        if (msg.localId != null) {
          // Обновление статуса своего сообщения (часики → галочки).
          final i = _messages.indexWhere((m) => m.localId == msg.localId);
          if (i >= 0) {
            final old = _messages[i];
            _messages[i] = _Msg(
              type: old.type,
              incoming: old.incoming,
              time: old.time,
              text: old.text,
              photoSeed: old.photoSeed,
              voiceSeconds: old.voiceSeconds,
              voicePath: old.voicePath,
              voiceUrl: old.voiceUrl,
              photoUrl: old.photoUrl,
              videoPath: old.videoPath,
              videoUrl: old.videoUrl,
              reactions: old.reactions,
              replyText: old.replyText,
              replyAuthor: old.replyAuthor,
              status: msg.status,
              localId: msg.localId,
              stickerEmoji: old.stickerEmoji,
              date: old.date,
            );
          }
        } else if (msg.incoming) {
          _messages.insert(0, _toMsg(msg)); // Вставляем в начало (низ экрана)
          if (!_atBottom) _newIncoming++;
        }
      });
      // В режиме reverse прокрутка не нужна, список сам растет вверх
    });
    // «Печатает…»: событие от собеседника + автосброс через 4 секунды.
    _typingSub = VibeBackend.instance.typingEvents.listen((chatId) {
      if (chatId != _chatId || !mounted) return;
      setState(() => _peerTyping = true);
      _typingReset?.cancel();
      _typingReset = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() => _peerTyping = false);
      });
    });
    // Правки/удаления/очистка — «на лету», как в Telegram.
    _msgEventsSub = VibeBackend.instance.msgEvents.listen((ev) {
      if (ev.chatId != _chatId || !mounted) return;
      setState(() {
        switch (ev.type) {
          case VibeMsgEventType.edited:
            final upd = ev.updated;
            if (upd == null) return;
            final i = _messages.indexWhere((m) => m.serverId == ev.messageId);
            if (i < 0) return;
            _messages[i] = _Msg(
              type: _messages[i].type,
              incoming: _messages[i].incoming,
              time: _messages[i].time,
              text: upd.text ?? _messages[i].text,
              photoSeed: _messages[i].photoSeed,
              voiceSeconds: _messages[i].voiceSeconds,
              voicePath: _messages[i].voicePath,
              voiceUrl: _messages[i].voiceUrl,
              photoUrl: _messages[i].photoUrl,
              videoPath: _messages[i].videoPath,
              videoUrl: _messages[i].videoUrl,
              reactions: _messages[i].reactions,
              replyText: _messages[i].replyText,
              replyAuthor: _messages[i].replyAuthor,
              status: _messages[i].status,
              localId: _messages[i].localId,
              edited: true,
              forwardedFrom: _messages[i].forwardedFrom,
              serverId: _messages[i].serverId,
              date: _messages[i].date,
            );
          case VibeMsgEventType.deleted:
            final i = _messages.indexWhere((m) => m.serverId == ev.messageId);
            if (i >= 0) _messages.removeAt(i);
          case VibeMsgEventType.cleared:
            _messages.clear();
          case VibeMsgEventType.reactions:
            final reac = ev.reactions;
            if (reac == null) return;
            final i = _messages.indexWhere((m) => m.serverId == ev.messageId);
            if (i < 0) return;
            final list = [
              for (final e in reac.entries) _Reaction(e.key, e.value),
            ];
            final m = _messages[i];
            _messages[i] = _Msg(
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
            );
        }
      });
    });
  }

  Future<void> _loadMessages() async {
    _hasMoreOlder = true;
    try {
      final list = await VibeBackend.instance.listMessages(
        _chatId,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() => _messages
        ..clear()
        ..addAll(list.map(_toMsg)));
      // Первичная загрузка реакций (счётчики с сервера).
      VibeBackend.instance.refreshChatReactions(_chatId);
    } catch (_) {}
  }

  /// Подгрузка более старых сообщений (при прокрутке к началу списка).
  Future<void> _loadOlderIfNeeded() async {
    if (_loadingOlder || !_hasMoreOlder || _messages.isEmpty) return;
    final oldest = _messages.last.date;
    _loadingOlder = true;
    if (mounted) setState(() {});
    try {
      final older = await VibeBackend.instance.listMessages(
        _chatId,
        limit: _pageSize,
        before: oldest,
      );
      if (!mounted) return;
      setState(() {
        _loadingOlder = false;
        if (older.length < _pageSize) _hasMoreOlder = false;
        if (older.isNotEmpty) _messages.addAll(older.map(_toMsg));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOlder = false);
    }
  }

  _Msg _toMsg(VibeMessage m) {
    _MsgType type;
    if (m.stickerEmoji != null) {
      type = _MsgType.text; // Стикер хранится в stickerEmoji, текст пуст
    } else if (m.photoPath != null) {
      type = _MsgType.photo;
    } else if (m.voicePath != null) {
      type = _MsgType.voice;
    } else if (m.videoPath != null) {
      type = _MsgType.video;
    } else {
      type = _MsgType.text;
    }
    return _Msg(
      type: type,
      incoming: m.incoming,
      time: _fmtTime(m.created),
      text: m.text ?? '',
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
      reactions: [
        for (final e in m.reactions.entries) _Reaction(e.key, e.value),
      ],
    );
  }

  String _fmtTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _now() {
    final now = DateTime.now();
    return '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    NotificationService.instance.exitChat(_chatId);
    _sub?.cancel();
    _msgEventsSub?.cancel();
    _typingSub?.cancel();
    _typingReset?.cancel();
    _recordTimer?.cancel();
    _videoTimer?.cancel();
    _holdTimer?.cancel();
    _camCtrl?.dispose();
    _recorder.dispose();
    _player.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Шлём «печатает…» не чаще раза в 2.5 секунды (и только при непустом
  /// вводе) — иначе зальём собеседника событий.
  void _notifyTyping() {
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) < const Duration(milliseconds: 2500)) {
      return;
    }
    if (_input.text.trim().isEmpty) return;
    _lastTypingSent = now;
    VibeBackend.instance.sendTyping(_chatId);
  }

  void _scrollToEnd() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: VibeAnimations.fadeIn,
        curve: VibeAnimations.easeOut,
      );
    }
  }

  /// Реагируем на прокрутку: скрываем кнопку «вниз», когда мы уже внизу,
  /// и подгружаем более старые сообщения, когда доскроллили до верха.
  void _onChatScroll() {
    if (!_scroll.hasClients || !mounted) return;
    final pos = _scroll.position;
    // reverse:true — внизу экрана последние сообщения (практически 0 px).
    final atBottom = pos.pixels < 80;
    if (atBottom != _atBottom || _newIncoming > 0) {
      setState(() {
        _atBottom = atBottom;
        if (atBottom) _newIncoming = 0;
      });
    }
    // Верх списка (старые сообщения) — пагинация вверх.
    if (pos.maxScrollExtent > 0 &&
        pos.pixels >= pos.maxScrollExtent - 120) {
      _loadOlderIfNeeded();
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    final editIdx = _editingIdx;
    if (editIdx != null) {
      // ─── Режим редактирования своего сообщения ───
      final msg = _messages[editIdx];
      try {
        final updated = await VibeBackend.instance.updateMessage(
          msg.serverId!,
          text,
        );
        if (!mounted) return;
        setState(() {
          if (updated != null) {
            _messages[editIdx] = _Msg(
              type: msg.type,
              incoming: msg.incoming,
              time: msg.time,
              text: text,
              photoSeed: msg.photoSeed,
              voiceSeconds: msg.voiceSeconds,
              voicePath: msg.voicePath,
              voiceUrl: msg.voiceUrl,
              photoUrl: msg.photoUrl,
              videoPath: msg.videoPath,
              videoUrl: msg.videoUrl,
              reactions: msg.reactions,
              replyText: msg.replyText,
              replyAuthor: msg.replyAuthor,
              status: msg.status,
              localId: msg.localId,
              edited: true,
              forwardedFrom: msg.forwardedFrom,
              serverId: msg.serverId,
              stickerEmoji: msg.stickerEmoji,
              date: msg.date,
            );
          }
          _input.clear();
          _editingIdx = null;
          _replyTo = null;
        });
      } catch (_) {
        _snack('Не удалось изменить');
      }
      return;
    }
    final replyIdx = _replyTo;
    final replyText =
        replyIdx == null ? null : _messages[replyIdx].text;
    final replyAuthor = replyIdx == null
        ? null
        : _messages[replyIdx].incoming
            ? widget.chat.title
            : 'Вы';
    final localId = 'c${DateTime.now().microsecondsSinceEpoch}';
    // Пузырь появляется мгновенно (часики), сервер подтверждает фоном.
    setState(() {
      _messages.insert(0, _Msg( // Вставляем в начало (низ)
        type: _MsgType.text,
        incoming: false,
        time: _fmtTime(DateTime.now()),
        text: text,
        replyText: replyText,
        replyAuthor: replyAuthor,
        status: MsgStatus.sending,
        localId: localId,
        date: DateTime.now(),
      ));
      _input.clear();
      _replyTo = null;
    });
    try {
      await VibeBackend.instance.sendText(
        _chatId,
        text,
        localId: localId,
        replyText: replyText,
        replyAuthor: replyAuthor,
      );
    } catch (_) {
      _snack('Не удалось отправить');
    }
  }

  Future<void> _sendSticker(String emoji) async {
    HapticFeedback.lightImpact();
    final localId = 's${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _messages.insert(0, _Msg(
        type: _MsgType.text,
        incoming: false,
        time: _fmtTime(DateTime.now()),
        stickerEmoji: emoji,
        status: MsgStatus.sending,
        localId: localId,
        date: DateTime.now(),
      ));
    });
    try {
      await VibeBackend.instance.sendSticker(_chatId, emoji, localId: localId);
    } catch (_) {
      _snack('Не удалось отправить стикер');
    }
  }

  Future<void> _sendPhoto() async {
    HapticFeedback.lightImpact();
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final localId = 'c${DateTime.now().microsecondsSinceEpoch}';
    final sent = await VibeBackend.instance
        .sendPhoto(_chatId, bytes, localId: localId);
    if (!mounted) return;
    setState(() {
      _messages.insert(0, _Msg( // Вставляем в начало (низ)
        type: _MsgType.photo,
        incoming: false,
        time: _fmtTime(sent.created),
        photoSeed: 0,
        photoUrl: sent.photoPath,
        localId: localId,
        date: sent.created,
      ));
    });
  }

  Future<void> _startRecording() async {
    await _stopPlayback();
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _snack('Нет доступа к микрофону');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
    } catch (_) {
      _snack('Не удалось начать запись');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _recording = true;
      _micLocked = false;
      _recordSeconds = 0;
      _recordPath = path;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _recordSeconds++;
        if (_recordSeconds >= 60) {
          t.cancel();
          _stopRecording();
        }
      });
    });
  }

  /// Свайп вверх по кнопке: зафиксировать запись (замочек).
  void _lockMic() {
    HapticFeedback.selectionClick();
    setState(() => _micLocked = true);
  }

  /// Свайп вниз по зафиксированной кнопке: снять фиксацию (запись идёт дальше).
  void _unlockMic() {
    if (!_micLocked) return;
    HapticFeedback.selectionClick();
    setState(() => _micLocked = false);
  }

  void _cancelRecording() {
    _recordTimer?.cancel();
    final path = _recordPath;
    HapticFeedback.selectionClick();
    setState(() {
      _recording = false;
      _micLocked = false;
      _recordSeconds = 0;
      _recordPath = null;
    });
    if (path != null) {
      _recorder.cancel();
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    if (!_recording) return;
    final stopped = await _recorder.stop();
    final seconds = _recordSeconds;
    HapticFeedback.mediumImpact();
    final path = stopped;
    setState(() {
      _recording = false;
      _micLocked = false;
      _recordSeconds = 0;
      _recordPath = null;
    });
    if (path != null) {
      if (seconds < 1) {
        _snack('Запись слишком короткая');
        return;
      }
      final localId = 'c${DateTime.now().microsecondsSinceEpoch}';
      setState(() {
        _messages.insert(0, _Msg( // Вставляем в начало (низ)
          type: _MsgType.voice,
          incoming: false,
          time: _now(),
          voiceSeconds: seconds,
          voicePath: path,
          status: MsgStatus.sending,
          localId: localId,
          date: DateTime.now(),
        ));
      });
      try {
        await VibeBackend.instance.sendVoice(
          _chatId,
          File(path),
          localId: localId,
          localPath: path,
          voiceSeconds: seconds,
        );
      } catch (_) {
        _snack('Не удалось отправить голосовое');
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  Future<void> _stopPlayback() async {
    if (_player.state == PlayerState.playing) {
      await _player.stop();
    }
  }

  void _addReaction(int i, String emoji) {
    HapticFeedback.selectionClick();
    final serverId = _messages[i].serverId;
    if (serverId != null) {
      VibeBackend.instance.setReaction(_chatId, serverId, emoji);
    }
    setState(() {
      final m = _messages[i];
      final list = [...m.reactions];
      final existing = list.indexWhere((r) => r.emoji == emoji);
      if (existing >= 0) {
        list.removeAt(existing);
        if (list.isEmpty) {
          _messages[i] = m.copyWith(reactions: const []);
          return;
        }
      } else {
        list.add(_Reaction(emoji, 1));
      }
      _messages[i] = m.copyWith(reactions: list);
    });
  }

  void _heartReact(int i) {
    HapticFeedback.selectionClick();
    final m = _messages[i];
    final has = m.reactions.any((r) => r.emoji == '❤️');
    if (has) {
      if (m.serverId != null) {
        VibeBackend.instance.setReaction(_chatId, m.serverId!, '❤️');
      }
      setState(() {
        _messages[i] = m.copyWith(
          reactions: m.reactions
              .where((r) => r.emoji != '❤️')
              .toList(),
        );
      });
    } else {
      _addReaction(i, '❤️');
    }
  }

  void _replyToMsg(int i) {
    HapticFeedback.mediumImpact(); // ОТКЛИК НА СВАЙП/ОТВЕТ
    setState(() => _replyTo = i);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDarkMode
          ? context.vibeSurfaceLow
          : const Color(0xFFEBE9F4),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: SettingsService.instance.appearanceVersion,
                  builder: (context, _) => CustomScrollView(
                    controller: _scroll,
                    reverse: true, // СТАНДАРТ МЕССЕНДЖЕРОВ
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // В режиме reverse: true порядок сливеров инвертирован
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 100), // Отступ под полем ввода
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: VibeSpacing.md,
                          vertical: VibeSpacing.md,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              // Разделитель даты, как в Telegram: показываем
                              // при смене дня между соседними сообщениями.
                              final showDate = i == 0 ||
                                  !_sameDay(
                                    _messages[i].date,
                                    _messages[i - 1].date,
                                  );
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showDate) _DateDivider(_messages[i].date),
                                  _MessageBubble(
                                    msg: _messages[i],
                                    key: ValueKey(
                                        'msg_${_messages[i].localId ?? i}'),
                                    onHeart: () => _heartReact(i),
                                    onLongPress: () => _showMessageActions(i),
                                    onReply: () => _replyToMsg(i),
                                    onOpenUrl: _openUrl,
                                    scrollController: _scroll,
                                    player: _player,
                                    highlight:
                                        _pinFlashId != null &&
                                            _messages[i].serverId == _pinFlashId,
                                  ),
                                ],
                              );
                            },
                            childCount: _messages.length,
                          ),
                        ),
                      ),
                      ListenableBuilder(
                        listenable: VibeBackend.instance.connectivityVersion,
                        builder: (context, _) => VibeBackend.instance.isOffline
                            ? const SliverToBoxAdapter(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: VibeOfflineBanner(),
                                ),
                              )
                            : const SliverToBoxAdapter(
                                child: SizedBox.shrink(),
                              ),
                      ),
                      // Загрузка более старых сообщений (вверху истории).
                      if (_hasMoreOlder)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: VibeSpacing.md,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: _loadingOlder ? null : 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Тонкий отступ под шапку (теперь он вверху экрана)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.of(context).padding.top + 72,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildInputBar(context),
            ],
          ),
          // Плавающая шапка "Три пилюли"
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAppBar(context),
                  if (_pinMsgId != null) _buildPinnedBanner(context),
                ],
              ),
            ),
          ),
          // Кнопка «вниз» со счётчиком новых сообщений (как в Telegram).
          Positioned(
            right: VibeSpacing.md,
            bottom:
                VibeSpacing.md + MediaQuery.of(context).viewPadding.bottom,
            child: _JumpDownButton(
              visible: !_atBottom || _newIncoming > 0,
              badge: _newIncoming,
              onTap: () {
                HapticFeedback.lightImpact();
                _scrollToEnd();
                setState(() {
                  _atBottom = true;
                  _newIncoming = 0;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Плашка «Закреплённое сообщение» под шапкой (как в Telegram).
  Widget _buildPinnedBanner(BuildContext context) {
    final pinned =
        _messages.where((m) => m.serverId == _pinMsgId).toList();
    final m = pinned.isEmpty
        ? null
        : _messages[_messages.indexWhere((x) => x.serverId == _pinMsgId)];
    final preview = m == null
        ? 'Закреплённое сообщение'
        : (m.type == _MsgType.text && m.text.isNotEmpty
            ? m.text
            : 'Закреплённое медиа');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VibeSpacing.md,
        VibeSpacing.xs,
        VibeSpacing.md,
        VibeSpacing.xs,
      ),
      child: Material(
        borderRadius: BorderRadius.circular(VibeRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (m?.serverId != null) _jumpToPinned(m!.serverId!);
          },
          child: Container(
            color: context.vibeSurfaceVariant.withValues(alpha: 0.92),
            padding: const EdgeInsets.symmetric(
              horizontal: VibeSpacing.md,
              vertical: VibeSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.push_pin_rounded,
                  size: 15,
                  color: context.vibePrimary,
                ),
                const SizedBox(width: VibeSpacing.sm),
                Expanded(
                  child: Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VibeTypography.caption.copyWith(
                      color: context.vibeTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: VibeSpacing.sm),
                GestureDetector(
                  onTap: () => _pinMsg(null),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: context.vibeTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final chat = widget.chat;
    final isGroup = chat.kind == 'group';
    final typing = !isGroup && _peerTyping;
    final subtitle = typing
        ? 'печатает…'
        : (isGroup
            ? 'Группа'
            : (chat.peerOnline
                ? 'в сети'
                : (chat.peerLastSeen != null
                    ? 'был(а) в сети ${VibeBackend.formatTime(chat.peerLastSeen)}'
                    : 'был(а) недавно')));
    final subtitleColor = typing
        ? context.vibePrimary
        : ((!isGroup && chat.peerOnline)
            ? VibeColors.success
            : context.vibeTextTertiary);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VibeSpacing.sm,
        VibeSpacing.xs,
        VibeSpacing.sm,
        VibeSpacing.xs,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Row(
            children: [
              _HeaderPill(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                ),
              ),
              const SizedBox(width: VibeSpacing.xs),
              Expanded(
                child: _HeaderPill(
                  onTap: widget.chat.kind == 'group'
                      ? _openGroupInfo
                      : _openProfile,
                  child: Row(
                    children: [
                      Hero(
                        tag: 'avatar_${chat.id}',
                        child: VibeAvatar(
                          name: chat.title,
                          size: VibeSizes.avatarMd,
                          online: chat.peerOnline,
                          photoUrl: chat.peerAvatar,
                        ),
                      ),
                      const SizedBox(width: VibeSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _groupTitle ?? chat.title,
                              overflow: TextOverflow.ellipsis,
                              style: VibeTypography.subtitle.copyWith(
                                fontSize: 15,
                                color: context.vibeTextPrimary,
                              ),
                            ),
                            Text(
                              subtitle,
                              overflow: TextOverflow.ellipsis,
                              style: VibeTypography.caption.copyWith(
                                fontSize: 11,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: VibeSpacing.xs),
              _HeaderPill(
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _openSearch,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Icon(Icons.search_rounded, size: 20),
                          ),
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        indent: 4,
                        endIndent: 4,
                        color: context.isDarkMode
                            ? Colors.white24
                            : const Color(0x1F1C1B22),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _chooseCall(context),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Icon(Icons.call_outlined, size: 20),
                          ),
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        indent: 4,
                        endIndent: 4,
                        color: context.isDarkMode
                            ? Colors.white24
                            : const Color(0x1F1C1B22),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showChatMenu(context),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Icon(Icons.more_vert_rounded, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Поиск по сообщениям чата: экран находок, выбор — прыжок к сообщению
  /// с подсветкой (тем же механизмом, что и у закреплённых).
  Future<void> _openSearch() async {
    final items = [
      for (final m in _messages)
        if (m.type == _MsgType.text && m.text.isNotEmpty && m.serverId != null)
          ChatSearchItem(
            serverId: m.serverId!,
            text: m.text,
            incoming: m.incoming,
            time: m.time,
          ),
    ];
    if (items.isEmpty) {
      _snack('В чате пока нет текстовых сообщений');
      return;
    }
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ChatSearchScreen(items: items),
      ),
    );
    if (id == null || !mounted) return;
    _jumpToPinned(id);
  }

  /// Инфо группы (тап по центральной пилюле в групповом чате).
  Future<void> _openGroupInfo() async {
    final result = await Navigator.of(context).push<GroupInfoResult>(
      MaterialPageRoute(
        builder: (_) => GroupInfoScreen(
          chatId: _chatId,
          title: _groupTitle ?? widget.chat.title,
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result.left) {
      Navigator.of(context).pop();
      return;
    }
    if (result.renamedTitle != null) {
      HapticFeedback.lightImpact();
      setState(() => _groupTitle = result.renamedTitle);
      _snack('Группа переименована');
    }
  }

  /// Профиль собеседника (тап по центральной пилюле шапки).
  Future<void> _openProfile() async {
    final media = [
      for (final m in _messages)
        if (m.type == _MsgType.photo)
          PeerMedia(isVideo: false, url: m.photoUrl)
        else if (m.type == _MsgType.video)
          PeerMedia(
            isVideo: true,
            url: m.videoUrl,
            localPath: m.videoPath,
          ),
    ];
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PeerProfileScreen(
          chat: widget.chat,
          media: media,
        ),
      ),
    );
  }

  /// Выбор способа звонка — как в TG: жмём «трубку», появляется
  /// аккуратный лист с аудио- и видеозвонком.
  void _chooseCall(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          VibeSpacing.xl,
          VibeSpacing.xs,
          VibeSpacing.xl,
          VibeSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetCallTile(
              icon: Icons.call_rounded,
              color: VibeColors.success,
              title: 'Аудиозвонок',
              subtitle: 'Через Vibe',
              onTap: () {
                HapticFeedback.mediumImpact(); // БОЛЕЕ МОЩНЫЙ ОТКЛИК
                Navigator.of(sheetCtx).pop();
                _snack('Аудиозвонок — в v2.0');
              },
            ),
            const SizedBox(height: VibeSpacing.xs),
            _SheetCallTile(
              icon: Icons.videocam_rounded,
              color: context.vibePrimary,
              title: 'Видеозвонок',
              subtitle: 'Через Vibe',
              onTap: () {
                HapticFeedback.mediumImpact(); // БОЛЕЕ МОЩНЫЙ ОТКЛИК
                Navigator.of(sheetCtx).pop();
                _snack('Видеозвонок — в v2.0');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChatMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => _ChatMenuSheet(
        chat: widget.chat,
        onSnack: _snack,
        onTapSearch: () {
          Navigator.of(sheetCtx).pop();
          _openSearch();
        },
      ),
    );
  }

  void _openAttachmentMenu(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          VibeSpacing.xl,
          VibeSpacing.sm,
          VibeSpacing.xl,
          VibeSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вложение',
              style: VibeTypography.subtitle.copyWith(
                color: context.vibeTextPrimary,
              ),
            ),
            const SizedBox(height: VibeSpacing.lg),
            Row(
              children: [
                _AttachmentItem(
                  icon: Icons.photo_library_rounded,
                  color: VibeColors.vivid,
                  label: 'Фото',
                  onTap: () {
                    Navigator.of(context).pop();
                    _sendPhoto();
                  },
                ),
                const SizedBox(width: VibeSpacing.lg),
                _AttachmentItem(
                  icon: Icons.mic_rounded,
                  color: const Color(0xFFEC4899),
                  label: 'Голос',
                  onTap: () {
                    Navigator.of(context).pop();
                    _startRecording();
                  },
                ),
                const SizedBox(width: VibeSpacing.lg),
                _AttachmentItem(
                  icon: Icons.insert_drive_file_rounded,
                  color: const Color(0xFFF59E0B),
                  label: 'Файл',
                  onTap: () {
                    Navigator.of(context).pop();
                    _showAttachments();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachments() {
    final photos = _messages.where((m) => m.type == _MsgType.photo).toList();
    final voices =
        _messages.where((m) => m.type == _MsgType.voice).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            VibeSpacing.xl,
            VibeSpacing.xs,
            VibeSpacing.xl,
            VibeSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Вложения',
                style: VibeTypography.subtitle.copyWith(
                  color: context.vibeTextPrimary,
                ),
              ),
              const SizedBox(height: VibeSpacing.sm),
              Text(
                '${photos.length} фото · ${voices.length} голосовых',
                style: VibeTypography.caption.copyWith(
                  color: context.vibeTextTertiary,
                ),
              ),
              const SizedBox(height: VibeSpacing.lg),
              if (photos.isEmpty && voices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: VibeSpacing.lg,
                  ),
                  child: Center(
                    child: Text(
                      'В этом чате пока нет вложений',
                      style: VibeTypography.body
                          .copyWith(color: context.vibeTextTertiary),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in photos)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: VibeNetImage(
                            source: p.photoUrl,
                            errorBuilder: (_, _, _) => Container(
                              color: context.vibeSurfaceVariant,
                              child: const Icon(
                                Icons.image_outlined,
                                color: VibeColors.textTertiaryDark,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageActions(int i) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          VibeSpacing.xl,
          VibeSpacing.xs,
          VibeSpacing.xl,
          VibeSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Действия',
              style: VibeTypography.subtitle.copyWith(
                color: context.vibeTextPrimary,
              ),
            ),
            const SizedBox(height: VibeSpacing.md),
            Wrap(
              spacing: VibeSpacing.sm,
              runSpacing: VibeSpacing.sm,
              children: [
                for (final (_, r) in _emojiOptions.indexed)
                  _ReactionButton(
                    emoji: r.$1,
                    onTap: () {
                      Navigator.of(context).pop();
                      _addReaction(i, r.$1);
                    },
                  ),
              ],
            ),
            const SizedBox(height: VibeSpacing.md),
            _ActionRow(
              icon: Icons.reply_rounded,
              label: 'Ответить',
              onTap: () {
                Navigator.of(context).pop();
                _replyToMsg(i);
              },
            ),
            _ActionRow(
              icon: Icons.copy_rounded,
              label: 'Копировать',
              onTap: () {
                Navigator.of(context).pop();
                Clipboard.setData(
                  ClipboardData(text: _messages[i].text),
                );
                _snack('Скопировано');
              },
            ),
            _ActionRow(
              icon: Icons.reply_all_rounded,
              label: 'Переслать',
              onTap: () {
                Navigator.of(context).pop();
                _openForward(_messages[i]);
              },
            ),
            if (_messages[i].serverId != null &&
                _messages[i].serverId == _pinMsgId)
              _ActionRow(
                icon: Icons.push_pin_rounded,
                label: 'Открепить',
                onTap: () {
                  Navigator.of(context).pop();
                  _pinMsg(null);
                },
              )
            else if (_messages[i].serverId != null)
              _ActionRow(
                icon: Icons.push_pin_outlined,
                label: 'Закрепить',
                onTap: () {
                  Navigator.of(context).pop();
                  _pinMsg(_messages[i].serverId);
                },
              ),
            if (!_messages[i].incoming && _messages[i].type == _MsgType.text)
              _ActionRow(
                icon: Icons.edit_rounded,
                label: 'Редактировать',
                onTap: () {
                  Navigator.of(context).pop();
                  _startEdit(i);
                },
              ),
            _ActionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Удалить',
              onTap: () {
                Navigator.of(context).pop();
                _deleteMsg(i);
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _emojiOptions = [
    ('❤️', 'сердце'),
    ('👍', 'лайк'),
    ('😂', 'смех'),
    ('🔥', 'огонь'),
    ('🎉', 'праздник'),
    ('😮', 'ух ты'),
    ('👏', 'браво'),
    ('😢', 'грустно'),
  ];

  void _startEdit(int i) {
    setState(() {
      _editingIdx = i;
      _replyTo = null;
      _input.text = _messages[i].text;
    });
    // Фокус на поле ввода.
    _scrollToEnd();
  }

  Future<void> _deleteMsg(int i) async {
    final msg = _messages[i];
    final isMine = !msg.incoming;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          VibeSpacing.xl,
          VibeSpacing.xs,
          VibeSpacing.xl,
          VibeSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Удалить сообщение',
              style: VibeTypography.subtitle.copyWith(
                color: context.vibeTextPrimary,
              ),
            ),
            const SizedBox(height: VibeSpacing.md),
            if (isMine && msg.serverId != null) ...[
              _ActionRow(
                icon: Icons.group_off_rounded,
                label: 'Удалить для всех',
                onTap: () => Navigator.of(context).pop('everyone'),
              ),
              const SizedBox(height: VibeSpacing.xs),
            ],
            _ActionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Удалить для меня',
              onTap: () => Navigator.of(context).pop('me'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final idx = _messages.indexOf(msg);
    if (idx < 0) return;

    if (action == 'everyone') {
      try {
        await VibeBackend.instance.deleteMessage(msg.serverId!);
        if (!mounted) return;
        setState(() => _messages.removeAt(idx));
      } catch (_) {
        _snack('Не удалось удалить');
      }
    } else {
      // «Удалить для меня» — скрываем локально.
      setState(() => _messages.removeAt(idx));
    }
  }

  void _pinMsg(String? serverId) {
    setState(() => _pinMsgId = serverId);
    SettingsService.instance.setPinnedMessageId(_chatId, serverId);
  }

  /// Прыжок к закреплённому сообщению: поднимаем к низу экрана и
  /// подсвечиваем пузырь (как в Telegram).
  void _jumpToPinned(String id) {
    final i = _messages.indexWhere((m) => m.serverId == id);
    if (i < 0) return;
    final msg = _messages[i];
    _pinTimer?.cancel();
    setState(() {
      _messages.removeAt(i);
      _messages.insert(0, msg);
      _pinFlashId = id;
    });
    _pinTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        final j = _messages.indexWhere((m) => m.serverId == id);
        if (j == 0) {
          _messages.removeAt(0);
          _messages.insert(i > 0 ? i : 0, msg);
        }
        _pinFlashId = null;
      });
    });
  }

  Future<void> _openForward(_Msg msg) async {
    final backend = VibeBackend.instance;
    final me = backend.myProfileId;
    if (me == null) return;
    List<VibeChat> chats;
    try {
      chats = await backend.listChats();
    } catch (_) {
      _snack('Сервер недоступен');
      return;
    }
    if (!mounted) return;
    final targets = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => ForwardPickerScreen(
          chats: chats.where((c) => c.id != _chatId).toList(),
        ),
      ),
    );
    final ids = targets;
    if (ids == null || ids.isEmpty || !mounted) return;
    var ok = 0;
    for (final chatId in ids) {
      try {
        final m = await backend.forwardMessage(chatId, _msgToBackend(msg));
        if (m != null) ok++;
      } catch (_) {}
    }
    if (!mounted) return;
    _snack(ok > 0 ? 'Переслано' : 'Не удалось переслать');
  }

  Future<void> _openUrl(String raw) async {
    final uri = raw.startsWith('www.')
        ? Uri.parse('https://$raw')
        : Uri.parse(raw);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack('Не удалось открыть ссылку');
  }

  VibeMessage _msgToBackend(_Msg m) {
    return VibeMessage(
      id: m.serverId ?? '',
      chatId: _chatId,
      senderId: '',
      senderName: '',
      senderAvatar: null,
      text: m.type == _MsgType.text ? m.text : null,
      voicePath: m.voiceUrl,
      photoPath: m.photoUrl,
      videoPath: m.videoUrl,
      created: DateTime.now(),
      incoming: m.incoming,
      status: MsgStatus.sent,
      stickerEmoji: m.stickerEmoji,
      forwardedFrom: m.forwardedFrom,
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          VibeSpacing.md,
          VibeSpacing.sm,
          VibeSpacing.md,
          VibeSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_editingIdx != null)
              Padding(
                padding: const EdgeInsets.only(bottom: VibeSpacing.sm),
                child: _ReplyPanel(
                  author: 'Редактирование',
                  text: _messages[_editingIdx!].text,
                  onClose: () {
                    setState(() {
                      _editingIdx = null;
                      _input.clear();
                    });
                  },
                ),
              ),
            if (_replyTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: VibeSpacing.sm),
                child: _ReplyPanel(
                  author: _messages[_replyTo!].incoming
                      ? widget.chat.title
                      : 'Вы',
                  text: _messages[_replyTo!].text,
                  onClose: () => setState(() => _replyTo = null),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTapDown: _onCamTapDown,
                  onTapUp: _onCamTapUp,
                  onTapCancel: _onCamTapCancel,
                  onVerticalDragUpdate: _onCamDragUpdate,
                  onVerticalDragEnd: _onCamDragEnd,
                  onHorizontalDragUpdate: (d) {
                    if (_videoRolling && !_videoLocked && d.delta.dx < -0.1) {
                      _cancelVideoRoll();
                    }
                  },
                  onTap: () {
                    // Простой тап (без удержания) — открыть рекордер экраном.
                    if (_videoRolling || _videoLocked) return;
                    if (_justHeld) {
                      _justHeld = false;
                      return;
                    }
                    _openVideoRecorder();
                  },
                  child: AnimatedContainer(
                    duration: VibeAnimations.pulse,
                    width: _videoRolling ? 54 : 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _videoRolling
                          ? VibeColors.error.withValues(alpha: 0.85)
                          : context.isDarkMode
                              ? context.vibeSurfaceVariant
                              : Colors.white,
                      shape: BoxShape.circle,
                      border: _videoRolling
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2,
                            )
                          : context.isDarkMode
                              ? null
                              : Border.all(color: const Color(0x1F1C1B22)),
                    ),
                    child: Icon(
                      Icons.videocam_rounded,
                      size: 20,
                      color: _videoRolling
                          ? Colors.white
                          : context.vibePrimary,
                    ),
                  ),
                ),
                const SizedBox(width: VibeSpacing.sm),
                IconButton(
                  onPressed: _recording || _videoRolling
                      ? null
                      : () => _openAttachmentMenu(context),
                  icon: const Icon(Icons.attach_file_rounded),
                  color: context.vibePrimary,
                  tooltip: 'Вложение',
                ),
                Expanded(
                  child: _videoRolling
                      ? _VideoRollPill(
                          cam: _camCtrl,
                          seconds: _videoSeconds,
                          locked: _videoLocked,
                          onCancel: _cancelVideoRoll,
                          onSend: () => _finalizeVideo(send: true),
                        )
                      : _recording
                          ? _RollingPill(
                              seconds: _recordSeconds,
                              locked: _micLocked,
                              onCancel: _cancelRecording,
                              onSend: _stopRecording,
                            )
                          : Container(
                          constraints: const BoxConstraints(
                            minHeight: VibeSizes.inputHeight,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: VibeSpacing.lg,
                          ),
                          decoration: BoxDecoration(
                            color: context.isDarkMode
                                ? context.vibeSurfaceVariant
                                : Colors.white,
                            borderRadius: BorderRadius.circular(
                              VibeRadius.xl,
                            ),
                            border: Border.all(
                              color: context.isDarkMode
                                  ? VibeColors.borderDark.withValues(alpha: 0.6)
                                  : const Color(0x1F1C1B22),
                            ),
                            boxShadow: context.isDarkMode
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: TextField(
                            controller: _input,
                            maxLines: 5,
                            minLines: 1,
                            onChanged: (_) {
                              setState(() {});
                              _notifyTyping();
                            },
                            style: VibeTypography.body.copyWith(
                              color: context.vibeTextPrimary,
                            ),
                            cursorColor: context.vibePrimary,
                            decoration: InputDecoration(
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              hintText: 'Сообщение…',
                              hintStyle: VibeTypography.body.copyWith(
                                color: context.vibeTextTertiary,
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: VibeSpacing.sm),
                IconButton(
                  onPressed: () => setState(() {
                    _showEmojiPanel = !_showEmojiPanel;
                  }),
                  icon: Icon(
                    _showEmojiPanel
                        ? Icons.keyboard_rounded
                        : Icons.emoji_emotions_outlined,
                  ),
                  color: context.vibePrimary,
                  tooltip: 'Эмодзи и стикеры',
                ),
                _SendButton(
                  canSend: _input.text.trim().isNotEmpty,
                  recording: _recording,
                  locked: _micLocked,
                  onMicTap: _startRecording,
                  onSend: _recording && _micLocked ? _stopRecording : _send,
                  onRelease: _stopRecording,
                  onLock: _lockMic,
                  onUnlock: _unlockMic,
                  onCancel: _cancelRecording,
                ),
              ],
            ),
            if (_showEmojiPanel)
              EmojiStickerPanel(
                onEmoji: (e) => setState(() => _input.text += e),
                onSticker: _sendSticker,
              ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    HapticFeedback.lightImpact(); // ЛЕГКОЕ ВИБРО ПРИ УВЕДОМЛЕНИИ
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Видеокружок: inline-запись (удержание камеры, как в TG) ───

  Future<bool> _ensureCam() async {
    if (_camCtrl != null) return _camReady;
    try {
      final cams = await availableCameras();
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final c = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return false;
      }
      setState(() {
        _camCtrl = c;
        _camReady = true;
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onCamTapDown(TapDownDetails d) {
    if (_camCtrl == null) return;
    if (_recording || _videoRolling || _videoLocked) return;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 180), () async {
      if (!mounted || _videoRolling) return;
      HapticFeedback.mediumImpact();
      setState(() => _justHeld = true);
      await _startVideoRoll();
    });
  }

  void _onCamTapUp(TapUpDetails d) {
    _holdTimer?.cancel();
    if (_videoRolling && !_videoLocked) {
      _finalizeVideo(send: true);
    }
  }

  void _onCamTapCancel() {
    _holdTimer?.cancel();
  }

  Future<void> _startVideoRoll() async {
    if (!await _ensureCam() || _camCtrl == null) return;
    final cam = _camCtrl!;
    if (!cam.value.isInitialized) return;
    try {
      await cam.startVideoRecording();
    } catch (_) {
      _snack('Не удалось начать запись');
      return;
    }
    setState(() {
      _videoRolling = true;
      _videoLocked = false;
      _videoSeconds = 0;
    });
    _videoTimer?.cancel();
    _videoTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _videoSeconds++);
      if (_videoSeconds >= 60) {
        t.cancel();
        _finalizeVideo(send: true);
      }
    });
  }

  void _onCamDragUpdate(DragUpdateDetails d) {
    setState(() => _videoDragDy += d.delta.dy);
  }

  void _onCamDragEnd(DragEndDetails d) {
    if (!_videoRolling) return;
    if (_videoDragDy < -40) {
      HapticFeedback.selectionClick();
      setState(() => _videoLocked = true);
    } else if (_videoDragDy > 56 && _videoLocked) {
      HapticFeedback.selectionClick();
      setState(() => _videoLocked = false);
    } else if (!_videoLocked) {
      _finalizeVideo(send: true);
    }
    setState(() => _videoDragDy = 0);
  }

  Future<void> _finalizeVideo({required bool send}) async {
    _videoTimer?.cancel();
    final cam = _camCtrl;
    if (cam == null || !_videoRolling) return;
    XFile? xf;
    try {
      xf = await cam.stopVideoRecording();
    } catch (_) {}
    setState(() {
      _videoRolling = false;
      _videoLocked = false;
    });
    if (!mounted) return;
    if (xf == null || _videoSeconds < 1) {
      if (xf != null) {
        try {
          File(xf.path).delete();
        } catch (_) {}
      }
      if (send) _snack('Слишком короткая запись');
      return;
    }
    if (!send) {
      try {
        File(xf.path).delete();
      } catch (_) {}
      return;
    }
    final file = File(xf.path);
    final localId = 'c${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _messages.insert(0, _Msg( // Вставляем в начало (низ)
        type: _MsgType.video,
        incoming: false,
        time: _now(),
        videoPath: file.path,
        status: MsgStatus.sending,
        localId: localId,
        date: DateTime.now(),
      ));
    });
    try {
      await VibeBackend.instance
          .sendVideo(_chatId, file, localId: localId, localPath: file.path);
    } catch (_) {
      _snack('Не удалось отправить видеокружок');
    }
  }

  Future<void> _cancelVideoRoll() async {
    _videoTimer?.cancel();
    final cam = _camCtrl;
    if (cam != null && _videoRolling) {
      try {
        final xf = await cam.stopVideoRecording();
        try {
          File(xf.path).delete();
        } catch (_) {}      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _videoRolling = false;
        _videoLocked = false;
      });
    }
  }

  Future<void> _openVideoRecorder() async {
    if (_recording) return;
    final res = await Navigator.of(context).push<VideoRoundResult>(
      MaterialPageRoute(builder: (_) => const VideoRoundRecorderScreen()),
    );
    if (res == null || !mounted) return;
    final localId = 'c${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _messages.insert(0, _Msg( // Вставляем в начало (низ)
        type: _MsgType.video,
        incoming: false,
        time: _now(),
        videoPath: res.file.path,
        status: MsgStatus.sending,
        localId: localId,
        date: DateTime.now(),
      ));
    });
    try {
      await VibeBackend.instance
          .sendVideo(_chatId, res.file, localId: localId, localPath: res.file.path);
    } catch (_) {
      _snack('Не удалось отправить видеокружок');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    super.key,
    required this.msg,
    required this.onHeart,
    required this.onLongPress,
    required this.onReply,
    required this.onOpenUrl,
    required this.scrollController,
    this.player,
    this.highlight = false,
  });

  final _Msg msg;
  final VoidCallback onHeart;
  final VoidCallback onLongPress;
  final VoidCallback onReply;

  /// Открытие URL из текста сообщения (в браузере).
  final ValueChanged<String> onOpenUrl;
  final ScrollController scrollController;
  final AudioPlayer? player;

  /// Подсветка при прыжке к закреплённому сообщению (как в Telegram).
  final bool highlight;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spark;
  bool _sparkVisible = false;

  // Для динамического градиента
  final GlobalKey _bubbleKey = GlobalKey();
  double _yPos = 0;

  // Для свайпа ответа
  double _dragOffset = 0;
  bool _triggeredReply = false;

  @override
  void initState() {
    super.initState();
    _spark = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    widget.scrollController.addListener(_updateY);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_updateY);
    _spark.dispose();
    super.dispose();
  }

  void _updateY() {
    if (!mounted) return;
    final box = _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final pos = box.localToGlobal(Offset.zero).dy;
      if ((pos - _yPos).abs() > 2) {
        setState(() => _yPos = pos);
      }
    }
  }

  void _onDoubleTap() {
    HapticFeedback.vibrate(); // ИСПРАВЛЕНО: Стандартный мощный отклик
    widget.onHeart();
    setState(() => _sparkVisible = true);
    _spark.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _sparkVisible = false);
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (d.delta.dx < 0) {
      setState(() {
        _dragOffset += d.delta.dx * 0.4; // Сопротивление свайпу
        if (_dragOffset < -60 && !_triggeredReply) {
          _triggeredReply = true;
          HapticFeedback.mediumImpact();
        }
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    if (_triggeredReply) {
      widget.onReply();
    }
    setState(() {
      _dragOffset = 0;
      _triggeredReply = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final isIncoming = msg.incoming;
    final r = SettingsService.instance.bubbleRadius.clamp(4.0, 24.0);

    // Расчет динамического цвета для исходящих
    final screenHeight = MediaQuery.of(context).size.height;
    final progress = (_yPos / screenHeight).clamp(0.0, 1.0);
    
    // Плавный перелив от основного фиолетового к более насыщенному
    final bubbleColor = isIncoming
        ? (context.isDarkMode ? const Color(0xFF19172C) : Colors.white)
        : Color.lerp(
            const Color(0xFF8B4DFF), 
            const Color(0xFF5B21B6), 
            progress
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.translationValues(_dragOffset, 0, 0),
      curve: Curves.easeOutCubic,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Иконка ответа, которая появляется при свайпе
          if (_dragOffset < 0)
            Positioned(
              right: -40,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: (_dragOffset.abs() / 60).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.vibePrimary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.reply_rounded,
                      color: _triggeredReply ? context.vibePrimary : context.vibeTextSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: isIncoming ? MainAxisAlignment.start : MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isIncoming) const Spacer(flex: 2),
                GestureDetector(
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  onDoubleTap: _onDoubleTap,
                  onLongPress: () {
                    HapticFeedback.selectionClick();
                    widget.onLongPress();
                  },
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    child: Stack(
                      key: _bubbleKey,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: msg.type == _MsgType.photo || msg.stickerEmoji != null
                              ? EdgeInsets.zero
                              : const EdgeInsets.symmetric(
                                  horizontal: VibeSpacing.md,
                                  vertical: VibeSpacing.sm,
                                ),
                          decoration: BoxDecoration(
                            color: widget.highlight
                                ? VibeColors.workBlue.withValues(alpha: 0.35)
                                : bubbleColor,
                            border: (!context.isDarkMode && isIncoming)
                                ? Border.all(
                                    color: const Color(0x1F1C1B22),
                                  )
                                : null,
                            boxShadow: context.isDarkMode
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(r),
                              topRight: Radius.circular(r),
                              bottomLeft: Radius.circular(isIncoming ? math.min(r, 4) : r),
                              bottomRight: Radius.circular(isIncoming ? r : math.min(r, 4)),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _bubbleContent(context, msg, isIncoming),
                        ),
                        if (msg.reactions.isNotEmpty)
                          Positioned(
                            right: isIncoming ? 8 : null,
                            left: isIncoming ? null : 8,
                            bottom: -12,
                            child: _ReactionChip(reactions: msg.reactions),
                          ),
                        if (_sparkVisible)
                          Positioned(
                            right: 4,
                            top: -6,
                            child: IgnorePointer(
                              child: _SparkBurst(controller: _spark),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isIncoming) const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubbleContent(
    BuildContext context,
    _Msg msg,
    bool isIncoming,
  ) {
    if (msg.stickerEmoji != null) {
      return _StickerBubble(emoji: msg.stickerEmoji!, incoming: isIncoming);
    }
    if (msg.type == _MsgType.photo) {
      return _PhotoBubble(msg: msg, incoming: isIncoming);
    }
    if (msg.type == _MsgType.voice) {
      final p = widget.player;
      if (p != null) {
        return _VoiceBubble(msg: msg, incoming: isIncoming, player: p);
      }
      return _VoiceBubble(msg: msg, incoming: isIncoming, player: AudioPlayer());
    }
    if (msg.type == _MsgType.video) {
      return _VideoRoundBubble(msg: msg, incoming: isIncoming);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (msg.replyText != null) _ReplyQuote(context, msg, isIncoming),
        if (msg.forwardedFrom != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.reply_all_rounded,
                  size: 13,
                  color: isIncoming
                      ? context.vibePrimary
                      : const Color(0xFFB7A7FF),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Переслано от ${msg.forwardedFrom}',
                    overflow: TextOverflow.ellipsis,
                    style: VibeTypography.caption.copyWith(
                      color: isIncoming
                          ? context.vibePrimary
                          : const Color(0xFFB7A7FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Text.rich(
          TextSpan(
            children: buildLinkSpans(
              msg.text,
              isIncoming
                  ? context.vibePrimary
                  : const Color(0xFFC9B4FF),
              widget.onOpenUrl,
            ),
            style: VibeTypography.body.copyWith(
              fontSize: 15 + SettingsService.instance.fontSizeDelta,
              color: isIncoming ? context.vibeTextPrimary : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Spacer(),
            if (msg.edited)
              Text(
                'изменено',
                style: VibeTypography.caption.copyWith(
                  color: isIncoming
                      ? (context.isDarkMode
                          ? context.vibeTextTertiary
                          : const Color(0xFF5A5766))
                      : Colors.white54,
                  fontSize: 9,
                ),
              ),
            if (msg.edited) const SizedBox(width: 4),
            Text(
              msg.time,
              style: VibeTypography.caption.copyWith(
                color: isIncoming
                    ? (context.isDarkMode
                        ? context.vibeTextTertiary
                        : const Color(0xFF5A5766))
                    : Colors.white70,
                fontSize: 10,
              ),
            ),
            if (!isIncoming) ...[
              const SizedBox(width: 4),
              _statusTick(msg.status),
            ],
          ],
        ),
      ],
    );
  }
}

/// Галочки статуса: часики → ✓ → ✓✓ → синие ✓✓ (как в Telegram).
Widget _statusTick(MsgStatus status) {
  switch (status) {
    case MsgStatus.sending:
      return const Icon(Icons.schedule_rounded, size: 14, color: Colors.white38);
    case MsgStatus.sent:
      return const Icon(Icons.check_rounded, size: 14, color: Colors.white70);
    case MsgStatus.delivered:
      return const Icon(Icons.done_all_rounded, size: 14, color: Colors.white70);
    case MsgStatus.read:
      return const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF8AB4F8));
    case MsgStatus.failed:
      return const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFFF6B6B));
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote(this.context, this.msg, this.isIncoming);

  final BuildContext context;
  final _Msg msg;
  final bool isIncoming;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isIncoming ? context.vibePrimary : Colors.white,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg.replyAuthor ?? '',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isIncoming
                  ? context.vibePrimary
                  : Colors.white,
            ),
          ),
          Text(
            msg.replyText ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isIncoming
                  ? context.vibeTextSecondary
                  : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _StickerBubble extends StatelessWidget {
  const _StickerBubble({required this.emoji, required this.incoming});

  final String emoji;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Container(
        width: 128,
        height: 128,
        decoration: BoxDecoration(
          color: context.isDarkMode
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(VibeRadius.card),
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 64, height: 1),
          ),
        ),
      ),
    );
  }
}

class _PhotoBubble extends StatelessWidget {
  const _PhotoBubble({required this.msg, required this.incoming});

  final _Msg msg;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    final url = msg.photoUrl;
    if (url != null && url.isNotEmpty) {
      return _NetworkPhotoBubble(url: url, time: msg.time, incoming: incoming);
    }
    const palette = [
      Color(0xFF8B5CF6),
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF6366F1),
    ];
    final c1 = palette[msg.photoSeed % palette.length];
    final c2 = palette[(msg.photoSeed + 2) % palette.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 220,
          height: 150,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c1, c2],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                bottom: -18,
                child: Icon(
                  Icons.water_drop_rounded,
                  size: 90,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              Positioned(
                left: 12,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Фото · демо',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const Center(
                child: Icon(
                  Icons.image_rounded,
                  size: 42,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shield,
              size: 11,
              color: VibeColors.success,
            ),
            const SizedBox(width: 3),
            Text(
              msg.time,
              style: VibeTypography.caption.copyWith(
                color: incoming
                    ? context.vibeTextTertiary
                    : Colors.white70,
                fontSize: 11,
              ),
            ),
            if (!incoming) ...[
              const SizedBox(width: 3),
              const Icon(
                Icons.done_all_rounded,
                size: 13,
                color: Colors.white70,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _NetworkPhotoBubble extends StatelessWidget {
  const _NetworkPhotoBubble({
    required this.url,
    required this.time,
    required this.incoming,
  });

  final String url;
  final String time;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 220,
            height: 150,
            child: VibeNetImage(
              source: url,
              errorBuilder: (_, _, _) => Container(
                color: Colors.black26,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white38,
                  size: 40,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shield,
              size: 11,
              color: VibeColors.success,
            ),
            const SizedBox(width: 3),
            Text(
              time,
              style: VibeTypography.caption.copyWith(
                color: incoming
                    ? context.vibeTextTertiary
                    : Colors.white70,
                fontSize: 11,
              ),
            ),
            if (!incoming) ...[
              const SizedBox(width: 3),
              const Icon(
                Icons.done_all_rounded,
                size: 13,
                color: Colors.white70,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _VoiceBubble extends StatefulWidget {
  const _VoiceBubble({
    required this.msg,
    required this.incoming,
    required this.player,
  });

  final _Msg msg;
  final bool incoming;
  final AudioPlayer player;

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _progress;
  StreamSubscription<Duration>? _sub;
  Duration _pos = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: Duration(
        seconds: widget.msg.voiceSeconds == 0
            ? 1
            : widget.msg.voiceSeconds,
      ),
      value: 0,
    );
    _sub = widget.player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _pos = pos);
    });
    widget.player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _pos = Duration.zero;
        _progress.value = 0;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final localPath = widget.msg.voicePath;
    var url = widget.msg.voiceUrl;
    if ((localPath == null || localPath.isEmpty) &&
        (url == null || url.isEmpty)) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Нет аудиофайла')));
      return;
    }
    setState(() => _playing = !_playing);
    if (_playing) {
      if (widget.player.state != PlayerState.playing) {
        await widget.player.stop();
        if (localPath != null && localPath.isNotEmpty) {
          await widget.player.play(DeviceFileSource(localPath));
        } else {
          final signed = await VibeBackend.instance.mediaUrl(url);
          if (signed == null) {
            setState(() => _playing = false);
            return;
          }
          await widget.player.play(UrlSource(signed));
        }
      } else {
        await widget.player.resume();
      }
      _progress
        ..duration = Duration(seconds: widget.msg.voiceSeconds)
        ..forward();
    } else {
      await widget.player.pause();
      _progress.stop();
    }
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    final total = widget.msg.voiceSeconds;
    final rest = ((total - s)).clamp(0, total);
    return '${rest % 60}с';
  }

  @override
  Widget build(BuildContext context) {
    final isIncoming = widget.incoming;
    final isExternal =
        widget.msg.voicePath != null || widget.msg.voiceUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _toggle,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: AnimatedSwitcher(
                duration: VibeAnimations.fadeIn,
                child: Icon(
                  _playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  key: ValueKey(_playing),
                  color: isIncoming ? context.vibePrimary : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _progress,
            builder: (context, _) {
              return SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress.value,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(
                      isIncoming ? context.vibePrimary : Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            _fmt(_pos),
            style: VibeTypography.caption.copyWith(
              color: isIncoming
                  ? context.vibeTextSecondary
                  : Colors.white70,
              fontSize: 11,
            ),
          ),
          if (!isExternal) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.mic_none_rounded,
              size: 14,
              color: Colors.white38,
            ),
          ],
        ],
      ),
      const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shield,
              size: 11,
              color: VibeColors.success,
            ),
            const SizedBox(width: 3),
            Text(
              widget.msg.time,
              style: VibeTypography.caption.copyWith(
                color: isIncoming
                    ? context.vibeTextTertiary
                    : Colors.white70,
                fontSize: 11,
              ),
            ),
            if (!isIncoming) ...[
              const SizedBox(width: 3),
              const Icon(
                Icons.done_all_rounded,
                size: 13,
                color: Colors.white70,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.reactions});

  final List<_Reaction> reactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: context.vibeSurfaceHigh,
        borderRadius: BorderRadius.circular(VibeRadius.badge),
        border: Border.all(color: context.vibeDivider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in reactions) ...[
            Text(r.emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 2),
            Text(
              '${r.count}',
              style: VibeTypography.label.copyWith(
                color: context.vibePrimary,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _SparkBurst extends StatelessWidget {
  const _SparkBurst({required this.controller});

  final AnimationController controller;

  static const _angles = [0.0, 0.7, 1.4, 2.1, 2.8, 3.5, 4.2, 4.9];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = Curves.easeOut.transform(controller.value);
        final fade = 1 - controller.value;
        return SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final (_, angle) in _angles.indexed)
                Transform.translate(
                  offset: Offset(
                    math.cos(angle) * 26 * t,
                    math.sin(angle) * 26 * t,
                  ),
                  child: Opacity(
                    opacity: fade,
                    child: Text(
                      '✦',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color.lerp(
                          context.vibePrimary,
                          Colors.white,
                          0.45,
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.scale(
                scale: 1 + 0.35 * Curves.easeOutBack.transform(t),
                child: const Text('❤️', style: TextStyle(fontSize: 26)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.canSend,
    required this.recording,
    required this.locked,
    required this.onMicTap,
    required this.onSend,
    required this.onRelease,
    required this.onLock,
    required this.onUnlock,
    required this.onCancel,
  });

  final bool canSend;
  final bool recording;
  final bool locked;
  final VoidCallback onMicTap;
  final VoidCallback onSend;
  final VoidCallback onRelease;
  final VoidCallback onLock;
  final VoidCallback onUnlock;
  final VoidCallback onCancel;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  AnimationController get _pulseController {
    return _pulse ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  double _dragDy = 0;
  double _dragDx = 0;
  Timer? _holdTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulse?.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragDy += d.delta.dy;
      _dragDx += d.delta.dx;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (widget.recording) {
      if (_dragDx < -70) {
        // Свайп влево — отмена записи (как в TG: перетащил на корзину).
        HapticFeedback.heavyImpact(); // ВИБРО ПРИ ОТМЕНЕ
        widget.onCancel();
      } else if (_dragDy < -40) {
        HapticFeedback.selectionClick(); // ВИБРО ПРИ ЗАМОЧКЕ
        widget.onLock();
      } else if (_dragDy > 56 && widget.locked) {
        HapticFeedback.selectionClick();
        widget.onUnlock();
      } else if (!widget.locked) {
        widget.onRelease();
      }
    }
    setState(() {
      _dragDy = 0;
      _dragDx = 0;
    });
  }

  void _onTapDown(TapDownDetails d) {
    if (widget.canSend || widget.recording || widget.locked) return;
    _holdTimer?.cancel();
    _holdTimer = Timer(
      const Duration(milliseconds: 220),
      () {
        if (mounted && !widget.recording) widget.onMicTap();
      },
    );
  }

  void _onTapUp(TapUpDetails d) {
    _holdTimer?.cancel();
    if (widget.recording && !widget.locked) widget.onRelease();
  }

  void _onTapCancel() {
    _holdTimer?.cancel();
  }

  void _onTap() {
    HapticFeedback.lightImpact(); // КЛИК ПО КНОПКЕ
    if (widget.canSend) {
      widget.onSend();
    } else if (widget.recording && widget.locked) {
      widget.onSend();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stretch = widget.recording && !widget.locked
        ? (1 + 0.18 * _pulseController.value * (0.6 + 0.4 * ((now / 130) % 1)))
        : (widget.recording && widget.locked ? 1.0 : 1.0);

    return GestureDetector(
      onTap: _onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedContainer(
        duration: VibeAnimations.pulse,
        curve: VibeAnimations.springy,
        width: 48,
        height: 48,
        transform: Matrix4.diagonal3Values(stretch, stretch, 1),
        decoration: BoxDecoration(
          color: widget.canSend
              ? context.vibePrimary
              : (widget.recording
                  ? (widget.locked
                      ? context.vibePrimary
                      : VibeColors.warning.withValues(alpha: 0.16))
                  : context.vibeSurfaceVariant),
          shape: BoxShape.circle,
          border: widget.recording && !widget.locked
              ? Border.all(
                  color: VibeColors.warning.withValues(alpha: 0.5),
                  width: 2,
                )
              : null,
        ),
        child: AnimatedSwitcher(
          duration: VibeAnimations.fadeIn,
          child: widget.canSend
              ? const Icon(
                  Icons.send_rounded,
                  key: ValueKey('send'),
                  color: Colors.white,
                  size: 22,
                )
              : widget.locked
                  ? const Icon(
                      Icons.lock_rounded,
                      key: ValueKey('lock'),
                      color: Colors.white,
                      size: 22,
                    )
                  : Icon(
                      Icons.mic_rounded,
                      key: const ValueKey('mic'),
                      color: widget.recording ? VibeColors.warning : context.vibePrimary,
                      size: 22,
                    ),
        ),
      ),
    );
  }
  }

class _ReplyPanel extends StatelessWidget {
  const _ReplyPanel({
    required this.author,
    required this.text,
    required this.onClose,
  });

  final String author;
  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        VibeSpacing.md,
        VibeSpacing.sm,
        VibeSpacing.xs,
        VibeSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.vibeSurfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: context.vibePrimary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ответ $author',
                  style: VibeTypography.label.copyWith(
                    color: context.vibePrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VibeTypography.caption.copyWith(
                    color: context.vibeTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: context.vibeTextSecondary,
            tooltip: 'Отменить ответ',
          ),
        ],
      ),
    );
  }
}

class _RollingPill extends StatelessWidget {
  const _RollingPill({
    required this.seconds,
    required this.locked,
    required this.onCancel,
    required this.onSend,
  });

  final int seconds;
  final bool locked;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: VibeSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.vibeSurfaceVariant,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: (locked ? context.vibePrimary : VibeColors.warning)
              .withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          const _EqualizerWave(color: VibeColors.warning),
          const SizedBox(width: VibeSpacing.md),
          Text(
            '0:${seconds.toString().padLeft(2, '0')}',
            style: VibeTypography.bodyMedium.copyWith(
              color: context.vibeTextPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: VibeSpacing.sm),
          Expanded(
            child: Text(
              locked
                  ? 'Зафиксировано — тап по кнопке: отправить'
                  : 'Свайп вверх — зафиксировать · влево — отменить',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VibeTypography.caption.copyWith(
                color: context.vibeTextSecondary,
              ),
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 22),
            color: VibeColors.error,
            tooltip: 'Отмена',
          ),
          if (locked)
            IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded, size: 20),
              color: context.vibePrimary,
              tooltip: 'Отправить',
            ),
        ],
      ),
    );
  }
}

class _VideoRollPill extends StatelessWidget {
  const _VideoRollPill({
    required this.cam,
    required this.seconds,
    required this.locked,
    required this.onCancel,
    required this.onSend,
  });

  final CameraController? cam;
  final int seconds;
  final bool locked;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.md),
      decoration: BoxDecoration(
        color: context.vibeSurfaceVariant,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: (locked ? context.vibePrimary : VibeColors.warning)
              .withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Круглый предпросмотр камеры во время записи (как в TG).
          if (cam != null && cam!.value.isInitialized)
            SizedBox(
              width: 38,
              height: 38,
              child: ClipOval(
                child: CameraPreview(
                  cam!,
                  child: const SizedBox.shrink(),
                ),
              ),
            )
          else
            const SizedBox(width: 38, height: 38),
          const SizedBox(width: VibeSpacing.sm),
          Text(
            '0:${seconds.toString().padLeft(2, '0')}',
            style: VibeTypography.bodyMedium.copyWith(
              color: context.vibeTextPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: VibeSpacing.sm),
          Expanded(
            child: Text(
              locked ? 'Зафиксировано' : 'Свайп вверх — зафиксировать · влево — отмена',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VibeTypography.caption.copyWith(
                color: context.vibeTextSecondary,
              ),
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 22),
            color: VibeColors.error,
            tooltip: 'Отмена',
          ),
          if (locked)
            IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded, size: 20),
              color: context.vibePrimary,
              tooltip: 'Отправить',
            ),
        ],
      ),
    );
  }
}

/// Видеокружок — круглое видео с автовоспроизведением по кругу (как в ТГ).
class _VideoRoundBubble extends StatefulWidget {
  const _VideoRoundBubble({required this.msg, required this.incoming});

  final _Msg msg;
  final bool incoming;

  @override
  State<_VideoRoundBubble> createState() => _VideoRoundBubbleState();
}

class _VideoRoundBubbleState extends State<_VideoRoundBubble> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final local = widget.msg.videoPath;
    final url = await VibeBackend.instance.mediaUrl(widget.msg.videoUrl);
    VideoPlayerController? c;
    if (local != null && local.isNotEmpty) {
      c = VideoPlayerController.file(File(local));
    } else if (url != null) {
      c = VideoPlayerController.networkUrl(Uri.parse(url));
    }
    if (c == null) return;
    try {
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.play();
      setState(() => _controller = c);
    } catch (_) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: ClipOval(
        child: _controller == null
            ? const ColoredBox(
                color: VibeColors.surfaceDark,
                child: Center(
                  child: Icon(
                    Icons.videocam_rounded,
                    color: VibeColors.textTertiaryDark,
                  ),
                ),
              )
            : FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
      ),
    );
  }
}

class _EqualizerWave extends StatefulWidget {
  const _EqualizerWave({required this.color});

  final Color color;

  @override
  State<_EqualizerWave> createState() => _EqualizerWaveState();
}

class _EqualizerWaveState extends State<_EqualizerWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(5, (i) {
            final phase = (_controller.value * 3.14 + i * 1.1) % 3.14;
            final h = 6 + 14 * (0.5 + 0.5 * math.sin(phase));
            return Container(
              width: 3,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

class _AttachmentItem extends StatelessWidget {
  const _AttachmentItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.35), color],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: VibeTypography.caption.copyWith(
              color: context.vibeTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.vibeSurfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: context.vibePrimary),
      title: Text(
        label,
        style: VibeTypography.body.copyWith(
          color: context.vibeTextPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Стеклянная пилюля шапки чата — как в Telegram: одна плавающая капсула.
/// Использует стекло темы, поэтому дружит и со светлой, и с тёмной темой.
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VibeSpacing.sm,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: context.vibeGlass.withValues(
            alpha: context.isDarkMode ? 0.35 : 0.65,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0x1A1C1B22),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Одна строка листа выбора звонка.
class _SheetCallTile extends StatelessWidget {
  const _SheetCallTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: VibeTypography.body.copyWith(
          fontWeight: FontWeight.w600,
          color: context.vibeTextPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: VibeTypography.caption.copyWith(
          color: context.vibeTextTertiary,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Меню чата как в Telegram: столбец «Уведомления» открывает подраздел,
/// из него — «Выключить на время» со списком длительностей. А кнопка
/// «Не беспокоить» в главном столбце работает сразу.
class _ChatMenuSheet extends StatefulWidget {
  const _ChatMenuSheet({
    required this.chat,
    required this.onSnack,
    this.onTapSearch,
  });

  final VibeChat chat;
  final ValueChanged<String> onSnack;
  final VoidCallback? onTapSearch;

  @override
  State<_ChatMenuSheet> createState() => _ChatMenuSheetState();
}

class _ChatMenuSheetState extends State<_ChatMenuSheet> {
  /// 0 — главный столбец, 1 — «Уведомления», 2 — «Выключить на время».
  int _level = 0;

  late bool _muted;

  @override
  void initState() {
    super.initState();
    _muted = SettingsService.instance.mutedChats.contains(widget.chat.id);
  }

  void _setMuted(bool value) {
    setState(() => _muted = value);
    final ids = SettingsService.instance.mutedChats.toList();
    if (value && !ids.contains(widget.chat.id)) ids.add(widget.chat.id);
    if (!value) ids.remove(widget.chat.id);
    SettingsService.instance.setMutedChats(ids);
    // Облачный DND (как в TG): muted_until на сервере.
    VibeBackend.instance.setChatMuted(widget.chat.id, muted: value);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          VibeSpacing.lg,
          0,
          VibeSpacing.lg,
          VibeSpacing.lg,
        ),
        child: AnimatedSize(
          duration: VibeAnimations.fast,
          curve: Curves.easeOut,
          child: _level == 0
              ? _buildMainColumn(context)
              : _level == 1
                  ? _buildNotificationsColumn(context)
                  : _buildMuteForAWhileColumn(context),
        ),
      ),
    );
  }

  Widget _buildMainColumn(BuildContext context) {
    final chat = widget.chat;
    final isGroup = chat.kind == 'group';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            VibeAvatar(
              name: chat.title,
              size: VibeSizes.avatarMd,
              online: chat.peerOnline,
              photoUrl: chat.peerAvatar,
            ),
            const SizedBox(width: VibeSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.title,
                    style: VibeTypography.subtitle.copyWith(
                      color: context.vibeTextPrimary,
                    ),
                  ),
                  Text(
                    isGroup
                        ? 'Группа'
                        : (chat.peerOnline
                            ? 'в сети'
                            : (chat.peerLastSeen != null
                                ? 'был(а) в сети '
                                    '${VibeBackend.formatTime(chat.peerLastSeen)}'
                                : 'был(а) недавно')),
                    style: VibeTypography.caption.copyWith(
                      color: chat.peerOnline
                          ? VibeColors.success
                          : context.vibeTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: VibeSpacing.md),
        const Divider(height: 1),
        const SizedBox(height: VibeSpacing.xs),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.notifications_none_rounded,
              color: context.vibePrimary),
          title: const Text('Уведомления'),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () => setState(() => _level = 1),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            _muted ? Icons.volume_off_rounded : Icons.volume_up_outlined,
            color: _muted ? VibeColors.error : context.vibePrimary,
          ),
          title: Text(_muted ? 'Звук выключен' : 'Не беспокоить'),
          trailing: Switch(
            value: _muted,
            onChanged: _setMuted,
          ),
          onTap: () => _setMuted(!_muted),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.search_rounded, color: context.vibePrimary),
          title: const Text('Поиск в чате'),
          onTap: () {
            Navigator.of(context).pop();
            widget.onTapSearch?.call();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline_rounded,
              color: context.vibePrimary),
          title: const Text('Сведения о чате'),
          onTap: () {
            Navigator.of(context).pop();
            widget.onSnack('Сведения о чате — в v2.0');
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_outline_rounded,
              color: context.vibePrimary),
          title: const Text('Очистить историю'),
          onTap: () {
            Navigator.of(context).pop();
            widget.onSnack('Очистить историю — в v2.0');
          },
        ),
      ],
    );
  }

  Widget _buildNotificationsColumn(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.arrow_back_rounded, size: 20),
          title: const Text('Уведомления'),
          onTap: () => setState(() => _level = 0),
        ),
        const Divider(height: 1),
        const SizedBox(height: VibeSpacing.xs),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            _muted ? Icons.volume_off_rounded : Icons.volume_up_outlined,
            color: context.vibePrimary,
          ),
          title: const Text('Выключить звук'),
          trailing: Switch(value: _muted, onChanged: _setMuted),
          onTap: () => _setMuted(!_muted),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.timer_outlined, color: context.vibePrimary),
          title: const Text('Выключить на время'),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () => setState(() => _level = 2),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.tune_rounded, color: context.vibePrimary),
          title: const Text('Настроить'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsSettingsScreen(),
              ),
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_off_rounded, color: VibeColors.error),
          title: const Text(
            'Выключить уведомления',
            style: TextStyle(color: VibeColors.error),
          ),
          onTap: () {
            _setMuted(true);
            Navigator.of(context).pop();
            widget.onSnack('Уведомления выключены');
          },
        ),
      ],
    );
  }

  Widget _buildMuteForAWhileColumn(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.arrow_back_rounded, size: 20),
          title: const Text('Выключить на время'),
          onTap: () => setState(() => _level = 1),
        ),
        const Divider(height: 1),
        const SizedBox(height: VibeSpacing.xs),
        for (final entry in {
          '1 час': const Duration(hours: 1),
          '8 часов': const Duration(hours: 8),
          '1 день': const Duration(days: 1),
          '2 дня': const Duration(days: 2),
          '1 неделя': const Duration(days: 7),
        }.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule_rounded, color: context.vibePrimary),
            title: Text(entry.key),
            onTap: () {
              _setMuted(true);
              final until = DateTime.now().add(entry.value);
              VibeBackend.instance.setChatMuted(
                widget.chat.id,
                muted: true,
                forever: false,
                until: until,
              );
              Navigator.of(context).pop();
              widget.onSnack('Звук выключен на ${entry.key}');
            },
          ),
      ],
    );
  }
}

/// Разделитель даты между сообщениями, как в Telegram: «Сегодня»,
/// «Вчера» или полная дата. Идёт по центру, пилюля с фоном.
class _DateDivider extends StatelessWidget {
  const _DateDivider(this.date);

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    String label = _label();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VibeSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: VibeSpacing.md,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: context.vibeSurfaceVariant.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(VibeRadius.pill),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.vibeTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }

  String _label() {
    final d = date;
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Сегодня';
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == yesterday) return 'Вчера';
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }
}

/// Кнопка «прокрутить вниз» с бейджем количества новых сообщений,
/// как в Telegram. Появляется, когда чат прокручен вверх.
class _JumpDownButton extends StatelessWidget {
  const _JumpDownButton({
    required this.visible,
    required this.badge,
    required this.onTap,
  });

  final bool visible;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1.0 : 0.0,
      duration: VibeAnimations.scaleIn,
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: VibeAnimations.fadeIn,
        child: IgnorePointer(
          ignoring: !visible,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.isDarkMode
                        ? context.vibeSurfaceVariant
                        : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(
                      color: context.vibePrimary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: context.vibeTextPrimary,
                    size: 26,
                  ),
                ),
              ),
              if (badge > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    constraints: const BoxConstraints(minWidth: 20),
                    decoration: BoxDecoration(
                      color: VibeColors.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
