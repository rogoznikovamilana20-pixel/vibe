// ignore_for_file: use_build_context_synchronously

import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'dart:async';
import 'dart:io';

import 'group_call_screen.dart';
import 'photo_editor_screen.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
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
import '../core/widgets/swipe_back_wrapper.dart';
import 'gif_search_panel.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_media_gallery_screen.dart';
import '../chat/models.dart';
import '../chat/widgets/chat_app_bar.dart';
import '../chat/widgets/chat_composer.dart';
import '../chat/widgets/chat_menu_sheet.dart';
import '../chat/chat_export_service.dart';
import '../chat/widgets/chat_toolbar_widgets.dart';
import '../chat/widgets/attachment_menu.dart';
import '../chat/widgets/chat_planks.dart';
import '../chat/widgets/message_bubble.dart';
import '../chat/widgets/telegram_context_menu.dart';
import '../chat/widgets/mentions_autocomplete.dart';
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
import 'call_screen.dart';
import 'package:vibe_app/core/widgets/vibe_icon_resolver.dart';
import '../core/localization/vibe_localizations.dart';

/// Экран чата. Собирает ввод и отображает ленту; вся работа с данными —
/// в `ChatController` (Single Writer, см. docs/vibe/STATE_MACHINE.md).
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chat,
    this.backend,
    this.chats,
    this.initialIndex = 0,
  });

  final VibeChat chat;

  /// Тестовая подмена данных (widget-тесты); null — живой бэкенд.
  final VibeBackendApi? backend;

  /// Список чатов для свайпа между ними (V2.3).
  final List<VibeChat>? chats;

  /// Начальный индекс в списке чатов.
  final int initialIndex;

  /// Запись гифки во временный файл для отправки (инжектируемо для тестов —
  /// в widget-тестах реальный файловый I/O не завершается в FakeAsync).
  static Future<File> Function(String assetName) writeGifTemp =
      _writeGifTempDefault;

  static Future<File> _writeGifTempDefault(String assetName) async {
    final bytes = await rootBundle.load('assets/gifs/$assetName');
    final dir = await getTemporaryDirectory();
    final tmp = File('${dir.path}/vibe_gifs/$assetName');
    await tmp.parent.create(recursive: true);
    await tmp.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return tmp;
  }

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

  // ─── @mentions autocomplete ───
  String _mentionQuery = '';

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
    // @mentions: detect @ and extract query after it.
    final text = _input.text;
    final cursorPos = _input.selection.base.offset;
    if (cursorPos > 0) {
      final beforeCursor = text.substring(0, cursorPos);
      final atIndex = beforeCursor.lastIndexOf('@');
      if (atIndex >= 0 && (atIndex == 0 || beforeCursor[atIndex - 1] == ' ')) {
        final query = beforeCursor.substring(atIndex + 1);
        if (query.length <= 20 && !query.contains(' ')) {
          if (_mentionQuery != query) {
            setState(() => _mentionQuery = query);
          }
          return;
        }
      }
    }
    if (_mentionQuery.isNotEmpty) {
      setState(() => _mentionQuery = '');
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
    final label = best < 0 ? null : fmtDateLabel(context, msgs[best].date);
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
    final l = VibeLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        bool silent = false;
        return StatefulBuilder(
          builder: (ctx2, setSheetState) => SafeArea(
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
                    l.scheduleTitle,
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
                      VibeIconResolver.clock,
                      color: context.vibePrimary,
                    ),
                    title: Text(l.scheduleIn1Hour),
                    onTap: () => _applySchedule(
                      sheetCtx,
                      text,
                      DateTime.now().add(const Duration(hours: 1)),
                      silent: silent,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      VibeIconResolver.clock,
                      color: context.vibePrimary,
                    ),
                    title: Text(l.scheduleTomorrow9am),
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
                      silent: silent,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.event_rounded, color: context.vibePrimary),
                    title: Text(l.schedulePickDatetime),
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
                        silent: silent,
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Без звука'),
                    subtitle: const Text('Получатель не получит уведомление', style: TextStyle(fontSize: 12)),
                    value: silent,
                    onChanged: (v) => setSheetState(() => silent = v),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _applySchedule(BuildContext sheetCtx, String text, DateTime when, {bool silent = false}) {
    Navigator.of(sheetCtx).pop();
    if (!mounted) return;
    ScheduledService.instance.schedule(widget.chat.id, text, when, silent: silent);
    _input.clear();
    _chat.saveDraft('');
    setState(() {});
    _snack('${VibeLocalizations.of(context).scheduleScheduled} ${_scheduleLabel(when)}');
  }

  /// Список отложенных сообщений чата с отменой по строке.
  void _showScheduledList() {
    final pending = ScheduledService.instance.pendingFor(widget.chat.id);
    if (pending.isEmpty) return;
    HapticFeedback.selectionClick();
    final l = VibeLocalizations.of(context);
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
                l.scheduleListTitle,
                style: VibeTypography.subtitle.copyWith(
                  color: context.vibeTextPrimary,
                ),
              ),
              const SizedBox(height: VibeSpacing.sm),
              for (final m in pending)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    VibeIconResolver.clock,
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
                      _snack(l.scheduleCancelled);
                    },
                    icon: Icon(VibeIconResolver.close, size: 20),
                    color: context.vibeError,
                    tooltip: l.scheduleCancelSend,
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

  Future<void> _sendGif(String assetName) async {
    HapticFeedback.lightImpact();
    try {
      // Ассет не файл: копируем во временный каталог и шлём как анимированное
      // медиа (как в ТГ): в пузыре анимированный GIF, не карточка-файл.
      final tmp = await ChatScreen.writeGifTemp(assetName);
      await _chat.sendGif(tmp, assetName);
    } catch (e) {
      _snack('${VibeLocalizations.of(context).errorGifSendFailed}: $e');
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
    final file = File(picked.path);
    final result = await Navigator.of(context).push<PhotoEditResult>(
      MaterialPageRoute(builder: (_) => PhotoEditorScreen(file: file)),
    );
    if (result == null || !mounted) return;
    await _chat.sendPhoto(result.bytes);
    if (result.caption != null && result.caption!.isNotEmpty) {
      // Подпись — отдельным сообщением (деградация, пока нет photo+caption в одном).
      await _chat.send(result.caption!);
    }
  }

  Future<void> _startRecording() async {
    await _stopPlayback();
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _snack(VibeLocalizations.of(context).errorNoMicPermission);
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
      _snack(VibeLocalizations.of(context).errorRecordStartFailed);
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
        _snack(VibeLocalizations.of(context).errorTooShortRecording);
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

  /// Reply privately to a message in a group chat (V4.2).
  void _replyPrivately(int i) {
    HapticFeedback.mediumImpact();
    _snack(VibeLocalizations.of(context).actionPrivateReplySoon);
  }

  void _reportMessage(ChatMsg msg) {
    HapticFeedback.mediumImpact();
    final l = VibeLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.vibeSurfaceHigh,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(VibeRadius.bottomSheet)),
        ),
        padding: const EdgeInsets.all(VibeSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.reportTitle,
                style: VibeTypography.subtitle
                    .copyWith(color: context.vibeTextPrimary)),
            const SizedBox(height: VibeSpacing.md),
            Text(l.reportSelectReason,
                style: VibeTypography.body
                    .copyWith(color: context.vibeTextSecondary)),
            const SizedBox(height: VibeSpacing.lg),
            ...[l.reportSpam, l.reportViolence, l.reportCp, l.reportPersonal,
                l.reportIncitement, l.reportOther].map((reason) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(reason,
                      style: TextStyle(color: context.vibeTextPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _snack('${l.reportSubmitted}: $reason');
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _startEdit(int i) {
    _chat.startEdit(i);
    setState(() => _input.text = _chat.messages[i].text);
    _scrollToEnd();
  }

  Future<void> _deleteMsg(int i) async {
    final msg = _chat.messages[i];
    final isMine = !msg.incoming;
    final l = VibeLocalizations.of(context);
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
              l.msgDeleteTitle,
              style: VibeTypography.subtitle.copyWith(
                color: context.vibeTextPrimary,
              ),
            ),
            const SizedBox(height: VibeSpacing.md),
            if (isMine && msg.serverId != null) ...[
              ActionRow(
                icon: Icons.group_off_rounded,
                label: l.msgDeleteForEveryone,
                onTap: () => Navigator.of(context).pop('everyone'),
              ),
              const SizedBox(height: VibeSpacing.xs),
            ],
            ActionRow(
              icon: Icons.delete_outline_rounded,
              label: l.msgDeleteForMe,
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
      _snack(VibeLocalizations.of(context).chatNoTextMessages);
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
      _snack(VibeLocalizations.of(context).groupRenamed);
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
  /// аккуратный лист с аудио- и видеозвонком. Для групп — сразу групповой звонок.
  void _chooseCall(BuildContext context) {
    if (widget.chat.kind == 'group') {
      HapticFeedback.mediumImpact();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupCallScreen(chat: widget.chat)));
      return;
    }
    final l = VibeLocalizations.of(context);
    final peerId = widget.chat.peerId ?? '';
    final callId = widget.chat.id;
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
              icon: VibeIconResolver.phone,
              color: VibeColors.success,
              title: l.callAudio,
              subtitle: l.callViaVibe,
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.of(sheetCtx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CallScreen(
                      peerName: widget.chat.title,
                      peerEmoji: '',
                      callId: callId,
                      peerId: peerId,
                      video: false,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: VibeSpacing.xs),
            SheetCallTile(
              icon: VibeIconResolver.video,
              color: context.vibePrimary,
              title: l.callVideo,
              subtitle: l.callViaVibe,
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.of(sheetCtx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CallScreen(
                      peerName: widget.chat.title,
                      peerEmoji: '',
                      callId: callId,
                      peerId: peerId,
                      video: true,
                    ),
                  ),
                );
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
        onExport: _exportChat,
      ),
    );
  }

    /// 8.3.2: «Архивировать» из меню чата — чат уходит в облачный архив.
  void _archiveChat() {
    _backend.setChatArchived(widget.chat.id, archived: true);
    _snack(VibeLocalizations.of(context).chatArchivedSnack);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// 8.3.2: «Удалить чат» — для себя, локально (как в TG: чат исчезает
  /// из ленты; у собеседника история остаётся). Серверного deleteChat нет.
  Future<bool> _deleteChat() async {
    final l = VibeLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.chatDeleteTitle),
        content: Text(l.chatDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l.dialogDelete),
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

  void _exportChat() {
    ChatExportService.instance.exportChat(
      chatId: widget.chat.id,
      chatTitle: widget.chat.peerName ?? widget.chat.id,
      messages: _chat.messages,
    ).then((path) {
      if (path != null && mounted) {
        _snack(VibeLocalizations.of(context).chatExportDone);
      }
    });
  }

  /// 2.12: сведения о чате — тип, участник, число сообщений (локальные данные).
  void _showChatInfo() {    final chat = widget.chat;
    final l = VibeLocalizations.of(context);
    final kind = switch (chat.kind) {
      'pm' => l.chatKindPm,
      'group' => l.chatKindGroup,
      'channel' => l.chatKindChannel,
      _ => l.chatKindChat,
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
                  VibeIconResolver.user,
                  color: context.vibePrimary,
                ),
                title: Text(l.chatMember),
                trailing: Text(peer, style: VibeTypography.bodyMedium),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.forum_outlined, color: context.vibePrimary),
              title: Text(l.chatMessagesCount),
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
    final l = VibeLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.chatClearHistoryTitle),
        content: Text(l.chatClearHistoryBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l.dialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l.actionClear),
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
      builder: (context) => AttachmentMenu(
        onPhoto: () {
          Navigator.of(context).pop();
          _sendPhoto();
        },
        onVoice: () {
          Navigator.of(context).pop();
          _startRecording();
        },
        onMedia: () {
          Navigator.of(context).pop();
          _showAttachments();
        },
        onFile: () {
          Navigator.of(context).pop();
          _sendFile();
        },
        onLocation: () {
          Navigator.of(context).pop();
          _sendLocation(context);
        },
        onContact: () {
          Navigator.of(context).pop();
          _sendContact(context);
        },
        onPoll: () {
          Navigator.of(context).pop();
          _sendPoll(context);
        },
        onGif: () {
          Navigator.of(context).pop();
          _openGifSearch();
        },
      ),
    );
  }

  /// Файл-вложение: системный выбор файла → отправка.
  void _sendFile() {
    unawaited(() async {
      final result = await FilePicker.pickFiles(
        dialogTitle: VibeLocalizations.of(context).actionPickFile,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;
      await _chat.sendFile(File(path));
    }());
  }

  /// Локация: честное ручное задание координат (диалог) → карточка в чате.
  void _sendLocation(BuildContext context) {
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final l = VibeLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.locationTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.locationLatitude,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lngCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.locationLongitude,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(labelText: l.locationLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.dialogCancel),
          ),
          FilledButton(
            onPressed: () {
              final lat = double.tryParse(
                latCtrl.text.trim().replaceAll(',', '.'),
              );
              final lng = double.tryParse(
                lngCtrl.text.trim().replaceAll(',', '.'),
              );
              if (lat == null ||
                  lng == null ||
                  lat < -90 ||
                  lat > 90 ||
                  lng < -180 ||
                  lng > 180) {
                VibeToast.show(ctx, l.locationInvalidCoords);
                return;
              }
              Navigator.of(ctx).pop();
              final label = labelCtrl.text.trim();
              final attach = AttachmentData(
                kind: AttachmentKind.location,
                lat: lat,
                lng: lng,
                label: label.isEmpty ? null : label,
              );
              _chat.sendAttachmentJson(
                AttachmentData.encode(
                  kind: AttachmentKind.location,
                  lat: lat,
                  lng: lng,
                  label: label.isEmpty ? null : label,
                ),
                MsgType.location,
                attach,
              );
            },
            child: Text(l.actionSend),
          ),
        ],
      ),
    );
  }

  /// Контакт: выбор из списка контактов → визитка в чате.
  void _sendContact(BuildContext context) {
    unawaited(() async {
      final contacts = await _backend.listContacts();
      if (!context.mounted) return;
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: VibeSpacing.md),
          children: [
            for (final p in contacts)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: VibeColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    (p.displayName.isEmpty
                            ? '?'
                            : p.displayName.characters.first)
                        .toUpperCase(),
                    style: TextStyle(
                      color: context.vibePrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(p.displayName),
                subtitle: Text('@${p.username}'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  final attach = AttachmentData(
                    kind: AttachmentKind.contact,
                    uid: p.id,
                    contactName: p.displayName,
                    nick: p.username,
                  );
                  _chat.sendAttachmentJson(
                    AttachmentData.encode(
                      kind: AttachmentKind.contact,
                      uid: p.id,
                      contactName: p.displayName,
                      nick: p.username,
                    ),
                    MsgType.contact,
                    attach,
                  );
                },
              ),
            if (contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(VibeSpacing.lg),
                child: Text(
                  VibeLocalizations.of(context).contactEmpty,
                  style: VibeTypography.bodyMedium.copyWith(
                    color: context.vibeTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }());
  }

  /// GIF search panel with Tenor API.
  Color _getWallpaperColor() {
    final s = SettingsService.instance;
    final type = s.wallpaperType;
    if (type == 'color') {
      return Color(s.wallpaperColor);
    } else if (type == 'gradient') {
      return Color(s.wallpaperColor);
    }
    return context.isDarkMode
        ? context.vibeSurfaceLow
        : const Color(0xFFEBE9F4);
  }

  BoxDecoration? _wallpaperDecoration() {
    final s = SettingsService.instance;
    if (s.wallpaperType == 'gradient') {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(s.wallpaperColor), Color(s.wallpaperEndColor)],
        ),
      );
    } else if (s.wallpaperType == 'color') {
      return BoxDecoration(color: Color(s.wallpaperColor));
    }
    return null;
  }

  void _openGifSearch() {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GifSearchPanel(
        onGifSelected: (path) {
          _sendGifFromFile(path);
        },
      ),
    );
  }

  void _sendGifFromFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;
      await _chat.sendGif(file, 'gif.gif');
    } catch (_) {}
  }

  /// Опрос: вопрос + 2–4 варианта → опрос в чате.
  void _sendPoll(BuildContext context) {
    final questionCtrl = TextEditingController();
    final optionCtrls = [TextEditingController(), TextEditingController()];
    final l = VibeLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        bool anonymous = true;
        bool multiple = false;
        bool quiz = false;
        int? correct;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => AlertDialog(
            title: Text(l.pollTitle),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: questionCtrl,
                      decoration: InputDecoration(
                        labelText: l.pollQuestion,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < optionCtrls.length; i++) ...[
                      TextField(
                        controller: optionCtrls[i],
                        decoration: InputDecoration(
                          labelText: '${l.pollOption} ${i + 1}',
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (optionCtrls.length < 10)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setSheetState(() {
                              optionCtrls.add(TextEditingController());
                            });
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(l.pollAddOption),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Анонимный опрос'),
                      value: anonymous,
                      onChanged: (v) => setSheetState(() => anonymous = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Несколько ответов'),
                      value: multiple,
                      onChanged: (v) => setSheetState(() => multiple = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Викторина'),
                      value: quiz,
                      onChanged: (v) => setSheetState(() => quiz = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (quiz) ...[
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        value: correct,
                        hint: const Text('Правильный вариант'),
                        isExpanded: true,
                        items: [
                          for (var i = 0; i < optionCtrls.length; i++)
                            DropdownMenuItem(value: i, child: Text('Вариант ${i + 1}')),
                        ],
                        onChanged: (v) => setSheetState(() => correct = v),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l.dialogCancel),
              ),
              FilledButton(
                onPressed: () {
                  final q = questionCtrl.text.trim();
                  final options = optionCtrls
                      .map((c) => c.text.trim())
                      .where((o) => o.isNotEmpty)
                      .toList();
                  if (q.isEmpty || options.length < 2) {
                    VibeToast.show(ctx, l.pollValidation);
                    return;
                  }
                  Navigator.of(ctx).pop();
                  final attach = AttachmentData(
                    kind: AttachmentKind.poll,
                    question: q,
                    options: options,
                    anonymous: anonymous,
                    multiple: multiple,
                    quiz: quiz,
                    correctOption: correct,
                  );
                  _chat.sendAttachmentJson(
                    AttachmentData.encode(
                      kind: AttachmentKind.poll,
                      question: q,
                      options: options,
                      anonymous: anonymous,
                      multiple: multiple,
                      quiz: quiz,
                      correctOption: correct,
                    ),
                    MsgType.poll,
                    attach,
                  );
                },
                child: Text(l.actionPublish),
              ),
            ],
          ),
        );
      },
    );
  }

  /// «Написать» по контакту-вложению: открыть pm-чат с человеком.
  Future<void> _openContactChat(String uid) async {
    try {
      final chatId = await VibeBackend.instance.ensurePmChat(uid);
      final chat = await VibeBackend.instance.chatById(chatId);
      if (chat == null || !mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(chat: chat),
        ),
      );
    } catch (_) {
      if (mounted) VibeToast.show(context, VibeLocalizations.of(context).errorChatOpenFailed);
    }
  }

  void _showAttachments() {
    final l = VibeLocalizations.of(context);
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
                l.attachmentListTitle,
                style: VibeTypography.subtitle.copyWith(
                  color: context.vibeTextPrimary,
                ),
              ),
              const SizedBox(height: VibeSpacing.sm),
              Text(
                '${photos.length} ${l.attachmentPhoto} · ${voices.length} ${l.attachmentVoice}',
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
                      l.attachmentEmpty,
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
    final l = VibeLocalizations.of(context);
    final msg = _chat.messages[i];
    final isMy = !msg.incoming;
    final hasText = msg.text.isNotEmpty;

    TelegramContextMenu.show(
      context,
      reactions: _emojiOptions.map((e) => e.$1).toList(),
      onReactionTap: (emoji) {
        _chat.addReaction(i, emoji);
      },
      children: [
        ActionTile(
          icon: VibeIconResolver.reply,
          label: l.msgReply,
          onTap: () {
            Navigator.of(context).pop();
            _replyToMsg(i);
          },
        ),
        if (widget.chat.kind == 'group' && msg.incoming)
          ActionTile(
            icon: Icons.reply_all_rounded,
            label: l.msgReplyPrivately,
            onTap: () {
              Navigator.of(context).pop();
              _replyPrivately(i);
            },
          ),
        ActionTile(
          icon: VibeIconResolver.copy,
          label: l.msgCopy,
          onTap: () {
            Navigator.of(context).pop();
            Clipboard.setData(ClipboardData(text: msg.text));
            _snack(l.msgCopied);
          },
        ),
        if (msg.serverId != null)
          ActionTile(
            icon: Icons.link_rounded,
            label: l.msgCopyLink,
            onTap: () {
              Navigator.of(context).pop();
              final link = 'vibe.me/chat/${widget.chat.id}?msg=${msg.serverId}';
              Clipboard.setData(ClipboardData(text: link));
              _snack(l.msgLinkCopied);
            },
          ),
        if (!_isV2Encrypted(msg))
          ActionTile(
            icon: Icons.reply_all_rounded,
            label: l.msgForward,
            onTap: () {
              Navigator.of(context).pop();
              _openForward(msg);
            },
          ),
        ActionTile(
          icon: Icons.bookmark_add_outlined,
          label: l.msgSaveToSaved,
          onTap: () {
            Navigator.of(context).pop();
            _saveToSaved(msg);
          },
        ),
        ActionTile(
          icon: Icons.check_circle_outline_rounded,
          label: l.msgSelect,
          onTap: () {
            Navigator.of(context).pop();
            final id = msg.serverId;
            if (id != null) _chat.toggleSelect(id);
          },
        ),
        if (msg.text.isNotEmpty)
          ActionTile(
            icon: Icons.translate_rounded,
            label: l.msgTranslate,
            onTap: () {
              Navigator.of(context).pop();
              _translateMessage(msg);
            },
          ),
        if (msg.serverId != null && _chat.pins.contains(msg.serverId))
          ActionTile(
            icon: VibeIconResolver.pin,
            label: l.msgUnpin,
            onTap: () {
              Navigator.of(context).pop();
              _chat.unpin(msg.serverId!);
            },
          )
        else if (msg.serverId != null)
          ActionTile(
            icon: VibeIconResolver.pin,
            label: l.msgPin,
            onTap: () {
              Navigator.of(context).pop();
              _chat.setPin(msg.serverId);
            },
          ),
        if (isMy && msg.type == MsgType.text && hasText && !_isV2Encrypted(msg))
          ActionTile(
            icon: VibeIconResolver.edit,
            label: l.msgEdit,
            onTap: () {
              Navigator.of(context).pop();
              _startEdit(i);
            },
          ),
        if (msg.edited)
          ActionTile(
            icon: Icons.history_rounded,
            label: l.msgEditHistory,
            onTap: () {
              Navigator.of(context).pop();
              _showEditHistory(msg);
            },
          ),
        if (msg.incoming)
          ActionTile(
            icon: Icons.flag_outlined,
            label: l.msgReport,
            onTap: () {
              Navigator.of(context).pop();
              _reportMessage(msg);
            },
          ),
        ActionTile(
          icon: Icons.delete_outline_rounded,
          label: l.chatScreenActionDelete,
          isDestructive: true,
          onTap: () {
            Navigator.of(context).pop();
            _deleteMsg(i);
          },
        ),
      ],
    );
  }

  bool _isV2Encrypted(ChatMsg msg) =>
      msg.text == 'Зашифрованное сообщение недоступно' ||
      msg.text == 'Не удалось расшифровать сообщение' ||
      msg.text == '[зашифровано]' ||
      msg.text == 'Неподдерживаемая версия шифрования';

  Future<void> _saveToSaved(ChatMsg msg) async {
    final backend = _backend;
    final l = VibeLocalizations.of(context);
    try {
      final savedId = await backend.ensureSavedChat();
      if (savedId.isEmpty) {
        _snack(l.errorSaveFailed);
        return;
      }
      final m = await backend.forwardMessage(savedId, _msgToBackend(msg));
      if (!mounted) return;
      _snack(m != null ? l.msgSavedToSaved : l.errorSaveFailed);
    } catch (_) {
      if (!mounted) return;
      _snack(VibeLocalizations.of(context).errorServerUnavailable);
    }
  }

  /// Translate message text using device locale (placeholder for API).
  void _translateMessage(ChatMsg msg) {
    HapticFeedback.lightImpact();
    final l = VibeLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TelegramContextMenu(
        children: [
          Padding(
            padding: const EdgeInsets.all(VibeSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.translate_rounded, color: context.vibePrimary, size: 20),
                    const SizedBox(width: VibeSpacing.sm),
                    Text(
                      l.msgTranslated,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.vibeTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: VibeSpacing.sm),
                Text(
                  msg.text,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.vibeTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// История правок сообщения: снимки текста от новых к старым
  /// (как «изменено» в Telegram с просмотром версий).
  Future<void> _showEditHistory(ChatMsg msg) async {
    final serverId = msg.serverId;
    if (serverId == null) return;
    final l = VibeLocalizations.of(context);
    List<MessageEdit> edits;
    try {
      edits = await _backend.listMessageEdits(serverId);
    } catch (_) {
      _snack(l.errorServerUnavailable);
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
                    Text(l.msgEditHistory, style: VibeTypography.subtitle),
                    const SizedBox(height: VibeSpacing.md),
                    Text(
                      l.msgNoEdits,
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
                    Text(l.msgEditHistory, style: VibeTypography.subtitle),
                    const SizedBox(height: VibeSpacing.sm),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: edits.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final e = edits[i];
                          final dt = e.editedAt;
                          final date = '${dt.day}.${dt.month}.${dt.year}';
                          final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      VibeIconResolver.edit,
                                      size: 13,
                                      color: context.vibeTextTertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$date $time',
                                      style: VibeTypography.caption.copyWith(
                                        color: context.vibeTextTertiary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.text,
                                  style: VibeTypography.body.copyWith(
                                    color: context.vibeTextPrimary,
                                  ),
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

  Future<bool?> _pickForwardMode() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.vibeSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: context.vibeDivider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(VibeIconResolver.bubble, color: context.vibePrimary),
              title: const Text('С именем автора'),
              subtitle: const Text('Покажет от кого переслано', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.of(ctx).pop(false),
            ),
            ListTile(
              leading: Icon(Icons.visibility_off_rounded, color: context.vibePrimary),
              title: const Text('Анонимно'),
              subtitle: const Text('Скроет имя автора', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _openForward(ChatMsg msg) async {
    HapticFeedback.mediumImpact();
    final backend = _backend;
    final me = backend.myProfileId;
    if (me == null) return;
    final l = VibeLocalizations.of(context);
    List<VibeChat> chats;
    try {
      chats = await backend.listChats();
    } catch (_) {
      _snack(l.errorServerUnavailable);
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
    final hide = await _pickForwardMode();
    if (hide == null || !mounted) return;
    var ok = 0;
    for (final chatId in ids) {
      try {
        final base = _msgToBackend(msg);
        final author = msg.forwardedFrom ?? (msg.incoming ? widget.chat.title : (VibeBackend.myProfileNotifier.value?.displayName ?? 'Я'));
        final toSend = hide
            ? VibeMessage(
                id: base.id,
                chatId: base.chatId,
                senderId: base.senderId,
                senderName: '',
                senderAvatar: base.senderAvatar,
                text: base.text,
                voicePath: base.voicePath,
                photoPath: base.photoPath,
                videoPath: base.videoPath,
                created: base.created,
                incoming: base.incoming,
                status: base.status,
                localId: base.localId,
                replyText: base.replyText,
                replyAuthor: base.replyAuthor,
                edited: base.edited,
                forwardedFrom: null,
                reactions: base.reactions,
              )
            : (base.forwardedFrom != null ? base : base.copyWith(senderName: author, forwardedFrom: author));
        final m = await backend.forwardMessage(chatId, toSend, hideSender: hide);
        if (m != null) ok++;
      } catch (_) {}
    }
    if (!mounted) return;
    _snack(ok > 0 ? l.msgForwarded : l.msgForwardFailed);
  }

  Future<void> _openForwardSelected() async {
    final backend = _backend;
    final me = backend.myProfileId;
    if (me == null) return;
    final l = VibeLocalizations.of(context);
    List<VibeChat> chats;
    try {
      chats = await backend.listChats();
    } catch (_) {
      _snack(l.errorServerUnavailable);
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
    final hide = await _pickForwardMode();
    if (hide == null || !mounted) return;
    var ok = 0;
    for (final chatId in ids) {
      try {
        await _chat.forwardSelected(chatId, hideSender: hide);
        ok++;
      } catch (_) {}
    }
    if (!mounted) return;
    _snack(ok > 0 ? l.msgForwarded : l.msgForwardFailed);
  }

  Future<void> _openUrl(String raw) async {
    if (raw.startsWith('spoiler:')) {
      if (!mounted) return;
      VibeToast.show(context, raw.substring(8));
      return;
    }
    if (raw.startsWith('@')) {
      if (!mounted) return;
      VibeToast.show(context, '$raw — профиль (в v2)');
      return;
    }
    if (raw.startsWith('#')) {
      if (!mounted) return;
      VibeToast.show(context, 'Поиск по $raw');
      return;
    }
    if (raw.startsWith('tel:')) {
      final uri = Uri.parse(raw);
      final ok = await launchUrl(uri);
      if (!ok && mounted) _snack(VibeLocalizations.of(context).errorOpenLinkFailed);
      return;
    }
    final uri = raw.startsWith('www.') ? Uri.parse('https://$raw') : Uri.parse(raw);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack(VibeLocalizations.of(context).errorOpenLinkFailed);
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

  /// V2.3: Свайп между чатами (горизонтальный swipe → следующий/предыдущий чат).
  void _onHorizontalSwipe(DragEndDetails details) {
    if (widget.chats == null) return;
    final velocity = details.primaryVelocity ?? 0;
    final threshold = 300.0;
    VibeChat? targetChat;
    int? targetIndex;
    if (velocity > threshold) {
      // Свайп вправо → предыдущий чат
      final prevIndex = widget.initialIndex - 1;
      if (prevIndex >= 0 && prevIndex < widget.chats!.length) {
        targetChat = widget.chats![prevIndex];
        targetIndex = prevIndex;
      }
    } else if (velocity < -threshold) {
      // Свайп влево → следующий чат
      final nextIndex = widget.initialIndex + 1;
      if (nextIndex < widget.chats!.length) {
        targetChat = widget.chats![nextIndex];
        targetIndex = nextIndex;
      }
    }
    if (targetChat != null && targetIndex != null) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => ChatScreen(
            chat: targetChat!,
            backend: widget.backend,
            chats: widget.chats,
            initialIndex: targetIndex!,
          ),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: velocity > threshold
                      ? const Offset(-0.05, 0)
                      : const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: VibeAnimations.standard,
                  ),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: VibeAnimations.fadeIn,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = GestureDetector(
      onHorizontalDragEnd: widget.chats != null ? _onHorizontalSwipe : null,
      child: Scaffold(
        backgroundColor: _getWallpaperColor(),
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
              if (_wallpaperDecoration() != null)
                Positioned.fill(child: Container(decoration: _wallpaperDecoration())),
              Column(
                children: [
                  Expanded(
                    child: ListenableBuilder(
                      listenable: SettingsService.instance.appearanceVersion,
                      builder: (context, _) => RepaintBoundary(
                        child: RefreshIndicator(
                          color: context.vibePrimary,
                          backgroundColor: Colors.transparent,
                          displacement: 40,
                          onRefresh: () async {
                            HapticFeedback.mediumImpact();
                            await _chat.loadOlderIfNeeded();
                          },
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
                                                VibeLocalizations.of(context).actionUndoSend,
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
                                        _chat.visibleMessages[i].date,
                                        _chat.visibleMessages[i - 1].date,
                                      );
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (showDate)
                                        MessageDateDivider(
                                          date: _chat.visibleMessages[i].date,
                                        ),
                                      MessageBubble(
                                        msg: _chat.visibleMessages[i],
                                        key: _keyOf(_bubbleKeyFor(i)),
                                        isFirstInGroup:
                                            ChatController.isFirstInGroup(
                                              _chat.visibleMessages,
                                              i,
                                            ),
                                        isLastInGroup:
                                            ChatController.isLastInGroup(
                                              _chat.visibleMessages,
                                              i,
                                            ),
                                        isGroup: widget.chat.kind == 'group',
                                        onHeart: () => _chat.heartReact(i),
                                        onLongPress: () =>
                                            _showMessageActions(i),
                                        onReply: () => _replyToMsg(i),
                                        onReplyTap: _chat.visibleMessages[i].replyTo != null
                                            ? () => _chat.jumpToReplyId(_chat.visibleMessages[i].replyTo!)
                                            : null,
                                        onOpenUrl: _openUrl,
                                        scrollController: _scroll,
                                        player: _player,
                                        highlight:
                                            _chat.pinFlashId != null &&
                                            _chat.visibleMessages[i].serverId ==
                                                _chat.pinFlashId,
                                        chatId: _chat.chatId,
                                        pollVotes: _chat.visibleMessages[i].type ==
                                                    MsgType.poll &&
                                                _chat.visibleMessages[i].serverId !=
                                                    null
                                            ? computePollVotes(
                                                _chat.visibleMessages,
                                                _chat.visibleMessages[i].serverId!,
                                              )
                                            : const [],
                                        myVote: _chat.visibleMessages[i].type ==
                                                    MsgType.poll &&
                                                _chat.visibleMessages[i].serverId !=
                                                    null
                                            ? myPollVote(
                                                _chat.visibleMessages,
                                                _chat.visibleMessages[i].serverId!,
                                              )
                                            : null,
                                        onOpenContact: _openContactChat,
                                        onVote: _chat.visibleMessages[i]
                                                    .serverId !=
                                                null
                                            ? (opt) => _chat.sendPollVote(
                                                _chat.visibleMessages[i].serverId!,
                                                opt,
                                              )
                                            : null,
                                        isSelected: _chat.selectedMsgIds.contains(
                                          _chat.messages[i].serverId,
                                        ),
                                        selectionMode: _chat.selectionMode,
                                        onToggleSelect: () {
                                          final id = _chat.messages[i].serverId;
                                          if (id != null) _chat.toggleSelect(id);
                                        },
                                      ),
                                    ],
                                  );
                                }, childCount: _chat.visibleMessages.length),
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
                      if (_chat.selectionMode)
                        SelectionToolbar(
                          selectedCount: _chat.selectedMsgIds.length,
                          onClose: () => _chat.clearSelection(),
                          onDelete: () async {
                            await _chat.deleteSelected(everyone: false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(VibeLocalizations.of(context).msgDeleted)),
                              );
                            }
                          },
                          onForward: () => _openForwardSelected(),
                          onCopy: () {
                            HapticFeedback.selectionClick();
                            _chat.copySelectedText();
                            _chat.clearSelection();
                          },
                        )
                      else
                        ChatAppBar(
                        chat: widget.chat,
                        groupTitle: _chat.groupTitle,
                        peerTyping: _chat.peerTyping,
                            typingUsers: _chat.typingUsers,
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
                    child: UnreadPlank(
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
                    child: StickDatePlank(label: _stickDateLabel!),
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
    ),
    );

    return SwipeBackWrapper(child: scaffold);
  }

  /// Плашка «Закреплённое сообщение» под шапкой (как в Telegram).
  /// При нескольких закрепах показывает «+N ещё» и открывает список.
  Widget _buildPinnedBanner(BuildContext context) {
    final topId = _chat.pinMsgId;
    if (topId == null) return const SizedBox.shrink();
    final extra = _chat.pins.length - 1;
    final preview = _pinPreview(topId);
    final l = VibeLocalizations.of(context);
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
                  VibeIconResolver.pin,
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
                    '${l.chatMorePins} $extra',
                    style: VibeTypography.caption.copyWith(
                      color: context.vibePrimary,
                    ),
                  ),
                ],
                const SizedBox(width: VibeSpacing.sm),
                GestureDetector(
                  onTap: () => _chat.setPin(null),
                  child: Icon(
                    VibeIconResolver.close,
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
    final l = VibeLocalizations.of(context);
    for (final m in _chat.messages) {
      if (m.serverId == serverId) {
        return (m.type == MsgType.text && m.text.isNotEmpty)
            ? m.text
            : l.chatPinnedMessage;
      }
    }
    return l.chatPinnedMessage;
  }

  /// Список всех закреплённых сообщений чата.
  void _showAllPins() {
    final l = VibeLocalizations.of(context);
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
                l.chatPinnedMessages,
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
                    leading: Icon(VibeIconResolver.pin, size: 20),
                    title: Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(VibeIconResolver.close, size: 20),
                      tooltip: l.msgUnpin,
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
                  author: VibeLocalizations.of(context).chatEditing,
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
                      : VibeLocalizations.of(context).chatYou,
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
                              VibeIconResolver.clock,
                              size: 18,
                              color: context.vibePrimary,
                            ),
                            const SizedBox(width: VibeSpacing.xs),
                            Flexible(
                              child: Text(
                                pending.length == 1
                                    ? '${VibeLocalizations.of(context).scheduleScheduled} · ${_scheduleLabel(first.when)}'
                                    : '${VibeLocalizations.of(context).scheduleScheduled}: ${pending.length} · '
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
                      VibeIconResolver.video,
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
                  icon: Icon(VibeIconResolver.attach),
                  color: context.vibePrimary,
                  tooltip: VibeLocalizations.of(context).attachmentTitle,
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
                          child: MentionsAutocomplete(
                            query: _mentionQuery,
                            onMentionSelected: (username) {
                              final text = _input.text;
                              final cursorPos = _input.selection.base.offset;
                              final beforeCursor = text.substring(0, cursorPos);
                              final atIndex = beforeCursor.lastIndexOf('@');
                              if (atIndex >= 0) {
                                final afterCursor = text.substring(cursorPos);
                                final newText = '${text.substring(0, atIndex)}@$username $afterCursor';
                                _input.text = newText;
                                final newCursorPos = atIndex + username.length + 2;
                                _input.selection = TextSelection.collapsed(offset: newCursorPos);
                              }
                              setState(() => _mentionQuery = '');
                            },
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
                                hintText: VibeLocalizations.of(context).chatMessageHint,
                                hintStyle: VibeTypography.body.copyWith(
                                  color: context.vibeTextTertiary,
                                ),
                              ),
                              onSubmitted: SettingsService.instance.sendByEnter
                                  ? (_) => _send()
                                  : null,
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
                  tooltip: VibeLocalizations.of(context).chatEmojiStickers,
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
                backend: _backend,
                onEmoji: (e) => setState(() => _input.text += e),
                onSticker: _sendSticker,
                onGif: _sendGif,
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
      _snack(VibeLocalizations.of(context).errorRecordStartFailed);
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
      if (send) _snack(VibeLocalizations.of(context).errorTooShortRecording);
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