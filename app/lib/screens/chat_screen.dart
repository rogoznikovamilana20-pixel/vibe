
import 'package:vibe_app/core/widgets/vibe_toast.dart';import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/vibe_offline_banner.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_media_gallery_screen.dart';
import '../chat/models.dart';
import '../chat/widgets/chat_app_bar.dart';
import '../chat/widgets/chat_composer.dart';
import '../chat/widgets/chat_menu_sheet.dart';
import '../chat/widgets/message_bubble.dart';
import '../core/services/notification_service.dart';
import '../core/services/scheduled_service.dart';
import '../data/backend.dart';
import '../data/backend_api.dart';
import '../data/settings_service.dart';
import '../chat/widgets/jump_down_button.dart';
import '../chat/widgets/message_date_divider.dart';
import 'chat_search_screen.dart';
import 'emoji_sticker_panel.dart';
import 'forward_message_screen.dart';
import 'group_info_screen.dart';
import 'peer_profile_screen.dart';
import 'video_round_recorder.dart';

/// Экран чата. Собирает ввод и отображает ленту; вся работа с данными —
/// в `ChatController` (Single Writer, см. docs/vibe/STATE_MACHINE.md).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chat, this.backend});

  final VibeChat chat;

  /// Тестовая подмена данных (widget-тесты); null — живой бэкенд.
  final VibeBackendApi? backend;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  /// Поверхность данных экрана: живой бэкенд или фейк из теста.
  late final VibeBackendApi _backend = widget.backend ?? LiveVibeBackend();

  /// Data-plane чата: лента, пагинация, realtime, отправка.
  late final ChatController _chat;

  /// Показываем панель эмодзи/стикеров.
  bool _showEmojiPanel = false;

  /// 5.3: кэшированный «текст есть» — setState только при смене границы
  /// пусто/не-пусто, а не на каждую клавишу.
  bool _canSend = false;

  /// Версия восстановленного черновика (после «Отменить отправку»).
  int _seenDraftRestore = 0;

  // ─── Голосовая запись (удержание микрофона, как в Telegram) ───
  bool _recording = false;
  bool _micLocked = false;
  int _recordSeconds = 0;
  final _recorder = AudioRecorder();
  String? _recordPath;

  // ─── Видеокружок: inline-запись (удержание камеры, как в TG) ───
  CameraController? _camCtrl;
  bool _camReady = false;
  bool _videoRolling = false;
  bool _videoLocked = false;
  int _videoSeconds = 0;
  bool _justHeld = false;
  double _videoDragDy = 0;
  Timer? _holdTimer;

  // Аудиоплеер голосовых сообщений.
  final _player = AudioPlayer();

  // ─── 8.4.1: липкая плашка даты при скролле от низа ───
  // GlobalKey по сообщению: находим верхнее видимое через render-объекты
  // построенных элементов (lazy-список строит только видимые).
  final Map<String, GlobalKey> _msgKeys = {};
  Timer? _stickTimer;
  String? _stickDateLabel;
  int _noIdSeq = 0;

  GlobalKey _keyOf(dynamic id) {
    final key = _msgKeys[id];
    if (key != null) return key;
    final fresh = GlobalKey();
    _msgKeys[id] = fresh;
    return fresh;
  }

  String get _chatId => widget.chat.id;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.enterChat(_chatId);
    _chat = ChatController(
      chatId: _chatId,
      chatTitle: widget.chat.title,
      onError: _snack,
      initialUnread: widget.chat.unread,
      backend: _backend,
    );
    _chat.load();
    // Восстановление черновика (draft читается синхронно в load()).
    _input.text = _chat.draft;
    _canSend = _input.text.trim().isNotEmpty;
    // 5.3: подписка на поле ввода вместо setState в onChanged —
    // пересборка только при смене canSend, typing/draft идут без неё.
    _input.addListener(_onInputChanged);
    _scroll.addListener(_onChatScroll);
  }

  void _onInputChanged() {
    _chat.notifyTyping(_input.text);
    _chat.saveDraft(_input.text);
    final canSend = _input.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
    }
  }

  @override
  void dispose() {
    NotificationService.instance.exitChat(_chatId);
    _chat.dispose();
    _holdTimer?.cancel();
    _stickTimer?.cancel();
    _msgKeys.clear();
    _camCtrl?.dispose();
    _recorder.dispose();
    _player.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
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

  /// Скролл: отслеживаем положение (reverse — 0 px это низ чата) и
  /// подгружаем старые сообщения у верхнего края.
  void _onChatScroll() {
    if (!_scroll.hasClients || !mounted) return;
    final pos = _scroll.position;
    _chat.onScroll(atBottom: pos.pixels < 80);
    if (pos.maxScrollExtent > 0 && pos.pixels >= pos.maxScrollExtent - 120) {
      _chat.loadOlderIfNeeded();
    }
    // 8.4.1: липкая дата — дешёвый расчёт с троттлингом 80 мс.
    if (_stickTimer?.isActive ?? false) return;
    _stickTimer = Timer(const Duration(milliseconds: 80), _updateStickDate);
  }

  /// 8.4.1: вычисляет дату верхнего видимого сообщения и обновляет плашку.
  void _updateStickDate() {
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels < 80) {
      if (_stickDateLabel != null) {
        setState(() => _stickDateLabel = null);
      }
      return;
    }
    final msgs = _chat.messages;
    final screenH = MediaQuery.sizeOf(context).height;
    double? bestTop;
    int best = -1;
    for (var i = 0; i < msgs.length; i++) {
      final ctx = _keyOf(_bubbleKeyFor(i)).currentContext;
      if (ctx == null) continue;
      final ro = ctx.findRenderObject();
      if (ro is! RenderBox || !ro.attached) continue;
      final top = ro.localToGlobal(Offset.zero).dy;
      if (top >= screenH || top + ro.size.height <= 0) continue;
      if (bestTop == null || top < bestTop) {
        bestTop = top;
        best = i;
      }
    }
    final label = best < 0 ? null : fmtDateLabel(msgs[best].date);
    if (label != _stickDateLabel) {
      setState(() => _stickDateLabel = label);
    }
  }

  /// 8.4.1: ключ пузыря сообщения (по id, а не по индексу — индексы
  /// сдвигаются при вставке новых сообщений сверху).
  Object _bubbleKeyFor(int i) {
    final m = _chat.messages[i];
    return m.localId ?? m.serverId ?? '__noId_${_noIdSeq++}';
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _input.clear();
    setState(() {});
    await _chat.send(text);
  }

  /// 3.9: отложить отправку текста (удержание кнопки отправки).
  void _showScheduleSheet(String text) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
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
              Text(
                'Отложить отправку',
                style: VibeTypography.subtitle.copyWith(
                  color: context.vibeTextPrimary,
                ),
              ),
              const SizedBox(height: VibeSpacing.xs),
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VibeTypography.caption.copyWith(
                  color: context.vibeTextTertiary,
                ),
              ),
              const SizedBox(height: VibeSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.schedule_rounded,
                  color: context.vibePrimary,
                ),
                title: const Text('Через 1 час'),
                onTap: () => _applySchedule(
                  sheetCtx,
                  text,
                  DateTime.now().add(const Duration(hours: 1)),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.schedule_rounded,
                  color: context.vibePrimary,
                ),
                title: const Text('Завтра в 09:00'),
                onTap: () => _applySchedule(
                  sheetCtx,
                  text,
                  DateTime.now()
                      .add(const Duration(days: 1))
                      .copyWith(
                        hour: 9,
                        minute: 0,
                        second: 0,
                        millisecond: 0,
                        microsecond: 0,
                      ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event_rounded, color: context.vibePrimary),
                title: const Text('Выбрать дату и время…'),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  final now = DateTime.now();
                  final day = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (day == null || !mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time == null || !mounted) return;
                  _applySchedule(
                    context,
                    text,
                    DateTime(
                      day.year,
                      day.month,
                      day.day,
                      time.hour,
                      time.minute,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applySchedule(BuildContext sheetCtx, String text, DateTime when) {
    Navigator.of(sheetCtx).pop();
    if (!mounted) return;
    ScheduledService.instance.schedule(widget.chat.id, text, when);
    _input.clear();
    _chat.saveDraft('');
    setState(() {});
    _snack('Запланировано на ${_scheduleLabel(when)}');
  }

  /// Список отложенных сообщений чата с отменой по строке.
  void _showScheduledList() {
    final pending = ScheduledService.instance.pendingFor(widget.chat.id);
    if (pending.isEmpty) return;
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
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
              Text(
                'Запланированные сообщения',
                style: VibeTypography.subtitle.copyWith(
                  color: context.vibeTextPrimary,
                ),
              ),
              const SizedBox(height: VibeSpacing.sm),
              for (final m in pending)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.schedule_rounded,
                    color: context.vibePrimary,
                  ),
                  title: Text(
                    m.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VibeTypography.body.copyWith(
                      color: context.vibeTextPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _scheduleLabel(m.when),
                    style: VibeTypography.caption.copyWith(
                      color: context.vibeTextTertiary,
                    ),
                  ),
                  trailing: IconButton(
                    onPressed: () {
                      ScheduledService.instance.cancel(
                        widget.chat.id,
                        m.localId,
                      );
                      _snack('Отправка отменена');
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: context.vibeError,
                    tooltip: 'Отменить отправку',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _scheduleLabel(DateTime when) {
    final h = when.hour.toString().padLeft(2, '0');
    final min = when.minute.toString().padLeft(2, '0');
    final d = when.day.toString().padLeft(2, '0');
    final mo = when.month.toString().padLeft(2, '0');
    return '$h:$min $d.$mo';
  }

  Future<void> _sendSticker(String emoji) async {
    HapticFeedback.lightImpact();
    await _chat.sendSticker(emoji);
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
    await _chat.sendPhoto(bytes);
  }

  Future<void> _startRecording() async {
    await _stopPlayback();
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _snack('Нет разрешения на микрофон');
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
  }

  /// Зафиксировать запись (при поднятии пальца) — режим «удержание».
  void _lockMic() {
    HapticFeedback.selectionClick();
    setState(() => _micLocked = true);
  }

  /// Вернуться в режим «удержание» (свайпом вниз).
  void _unlockMic() {
    if (!_micLocked) return;
    HapticFeedback.selectionClick();
    setState(() => _micLocked = false);
  }

  void _cancelRecording() {
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
        _snack('Слишком короткая запись');
        return;
      }
      await _chat.sendVoice(path: path, seconds: seconds);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  Future<void> _stopPlayback() async {
    if (_player.state == PlayerState.playing) {
      await _player.stop();
    }
  }

  void _replyToMsg(int i) {
    HapticFeedback.mediumImpact(); // Ощутимый отклик при ответе/действии
    _chat.replyToMsg(i);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _startEdit(int i) {
    _chat.startEdit(i);
    setState(() => _input.text = _chat.messages[i].text);
    _scrollToEnd();
  }

  Future<void> _deleteMsg(int i) async {
    final msg = _chat.messages[i];
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
              ActionRow(
                icon: Icons.group_off_rounded,
                label: 'Удалить для всех',
                onTap: () => Navigator.of(context).pop('everyone'),
              ),
              const SizedBox(height: VibeSpacing.xs),
            ],
            ActionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Удалить для меня',
              onTap: () => Navigator.of(context).pop('me'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    await _chat.deleteMessage(msg, everyone: action == 'everyone');
  }

  /// Прыжок к закреплённому сообщению: поднимаем к низу экрана и
  /// подсвечиваем пузырь (как в Telegram).
  void _jumpToPinned(String id) {
    _chat.jumpToPinned(id);
    _scrollToEnd();
  }

  /// Поиск по сообщениям чата: экран находок, выбор — прыжок к сообщению
  /// с подсветкой (тем же механизмом, что и у закреплённых).
  Future<void> _openSearch() async {
    final items = [
      for (final m in _chat.messages)
        if (m.type == MsgType.text && m.text.isNotEmpty && m.serverId != null)
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
      MaterialPageRoute(builder: (_) => ChatSearchScreen(items: items)),
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
          title: _chat.groupTitle ?? widget.chat.title,
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
      _chat.setGroupTitle(result.renamedTitle!);
      _snack('Группа переименована');
    }
  }

  /// Профиль собеседника (тап по центральной пилюле шапки).
  Future<void> _openProfile() async {
    final media = [
      for (final m in _chat.messages)
        if (m.type == MsgType.photo)
          PeerMedia(isVideo: false, url: m.photoUrl)
        else if (m.type == MsgType.video)
          PeerMedia(isVideo: true, url: m.videoUrl, localPath: m.videoPath),
    ];
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PeerProfileScreen(chat: widget.chat, media: media),
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
            SheetCallTile(
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
            SheetCallTile(
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
      builder: (sheetCtx) => ChatMenuSheet(
        chat: widget.chat,
        onSnack: _snack,
        onTapSearch: () {
          Navigator.of(sheetCtx).pop();
          _openSearch();
        },
        onTapMedia: () {
          Navigator.of(sheetCtx).pop();
          _openMedia();
        },
        onClearHistory: () => _confirmClearHistory(),
        onChatInfo: _showChatInfo,
        onArchive: _archiveChat,
        onDelete: _deleteChat,
      ),
    );
  }

    /// 8.3.2: «Архивировать» из меню чата — чат уходит в облачный архив.
  void _archiveChat() {
    _backend.setChatArchived(widget.chat.id, archived: true);
    _snack('Чат в архиве');
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// 8.3.2: «Удалить чат» — для себя, локально (как в TG: чат исчезает
  /// из ленты; у собеседника история остаётся). Серверного deleteChat нет.
  Future<bool> _deleteChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Удалить чат?'),
        content: const Text(
          'Чат исчезнет из вашего списка. История останется '
          'у собеседника — удаление локальное, для этого устройства.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return false;
    final ids = [...SettingsService.instance.deletedChats, widget.chat.id];
    await SettingsService.instance.setDeletedChats(ids);
    if (mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
    return true;
  }

  /// 2.12: сведения о чате — тип, участник, число сообщений (локальные данные).
  void _showChatInfo() {    final chat = widget.chat;
    final kind = switch (chat.kind) {
      'pm' => 'Личный чат',
      'group' => 'Группа',
      'channel' => 'Канал',
      _ => 'Чат',
    };
    final peer = chat.peerName != null && chat.peerName!.isNotEmpty
        ? chat.peerName!
        : chat.title;
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        kind,
                        style: VibeTypography.caption.copyWith(
                          color: context.vibeTextTertiary,
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
            if (chat.kind == 'pm')
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.person_outline_rounded,
                  color: context.vibePrimary,
                ),
                title: const Text('Участник'),
                trailing: Text(peer, style: VibeTypography.bodyMedium),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.forum_outlined, color: context.vibePrimary),
              title: const Text('Сообщений'),
              trailing: Text(
                '${_chat.messages.length}',
                style: VibeTypography.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text(
          'Все сообщения этого чата будут удалены у всех участников.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _chat.clearHistory();
    }
  }

  void _openMedia() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatMediaGalleryScreen(
          controller: _chat,
          chatTitle: widget.chat.title,
        ),
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
                AttachmentItem(
                  icon: Icons.photo_library_rounded,
                  color: VibeColors.vivid,
                  label: 'Фото',
                  onTap: () {
                    Navigator.of(context).pop();
                    _sendPhoto();
                  },
                ),
                const SizedBox(width: VibeSpacing.lg),
                AttachmentItem(
                  icon: Icons.mic_rounded,
                  color: const Color(0xFFEC4899),
                  label: 'Голос',
                  onTap: () {
                    Navigator.of(context).pop();
                    _startRecording();
                  },
                ),
                const SizedBox(width: VibeSpacing.lg),
                AttachmentItem(
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
    final photos = _chat.messages
        .where((m) => m.type == MsgType.photo)
        .toList();
    final voices = _chat.messages
        .where((m) => m.type == MsgType.voice)
        .toList();
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
                  padding: const EdgeInsets.symmetric(vertical: VibeSpacing.lg),
                  child: Center(
                    child: Text(
                      'В этом чате пока нет вложений',
                      style: VibeTypography.body.copyWith(
                        color: context.vibeTextTertiary,
                      ),
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

  void _showMessageActions(int i) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // SingleChildScrollView: меню на маленьких экранах не помещается
      // (переполнение Column) — нижние пункты должны оставаться доступными.
      builder: (context) => SingleChildScrollView(
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
                    ReactionButton(
                      emoji: r.$1,
                      onTap: () {
                        Navigator.of(context).pop();
                        _chat.addReaction(i, r.$1);
                      },
                    ),
                ],
              ),
              const SizedBox(height: VibeSpacing.md),
              ActionRow(
                icon: Icons.reply_rounded,
                label: 'Ответить',
                onTap: () {
                  Navigator.of(context).pop();
                  _replyToMsg(i);
                },
              ),
              ActionRow(
                icon: Icons.copy_rounded,
                label: 'Копировать',
                onTap: () {
                  Navigator.of(context).pop();
                  Clipboard.setData(
                    ClipboardData(text: _chat.messages[i].text),
                  );
                  _snack('Скопировано');
                },
              ),
              ActionRow(
                icon: Icons.bookmark_add_outlined,
                label: 'Сохранить в Избранное',
                onTap: () {
                  Navigator.of(context).pop();
                  _saveToSaved(_chat.messages[i]);
                },
              ),
              ActionRow(
                icon: Icons.reply_all_rounded,
                label: 'Переслать',
                onTap: () {
                  Navigator.of(context).pop();
                  _openForward(_chat.messages[i]);
                },
              ),
              if (_chat.messages[i].serverId != null &&
                  _chat.pins.contains(_chat.messages[i].serverId))
                ActionRow(
                  icon: Icons.push_pin_rounded,
                  label: 'Открепить',
                  onTap: () {
                    Navigator.of(context).pop();
                    _chat.unpin(_chat.messages[i].serverId!);
                  },
                )
              else if (_chat.messages[i].serverId != null)
                ActionRow(
                  icon: Icons.push_pin_outlined,
                  label: 'Закрепить',
                  onTap: () {
                    Navigator.of(context).pop();
                    _chat.setPin(_chat.messages[i].serverId);
                  },
                ),
              if (!_chat.messages[i].incoming &&
                  _chat.messages[i].type == MsgType.text)
                ActionRow(
                  icon: Icons.edit_rounded,
                  label: 'Редактировать',
                  onTap: () {
                    Navigator.of(context).pop();
                    _startEdit(i);
                  },
                ),
              if (_chat.messages[i].edited)
                ActionRow(
                  icon: Icons.history_rounded,
                  label: 'История правок',
                  onTap: () {
                    Navigator.of(context).pop();
                    _showEditHistory(_chat.messages[i]);
                  },
                ),
              ActionRow(
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
      ),
    );
  }

  Future<void> _saveToSaved(ChatMsg msg) async {
    final backend = _backend;
    try {
      final savedId = await backend.ensureSavedChat();
      if (savedId.isEmpty) {
        _snack('Не удалось сохранить');
        return;
      }
      final m = await backend.forwardMessage(savedId, _msgToBackend(msg));
      if (!mounted) return;
      _snack(m != null ? 'Сохранено в Избранное' : 'Не удалось сохранить');
    } catch (_) {
      if (!mounted) return;
      _snack('Сервер недоступен');
    }
  }

  /// История правок сообщения: снимки текста от новых к старым
  /// (как «изменено» в Telegram с просмотром версий).
  Future<void> _showEditHistory(ChatMsg msg) async {
    final serverId = msg.serverId;
    if (serverId == null) return;
    List<MessageEdit> edits;
    try {
      edits = await _backend.listMessageEdits(serverId);
    } catch (_) {
      _snack('Сервер недоступен');
      return;
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            VibeSpacing.lg,
            VibeSpacing.xs,
            VibeSpacing.lg,
            VibeSpacing.xxl,
          ),
          child: edits.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: VibeSpacing.lg),
                    Text('История правок', style: VibeTypography.subtitle),
                    const SizedBox(height: VibeSpacing.md),
                    Text(
                      'Правок не найдено',
                      style: VibeTypography.body.copyWith(
                        color: context.vibeTextSecondary,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('История правок', style: VibeTypography.subtitle),
                    const SizedBox(height: VibeSpacing.sm),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: edits.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final e = edits[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    e.text,
                                    style: VibeTypography.body.copyWith(
                                      color: context.vibeTextPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: VibeSpacing.sm),
                                Icon(
                                  Icons.edit_rounded,
                                  size: 15,
                                  color: context.vibeTextTertiary,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _openForward(ChatMsg msg) async {
    final backend = _backend;
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

  VibeMessage _msgToBackend(ChatMsg m) {
    return VibeMessage(
      id: m.serverId ?? '',
      chatId: _chatId,
      senderId: '',
      senderName: '',
      senderAvatar: null,
      text: m.type == MsgType.text ? m.text : null,
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

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDarkMode
          ? context.vibeSurfaceLow
          : const Color(0xFFEBE9F4),
      body: ListenableBuilder(
        listenable: _chat,
        builder: (context, _) {
// «Отменить отправку» вернул текст в черновик — кладём в поле ввода.
          if (_chat.draftRestoreVersion != _seenDraftRestore) {
            _seenDraftRestore = _chat.draftRestoreVersion;
            // Без listener: восстановление не должно шлáть «печатает»
            // и делать setState посреди build.
            _input.removeListener(_onInputChanged);
            _input.text = _chat.draft;
            _canSend = _input.text.trim().isNotEmpty;
            _input.addListener(_onInputChanged);
            _input.selection =
                TextSelection.collapsed(offset: _input.text.length);
          }
          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ListenableBuilder(
                      listenable: SettingsService.instance.appearanceVersion,
                      builder: (context, _) => RepaintBoundary(
                        child: CustomScrollView(
                          controller: _scroll,
                          reverse: true, // Инвертированный список сообщений
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            // «Отменить отправку»: пилюля над последним пузырём
                            // (окно 5 секунд, как в Telegram).
                            if (_chat.undoAvailable)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    VibeSpacing.md,
                                    0,
                                    VibeSpacing.md,
                                    VibeSpacing.sm,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Material(
                                      color: context.vibeSurfaceVariant,
                                      borderRadius: BorderRadius.circular(
                                        VibeRadius.pill,
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(
                                          VibeRadius.pill,
                                        ),
                                        onTap: () => _chat.undoLastSend(),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: VibeSpacing.md,
                                            vertical: VibeSpacing.sm,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.undo_rounded,
                                                size: 18,
                                              ),
                                              const SizedBox(
                                                width: VibeSpacing.xs,
                                              ),
                                              Text(
                                                'Отменить отправку',
                                                style:
                                                    VibeTypography.bodyMedium,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Из-за reverse: true это «верх» списка (свежие).
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 100), // Запас для шапки
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: VibeSpacing.md,
                                vertical: VibeSpacing.md,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  i,
                                ) {
                                  final showDate =
                                      i == 0 ||
                                      !_sameDay(
                                        _chat.messages[i].date,
                                        _chat.messages[i - 1].date,
                                      );
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (showDate)
                                        MessageDateDivider(
                                          date: _chat.messages[i].date,
                                        ),
                                      MessageBubble(
                                        msg: _chat.messages[i],
                                        key: _keyOf(_bubbleKeyFor(i)),
                                        isFirstInGroup:
                                            ChatController.isFirstInGroup(
                                              _chat.messages,
                                              i,
                                            ),
                                        isLastInGroup:
                                            ChatController.isLastInGroup(
                                              _chat.messages,
                                              i,
                                            ),
                                        onHeart: () => _chat.heartReact(i),
                                        onLongPress: () =>
                                            _showMessageActions(i),
                                        onReply: () => _replyToMsg(i),
                                        onOpenUrl: _openUrl,
                                        scrollController: _scroll,
                                        player: _player,
                                        highlight:
                                            _chat.pinFlashId != null &&
                                            _chat.messages[i].serverId ==
                                                _chat.pinFlashId,
                                      ),
                                    ],
                                  );
                                }, childCount: _chat.messages.length),
                              ),
                            ),
                            ListenableBuilder(
                              listenable: _backend.connectivityVersion,
                              builder: (context, _) => _backend.isOffline
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
                            // Индикатор подгрузки старых сообщений.
                            if (_chat.hasMoreOlder)
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
                                        value: _chat.loadingOlder ? null : 0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Нижний отступ списка (под плавающей шапкой).
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: MediaQuery.of(context).padding.top + 72,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildInputBar(context),
                ],
              ),
              // Плавающая шапка чата.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChatAppBar(
                        chat: widget.chat,
                        groupTitle: _chat.groupTitle,
                        peerTyping: _chat.peerTyping,
                        onBack: () => Navigator.of(context).pop(),
                        onOpenProfile: _openProfile,
                        onOpenGroupInfo: _openGroupInfo,
                        onOpenSearch: _openSearch,
                        onChooseCall: () => _chooseCall(context),
                        onShowMenu: () => _showChatMenu(context),
                      ),
                      if (_chat.pinMsgId != null) _buildPinnedBanner(context),
                    ],
                  ),
                ),
              ),
              // Плашка «N непрочитанных» (прыжок к первому непрочитанному).
              if (_chat.unreadJumpIndex != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom:
                      VibeSpacing.md +
                      MediaQuery.of(context).viewPadding.bottom,
                  child: Center(
                    child: _UnreadPlank(
                      count: _chat.unreadJumpIndex! + 1,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _chat.jumpToUnread();
                        _scrollToEnd();
                      },
                    ),
                  ),
                ),
              // 8.4.1: липкая плашка даты — верхнее видимое сообщение
              // (видна, пока лента прокручена от низа).
              if (_stickDateLabel != null && !_chat.atBottom)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: VibeSpacing.md +
                      MediaQuery.of(context).viewPadding.bottom +
                      56,
                  child: Center(
                    child: _StickDatePlank(label: _stickDateLabel!),
                  ),
                ),
              // Кнопка «новые сообщения» (прыжок вниз, как в Telegram).
              Positioned(
                right: VibeSpacing.md,
                bottom:
                    VibeSpacing.md + MediaQuery.of(context).viewPadding.bottom,
                child: JumpDownButton(
                  visible: !_chat.atBottom || _chat.newIncoming > 0,
                  badge: _chat.newIncoming,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _chat.jumpToBottom();
                    _scrollToEnd();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Плашка «Закреплённое сообщение» под шапкой (как в Telegram).
  /// При нескольких закрепах показывает «+N ещё» и открывает список.
  Widget _buildPinnedBanner(BuildContext context) {
    final topId = _chat.pinMsgId;
    if (topId == null) return const SizedBox.shrink();
    final extra = _chat.pins.length - 1;
    final preview = _pinPreview(topId);
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
            if (extra > 0) {
              _showAllPins();
            } else {
              _jumpToPinned(topId);
            }
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
                if (extra > 0) ...[
                  const SizedBox(width: VibeSpacing.sm),
                  Text(
                    'ещё $extra',
                    style: VibeTypography.caption.copyWith(
                      color: context.vibePrimary,
                    ),
                  ),
                ],
                const SizedBox(width: VibeSpacing.sm),
                GestureDetector(
                  onTap: () => _chat.setPin(null),
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

  String _pinPreview(String serverId) {
    for (final m in _chat.messages) {
      if (m.serverId == serverId) {
        return (m.type == MsgType.text && m.text.isNotEmpty)
            ? m.text
            : 'Закреплённое медиа';
      }
    }
    return 'Закреплённое сообщение';
  }

  /// Список всех закреплённых сообщений чата.
  void _showAllPins() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(VibeSpacing.md),
              child: Text(
                'Закреплённые сообщения',
                style: VibeTypography.title,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _chat.pins.length,
                itemBuilder: (context, i) {
                  final id = _chat.pins[i];
                  final preview = _pinPreview(id);
                  return ListTile(
                    leading: const Icon(Icons.push_pin_rounded, size: 20),
                    title: Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Открепить',
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _chat.unpin(id);
                      },
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _jumpToPinned(id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
            if (_chat.editingIdx != null)
              Padding(
                padding: const EdgeInsets.only(bottom: VibeSpacing.sm),
                child: ReplyPanel(
                  author: 'Редактирование',
                  text: _chat.messages[_chat.editingIdx!].text,
                  onClose: () {
                    _chat.cancelEdit();
                    _input.clear();
                    setState(() {});
                  },
                ),
              ),
            if (_chat.replyTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: VibeSpacing.sm),
                child: ReplyPanel(
                  author: _chat.messages[_chat.replyTo!].incoming
                      ? widget.chat.title
                      : 'Вы',
                  text: _chat.messages[_chat.replyTo!].text,
                  onClose: () => _chat.setReply(null),
                ),
              ),
            ListenableBuilder(
              listenable: ScheduledService.instance.version,
              builder: (context, _) {
                final pending = ScheduledService.instance.pendingFor(
                  widget.chat.id,
                );
                if (pending.isEmpty) return const SizedBox.shrink();
                final first = pending.first;
                return Padding(
                  padding: const EdgeInsets.only(bottom: VibeSpacing.sm),
                  child: Material(
                    color: context.vibeSurfaceVariant,
                    borderRadius: BorderRadius.circular(VibeRadius.pill),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(VibeRadius.pill),
                      onTap: _showScheduledList,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: VibeSpacing.md,
                          vertical: VibeSpacing.xs,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 18,
                              color: context.vibePrimary,
                            ),
                            const SizedBox(width: VibeSpacing.xs),
                            Flexible(
                              child: Text(
                                pending.length == 1
                                    ? 'Запланировано · ${_scheduleLabel(first.when)}'
                                    : 'Запланировано: ${pending.length} · до '
                                          '${_scheduleLabel(first.when)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: VibeTypography.caption.copyWith(
                                  color: context.vibeTextSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: VibeSpacing.xs),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: VibeColors.borderDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
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
                          ? context.vibeError.withValues(alpha: 0.85)
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
                      color: _videoRolling ? Colors.white : context.vibePrimary,
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
                      ? VideoRollPill(
                          cam: _camCtrl,
                          locked: _videoLocked,
                          onTick: (s) {
                            _videoSeconds = s;
                            if (s >= 60) _finalizeVideo(send: true);
                          },
                          onCancel: _cancelVideoRoll,
                          onSend: () => _finalizeVideo(send: true),
                        )
                      : _recording
                      ? RollingPill(
                          locked: _micLocked,
                          onTick: (s) {
                            _recordSeconds = s;
                            if (s >= 60) _stopRecording();
                          },
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
                            borderRadius: BorderRadius.circular(VibeRadius.xl),
                            border: Border.all(
                              color: context.isDarkMode
                                  ? VibeColors.borderDark.withValues(alpha: 0.6)
                                  : const Color(0x1F1C1B22),
                            ),
                            boxShadow: context.isDarkMode
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: TextField(
                            controller: _input,
                            maxLines: 5,
                            minLines: 1,
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
                SendButton(
                  canSend: _canSend,
                  recording: _recording,
                  locked: _micLocked,
                  onMicTap: _startRecording,
                  onSend: _recording && _micLocked ? _stopRecording : _send,
                  onRelease: _stopRecording,
                  onLock: _lockMic,
                  onUnlock: _unlockMic,
                  onCancel: _cancelRecording,
                  onSchedule: _canSend
                      ? () => _showScheduleSheet(_input.text)
                      : null,
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
    VibeToast.show(context, msg);
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
    await _chat.sendVideo(file);
  }

  Future<void> _cancelVideoRoll() async {
    final cam = _camCtrl;
    if (cam != null && _videoRolling) {
      try {
        final xf = await cam.stopVideoRecording();
        try {
          File(xf.path).delete();
        } catch (_) {}
      } catch (_) {}
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
    await _chat.sendVideo(res.file);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }
}

/// Плашка «N непрочитанных» — прыжок к первому непрочитанному (как в ТГ).
class _UnreadPlank extends StatelessWidget {
  const _UnreadPlank({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.vibeSurfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.vibeBorder.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_downward_rounded,
              size: 16,
              color: context.vibePrimary,
            ),
            const SizedBox(width: 6),
            Text(
              'Непрочитанные: $count',
              style: VibeTypography.caption.copyWith(
                color: context.vibeTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 8.4.1: липкая плашка даты — показывает дату верхнего видимого
/// сообщения, пока лента прокручена от низа (как в Telegram).
class _StickDatePlank extends StatelessWidget {
  const _StickDatePlank({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('stick_date'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.vibeSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.vibeBorder.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: VibeTypography.caption.copyWith(
          color: context.vibeTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
