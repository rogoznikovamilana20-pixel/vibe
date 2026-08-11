import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_glass_surface.dart';
import '../core/widgets/vibe_offline_banner.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../core/widgets/vibe_top_frost.dart';
import '../data/backend.dart';
import '../data/mock/mock_data.dart';
import '../data/passcode_service.dart';
import '../data/settings_service.dart';
import '../../main.dart';
import 'aurion_screen.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'lock_screen.dart';
import 'new_message_screen.dart';
import 'search_screen.dart';
import 'story_composer_screen.dart';
import 'story_player.dart';

/// Список чатов: сториз, папки, свайпы, мультивыбор, боковое меню.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    super.key,
    required this.userName,
    this.userEmoji,
    this.onOpenTab,
  });

  final String userName;
  final String? userEmoji;

  /// Переход на вкладку нижнего бара (Aurion / Профиль) из боковой шторки.
  final ValueChanged<int>? onOpenTab;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

enum _Folder { all, personal, groups, channels, business }

class _ChatListScreenState extends State<ChatListScreen> {
  _Folder _folder = _Folder.all;
  final _selected = <String>{};
  late List<VibeChat> _chats = [];
  final _stories = <Uint8List>[];
  final _remoteStories = <VibeStory>[];

  // Просмотренные истории: непросмотренные всегда выдвигаются вперёд.
  final _storySeen = <String>{};

  // Статус чатов.
  final _archived = <String>{};
  final _dnd = <String>{};
  final _hidden = <String>{};
  final _read = <String>{};

  // Режимы просмотра.
  bool _showArchive = false;
  bool _showHidden = false;
  // Защита от двойного открытия «Избранного» (двойной тап = один экран).
  bool _openingSaved = false;

  bool get _selectionMode => _selected.isNotEmpty;

  // Notifier вместо setState: при скролле перестраиваются только оверлеи
  // (шапка/фрост/коллапс-бар), а не весь список чатов — это убирает дёрганье.
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);

  List<VibeChat> _visible = [];
  final Set<String> _pinned = {};

  @override
  void initState() {
    super.initState();
    _pinned.addAll(SettingsService.instance.pinnedChats);
    _dnd.addAll(SettingsService.instance.mutedChats);
    _dnd.addAll(VibeBackend.instance.mutedNotifier.value);
    _archived.addAll(VibeBackend.instance.archivedNotifier.value);
    SettingsService.instance.mutedVersion.addListener(_syncMuted);
    SettingsService.instance.blockedVersion.addListener(_syncBlocked);
    VibeBackend.instance.archivedNotifier.addListener(_syncCloudArchive);
    VibeBackend.instance.mutedNotifier.addListener(_syncCloudMuted);
    _loadChats();
    _loadStories();
    _streamSub = VibeBackend.instance.stream.listen((msg) {
      // Мгновенное обновление превью последнего сообщения (как в TG) —
      // без ожидания перезагрузки списка с сервера.
      _applyLivePreview(msg);
      _scheduleReload();
    });
    _chatSub = VibeBackend.instance.chatEvents.listen((_) => _scheduleReload());
    // Живые онлайн-статусы: прилетело обновление — точки «в сети» меняются
    // без ожидания тикера.
    VibeBackend.instance.presenceVersion.addListener(_onPresenceChanged);
    // Страховка, если websocket недоступен (сеть/Дузм): список всё равно
    // остаётся свежим с лёгким интервалом.
    _ticker = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _scheduleReload(),
    );
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _chatSub?.cancel();
    SettingsService.instance.mutedVersion.removeListener(_syncMuted);
    SettingsService.instance.blockedVersion.removeListener(_syncBlocked);
    VibeBackend.instance.archivedNotifier.removeListener(_syncCloudArchive);
    VibeBackend.instance.mutedNotifier.removeListener(_syncCloudMuted);
    VibeBackend.instance.presenceVersion.removeListener(_onPresenceChanged);
    _reloadTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  /// «Не беспокоить» могли выключить из экрана чата — синхронизируем
  /// локальный набор с настройками.
  void _syncMuted() {
    if (!mounted) return;
    final muted = SettingsService.instance.mutedChats.toSet();
    if (muted.length != _dnd.length || muted.difference(_dnd).isNotEmpty) {
      setState(() {
        _dnd
          ..clear()
          ..addAll(muted);
      });
    }
  }

  /// Облачный архив (другое устройство / вход) → локальный набор.
  void _syncCloudArchive() {
    if (!mounted) return;
    final cloud = VibeBackend.instance.archivedNotifier.value;
    if (cloud.length != _archived.length ||
        cloud.difference(_archived).isNotEmpty) {
      setState(() {
        _archived
          ..clear()
          ..addAll(cloud);
      });
    }
  }

  /// Облачный DND (другое устройство / вход) → локальный набор.
  void _syncCloudMuted() {
    if (!mounted) return;
    final cloud = VibeBackend.instance.mutedNotifier.value;
    if (cloud.length != _dnd.length || cloud.difference(_dnd).isNotEmpty) {
      setState(() {
        _dnd
          ..clear()
          ..addAll(cloud);
      });
      SettingsService.instance.setMutedChats(_dnd.toList());
    }
  }

  /// Список заблокированных изменился — пересчитываем видимые чаты.
  void _syncBlocked() {
    if (!mounted) return;
    setState(() {});
  }

  StreamSubscription<dynamic>? _streamSub;
  StreamSubscription<dynamic>? _chatSub;
  Timer? _reloadTimer;
  Timer? _ticker;

  Future<void> _onPresenceChanged() async {
    if (!mounted) return;
    final chats = await VibeBackend.instance.listChats();
    if (!mounted) return;
    setState(() => _chats = chats);
  }

  void _scheduleReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 400), () {
      _loadChats();
      _loadStories();
    });
  }

  Future<void> _loadChats() async {
    // 1. Мгновенно грузим из кэша (как в Telegram) — только если текущий
    //    список пуст: иначе фоновые релоады «мелькают» устаревшими данными.
    if (_chats.isEmpty) {
      final cached = await VibeBackend.instance.getOfflineChats();
      if (cached.isNotEmpty && mounted) {
        setState(() => _chats = cached);
      }
    }

    // 2. Спокойно обновляем из сети
    try {
      final fresh = await VibeBackend.instance.listChats();
      if (!mounted) return;
      setState(() => _chats = fresh);
    } catch (_) {
      // Если сети нет, оставляем кэш
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

  /// Мгновенно показать свежее сообщение в превью чата и поднять чат наверх.
  void _applyLivePreview(VibeMessage msg) {
    final i = _chats.indexWhere((c) => c.id == msg.chatId);
    if (i < 0 || !mounted) return;
    final old = _chats[i];
    final updated = VibeChat(
      id: old.id,
      title: old.title,
      kind: old.kind,
      lastMessage: _previewOf(msg),
      lastTime: VibeBackend.formatTime(msg.created.toIso8601String()),
      unread: old.unread,
      peerName: old.peerName,
      peerAvatar: old.peerAvatar,
      peerId: old.peerId,
      peerOnline: old.peerOnline,
    );
    setState(() {
      _chats.removeAt(i);
      _chats.insert(0, updated);
    });
  }

  /// Сколько непрочитанных у чата (с учётом «прочитанных» свайпом).
  int _unreadOf(VibeChat chat) {
    if (_read.contains(chat.id)) return 0;
    return chat.unread;
  }

  /// Пометить выделенные чаты прочитанными.
  void _markRead() {
    HapticFeedback.lightImpact();
    setState(() {
      _read.addAll(_selected);
      _selected.clear();
    });
    _snack('Прочитано');
  }

  /// Пометить выделенные чаты (убрать из основного списка).
  void _markArchived() {
    HapticFeedback.lightImpact();
    setState(() {
      _archived.addAll(_selected);
      _selected.clear();
    });
    for (final id in _archived) {
      VibeBackend.instance.setChatArchived(id, archived: true);
    }
    _snack('В архив: ${_archived.length}');
  }

  /// Спрятать выделенные чаты (в HMS-список).
  void _markHidden() {
    HapticFeedback.lightImpact();
    setState(() {
      _hidden.addAll(_selected);
      _selected.clear();
      _showHidden = true;
      _showArchive = false;
    });
    _snack('Скрыто: ${_hidden.length}');
  }

  bool _onScroll(ScrollNotification n) {
    // Реагируем ТОЛЬКО на вертикальный скролл главного списка. Вложенные
    // горизонтальные скроллеры (пилюли фильтров, лента сториз) шлют свои
    // метрики, иначе прокрутка их в сторону «гасит» большую шапку «Чаты».
    if (n.metrics.axis != Axis.vertical) return false;
    if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
      final value = n.metrics.pixels;
      if ((value - _scrollOffset.value).abs() > 0.5) {
        // Не setState: уведомляем только «лёгкие» слушатели прокрутки.
        _scrollOffset.value = value;
      }
    }
    return false;
  }

  void _togglePin(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_pinned.contains(id)) {
        _pinned.remove(id);
      } else {
        _pinned.add(id);
      }
    });
    SettingsService.instance.setPinnedChats(_pinned.toList());
  }

  /// Меню чата по долгому нажатию: закрепить, архив, уведомления, выбрать.
  Future<void> _showChatMenu(BuildContext context, VibeChat chat) {
    final pinned = _pinned.contains(chat.id);
    final archived = _archived.contains(chat.id);
    final dnd = _dnd.contains(chat.id);
    final sheetTheme = Theme.of(context);
    final sheetBg = sheetTheme.brightness == Brightness.dark
        ? VibeColors.surface2Dark
        : VibeColors.surface2Light;
    final sheetText = Color(
      sheetTheme.brightness == Brightness.dark ? 0xFFF5F3FA : 0xFF1C1B22,
    );
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: pinned ? Colors.amber : Colors.grey,
              ),
              title: Text(
                pinned ? 'Открепить чат' : 'Закрепить чат',
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _togglePin(chat.id);
              },
            ),
            ListTile(
              leading: Icon(
                dnd
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: Colors.grey,
              ),
              title: Text(
                dnd ? 'Включить уведомления' : 'Не беспокоить',
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                setState(() {
                  if (dnd) {
                    _dnd.remove(chat.id);
                  } else {
                    _dnd.add(chat.id);
                  }
                });
                SettingsService.instance.setMutedChats(_dnd.toList());
                VibeBackend.instance.setChatMuted(chat.id, muted: !dnd);
              },
            ),
            ListTile(
              leading: Icon(
                archived ? Icons.unarchive_rounded : Icons.archive_rounded,
                color: Colors.grey,
              ),
              title: Text(
                archived ? 'Разархивировать' : 'В архив',
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                setState(() {
                  if (archived) {
                    _archived.remove(chat.id);
                  } else {
                    _archived.add(chat.id);
                  }
                });
                VibeBackend.instance
                    .setChatArchived(chat.id, archived: !archived);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_rounded, color: Colors.grey),
              title: Text(
                'Отметить прочитанным',
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                if (chat.unread > 0) {
                  setState(() => _read.add(chat.id));
                }
              },
            ),
            Divider(color: Color(0x1FFFFFFF).withValues(alpha: 0.4)),
            ListTile(
              leading: const Icon(Icons.checklist_rounded, color: Colors.grey),
              title: Text(
                'Выбрать чаты',
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _toggleSelect(chat.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static const _folders = [
    (_Folder.all, 'Все'),
    (_Folder.personal, 'Личные'),
    (_Folder.groups, 'Группы'),
    (_Folder.channels, 'Каналы'),
    (_Folder.business, 'Бизнес'),
  ];

  _Folder _folderOf(VibeChat chat) {
    switch (chat.kind) {
      case 'group':
        return _Folder.groups;
      case 'channel':
        return _Folder.channels;
      case 'biz':
        return _Folder.business;
      default:
        return _Folder.personal;
    }
  }

  void _toggleSelect(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Заблокированные пользователи: их личные чаты скрыты из списка.
    final blocked = SettingsService.instance.blockedUsers;
    final inFolder = _folder == _Folder.all
        ? _chats.where((c) => !blocked.contains(c.peerId)).toList()
        : _chats
            .where((c) => !blocked.contains(c.peerId) && _folderOf(c) == _folder)
            .toList();

    // Режим просмотра: архив / скрытые / основной список.
    final List<VibeChat> visible;
    if (_showArchive) {
      visible = inFolder.where((c) => _archived.contains(c.id)).toList();
    } else if (_showHidden) {
      visible = inFolder.where((c) => _hidden.contains(c.id)).toList();
    } else {
      visible = inFolder
          .where((c) => !_archived.contains(c.id) && !_hidden.contains(c.id))
          .toList();
    }
    _visible = visible;

    // Закреплённые — всегда первыми (в основном списке).
    final showPinSection =
        !_showArchive &&
        !_showHidden &&
        _pinned.isNotEmpty &&
        visible.any((c) => _pinned.contains(c.id));
    if (showPinSection) {
      visible.sort((a, b) {
        final pa = _pinned.contains(a.id) ? 0 : 1;
        final pb = _pinned.contains(b.id) ? 0 : 1;
        return pa.compareTo(pb);
      });
    }
    final pinExtra = showPinSection ? 1 : 0;
    final archiveExtra =
        (_archived.isNotEmpty &&
            !_showArchive &&
            !_showHidden &&
            _folder == _Folder.all)
        ? 1
        : 0;

    return ListenableBuilder(
      listenable: SettingsService.instance.appearanceVersion,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: SafeArea(
                  bottom: false,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                      decelerationRate: ScrollDecelerationRate.normal,
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: ValueListenableBuilder<double>(
                          valueListenable: _scrollOffset,
                          builder: (context, offset, _) => Opacity(
                            // Исчезает очень быстро (к 40 пикселям)
                            opacity: (1.0 - (offset / 40)).clamp(0.0, 1.0),
                            child: _buildHeader(context),
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
                      // Компактный отступ сверху
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(child: _buildStories(context)),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      SliverToBoxAdapter(child: _buildTab(context)),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: VibeSpacing.md),
                      ),
                      SliverToBoxAdapter(child: _buildManageRow(context)),
                      if (!_showArchive && !_showHidden)
                        SliverToBoxAdapter(child: _buildAurionCard(context)),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: VibeSpacing.xs),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            if (i == 0 && showPinSection) {
                              return _buildPinnedHeader(context);
                            }
                            if (i == pinExtra && archiveExtra == 1) {
                              return _buildArchiveTile(context);
                            }
                            final index = i - pinExtra - archiveExtra;
                            if (index >= visible.length) {
                              return const SizedBox.shrink();
                            }
                            return _buildChatTile(context, visible[index]);
                          },
                          childCount: visible.length + pinExtra + archiveExtra,
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(
                          height:
                              VibeSizes.bottomNavHeight + VibeSpacing.xxl * 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Морозный «бесшовный» блюрик под верхней кромкой: проявляется
            // только по мере скролла, когда контент реально проходит под
            // баром. В покое — прозрачен.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 84,
              child: IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, offset, _) => Opacity(
                    opacity: ((offset - 40) / 200).clamp(0.0, 1.0),
                    child: const VibeTopFrost(),
                  ),
                ),
              ),
            ),
            // Коллапс большого заголовка: когда лента прокручена так, что
            // крупный заголовок уходит вверх, поверх проходящего контента
            // плавно вплывает компактный морозный бар (как в Telegram):
            // проезжающие под ним элементы деликатно подмораживаются блюром.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: VibeSpacing.lg,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _scrollOffset,
                      builder: (context, offset, _) => VibeCollapsedTopBar(
                        // Начинает появляться только после 60 пикселей, когда большая шапка уже точно скрыта
                        progress: ((offset - 60) / 180).clamp(0.0, 1.0),
                        title: const VibeTopBarTitle('Чаты'),
                        actions: [
                          if (PasscodeService.instance.hasPasscode)
                            IconButton(
                              onPressed: () => _lockNow(context),
                              icon: const Icon(Icons.lock_rounded, size: 22),
                              color: context.vibeTextPrimary,
                              tooltip: 'Заблокировать',
                            ),
                          IconButton(
                            onPressed: () => _openSearch(context),
                            icon: const Icon(Icons.search_rounded, size: 22),
                            color: context.vibeTextPrimary,
                            tooltip: 'Поиск',
                          ),
                          IconButton(
                            onPressed: () => _showChatsMenu(context),
                            icon: const Icon(Icons.more_vert_rounded, size: 22),
                            color: context.vibeTextPrimary,
                            tooltip: 'Меню чатов',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: VibeSpacing.lg,
              bottom: VibeSizes.bottomNavHeight + VibeSpacing.md,
              child: _ComposeFAB(onTap: () => _openCompose(context)),
            ),
          ],
        ),
      ),
    );
  }

  void _openCompose(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const NewMessageScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.05, 0),
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

  Widget _buildHeader(BuildContext context) {
    if (_selectionMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          VibeSpacing.lg,
          VibeSpacing.sm,
          VibeSpacing.lg,
          VibeSpacing.sm,
        ),
        child: Row(
          children: [
            Text(
              '${_selected.length}',
              style: VibeTypography.subtitle.copyWith(
                color: context.vibePrimary,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => setState(_selected.clear),
              icon: const Icon(Icons.clear_rounded),
              tooltip: 'Снять выделение',
            ),
            IconButton(
              onPressed: _markRead,
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Прочитано',
            ),
            IconButton(
              onPressed: _markArchived,
              icon: const Icon(Icons.archive_rounded),
              tooltip: 'В архив',
            ),
            IconButton(
              onPressed: _markHidden,
              icon: const Icon(Icons.lock_rounded),
              tooltip: 'Скрыть',
            ),
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _chats.removeWhere(_selected.contains);
                  _selected.clear();
                });
                _snack('Удалено');
              },
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Удалить',
            ),
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(_selected.clear);
              },
              icon: const Icon(Icons.check_rounded),
              tooltip: 'Готово',
            ),
          ],
        ),
      );
    }
    return VibeTopBar(
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VibeTypography.caption.copyWith(
              color: context.vibeTextSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 1),
          const VibeTopBarTitle('Чаты'),
        ],
      ),
      actions: [
        if (PasscodeService.instance.hasPasscode)
          VibeTopBarIcon(
            icon: Icons.lock_rounded,
            tooltip: 'Заблокировать',
            onTap: () => _lockNow(context),
          ),
        VibeTopBarIcon(
          icon: Icons.search_rounded,
          tooltip: 'Поиск',
          onTap: () => _openSearch(context),
        ),
        VibeTopBarIcon(
          icon: Icons.more_vert_rounded,
          tooltip: 'Меню чатов',
          onTap: () => _showChatsMenu(context),
        ),
      ],
    );
  }

  void _lockNow(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) => const LockScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: VibeAnimations.fadeIn,
      ),
    );
  }

  /// Меню ⋯ в списке чатов — как в Telegram:
  /// «Ночной режим», «Создать группу», «Избранное».
  Future<void> _showChatsMenu(BuildContext context) async {
    final isDark = context.isDarkMode;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark
          ? VibeColors.surface2Dark
          : VibeColors.surface2Light,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: context.vibePrimary,
              ),
              title: Text(
                isDark ? 'Дневной режим' : 'Ночной режим',
                style: TextStyle(
                  color: isDark
                      ? VibeColors.textPrimaryDark
                      : VibeColors.textPrimaryLight,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                HapticFeedback.selectionClick();
                final next = isDark ? ThemeMode.light : ThemeMode.dark;
                SettingsService.instance.setThemeMode(next);
                VibeApp.themeModeNotifier.value = next;
              },
            ),
            ListTile(
              leading: Icon(
                Icons.group_add_outlined,
                color: context.vibePrimary,
              ),
              title: Text(
                'Создать группу',
                style: TextStyle(
                  color: isDark
                      ? VibeColors.textPrimaryDark
                      : VibeColors.textPrimaryLight,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.bookmark_outline_rounded,
                color: context.vibePrimary,
              ),
              title: Text(
                'Избранное',
                style: TextStyle(
                  color: isDark
                      ? VibeColors.textPrimaryDark
                      : VibeColors.textPrimaryLight,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _openSaved();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openSaved() async {
    if (_openingSaved) return;
    _openingSaved = true;
    try {
      final chatId = await VibeBackend.instance.ensureSavedChat();
      if (chatId.isEmpty || !mounted) return;
      final chat = await VibeBackend.instance.chatById(chatId);
      if (chat == null || !mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)));
    } finally {
      _openingSaved = false;
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Доброй ночи, ${widget.userName}';
    if (h < 12) return 'Доброе утро, ${widget.userName}';
    if (h < 18) return 'Добрый день, ${widget.userName}';
    return 'Добрый вечер, ${widget.userName}';
  }

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const SearchScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.05, 0),
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

  Future<void> _loadStories() async {
    try {
      final stories = await VibeBackend.instance.listStories();
      if (!mounted) return;
      setState(
        () => _remoteStories
          ..clear()
          ..addAll(stories),
      );
    } catch (_) {
      // Сеть недоступна — лента уже содержит локальные и демо-истории.
    }
  }

  /// Отсортированный плейлист карусели, как в Telegram:
  /// непросмотренные — вперёд, просмотренные — назад, внутри — алфавит.
  /// Своя история всегда первая (кружок «+» без историй — тоже в начале).
  List<StoryItem> _storyItems() {
    final items = <StoryItem>[];
    for (var i = 0; i < _stories.length; i++) {
      final id = 'own-$i';
      items.add(
        StoryItem(
          id: id,
          author: 'Моя история',
          photo: _stories[i],
          isOwn: true,
          seen: _storySeen.contains(id),
        ),
      );
    }
    for (final s in _remoteStories) {
      final id = 'remote-${s.id}';
      items.add(
        StoryItem(
          id: id,
          author: s.authorName ?? 'Друг',
          photoUrl: s.photoUrl,
          seen: _storySeen.contains(id),
        ),
      );
    }
    if (MockData.showDemoStories) {
      for (final n in MockData.storyNames) {
        final id = 'mock-$n';
        items.add(StoryItem(id: id, author: n, seen: _storySeen.contains(id)));
      }
    }
    final own = items.where((i) => i.isOwn).toList();
    final others = items.where((i) => !i.isOwn).toList()
      ..sort((a, b) {
        if (a.seen != b.seen) return a.seen ? 1 : -1;
        return a.author.toLowerCase().compareTo(b.author.toLowerCase());
      });
    return [...own, ...others];
  }

  Widget _buildStories(BuildContext context) {
    final items = _storyItems();
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: VibeSpacing.xl),
        itemBuilder: (context, i) {
          final item = items[i];
          final isMyCircle = item.isOwn && i == 0;
          return _StoryCircle(
            item: item,
            placeholder: isMyCircle && _stories.isEmpty,
            onTap: isMyCircle && _stories.isEmpty
                ? () => _addStory(context)
                : () => _openStoryAt(items, i),
          );
        },
      ),
    );
  }

  /// Полноэкранный композер (камера + галерея), как в Telegram.
  Future<void> _addStory(BuildContext context) async {
    HapticFeedback.lightImpact();
    final result = await Navigator.of(context).push<StoryComposerResult>(
      MaterialPageRoute(builder: (_) => const StoryComposerScreen()),
    );
    if (result == null || !mounted) return;
    try {
      await VibeBackend.instance.uploadStory(result.bytes);
      setState(() => _stories.insert(0, result.bytes));
      _snack('История опубликована · синхронизирована');
    } catch (e) {
      _snack('Не удалось опубликовать: $e');
    }
  }

  void _openStoryAt(List<StoryItem> items, int index) {
    if (items.isEmpty) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryPlayerScreen(
          items: items,
          startIndex: index.clamp(0, items.length - 1),
          onSeen: (item) {
            if (!_storySeen.contains(item.id)) {
              setState(() => _storySeen.add(item.id));
            }
          },
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
        itemCount: _folders.length,
        itemBuilder: (context, i) {
          final f = _folders[i];
          final active = f.$1 == _folder;
          return Padding(
            padding: const EdgeInsets.only(right: 24),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick(); // ТАКТИЛЬНЫЙ ОТКЛИК
                setState(() => _folder = f.$1);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: VibeAnimations.fast,
                    style: VibeTypography.bodyMedium.copyWith(
                      color: active
                          ? context.vibePrimary
                          : context.vibeTextSecondary,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 15,
                    ),
                    child: Text(f.$2),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: VibeAnimations.fast,
                    curve: Curves.easeOutCubic,
                    width: active ? 28 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: context.vibePrimary,
                      borderRadius: BorderRadius.circular(VibeRadius.badge),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildManageRow(BuildContext context) {
    // В режиме просмотра архива/скрытых — строка «назад».
    if (_showArchive || _showHidden) {
      final label = _showArchive ? 'Архив' : 'Скрытые';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
        child: Row(
          children: [
            VibeGlassSurface(
              radius: VibeRadius.badge,
              color: VibeColors.vivid.withValues(alpha: 0.45),
              borderColor: Colors.white.withValues(alpha: 0.25),
              padding: const EdgeInsets.symmetric(
                horizontal: VibeSpacing.md,
                vertical: VibeSpacing.sm - 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showHidden ? Icons.lock_rounded : Icons.archive_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: VibeSpacing.sm),
                  Text(
                    label,
                    style: VibeTypography.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: VibeSpacing.sm),
                  Text(
                    '${_visible.length}',
                    style: VibeTypography.caption.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Flexible(
              child: GestureDetector(
                onTap: () => setState(() {
                  _showArchive = false;
                  _showHidden = false;
                }),
                child: Text(
                  'К чатам →',
                  overflow: TextOverflow.ellipsis,
                  style: VibeTypography.bodyMedium.copyWith(
                    color: context.vibePrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Обычный режим: показываем счётчики, если что-то скрыто.
    final chips = <Widget>[];
    if (_archived.isNotEmpty) {
      chips.add(_manageChip(context, 'Архив', _archived.length));
    }
    if (_hidden.isNotEmpty) {
      chips.add(_manageChip(context, 'Скрытые чаты', _hidden.length));
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
      child: Row(
        children: [
          ...chips,
          const Spacer(),
          if (_dnd.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.notifications_off_rounded,
                  size: 16,
                  color: context.vibeTextTertiary,
                ),
                const SizedBox(width: VibeSpacing.xs),
                Text(
                  '${_dnd.length}',
                  style: VibeTypography.caption.copyWith(
                    color: context.vibeTextTertiary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _manageChip(BuildContext context, String label, int count) {
    final active =
        (label == 'Архив' && _showArchive) ||
        (label == 'Скрытые чаты' && _showHidden);
    return Padding(
      padding: const EdgeInsets.only(right: VibeSpacing.sm),
      child: GestureDetector(
        onTap: () => setState(() {
          _showArchive = label == 'Архив';
          _showHidden = label == 'Скрытые чаты';
        }),
        child: VibeGlassSurface(
          radius: VibeRadius.badge,
          blur: VibeBlur.nav,
          color: active ? VibeColors.vivid.withValues(alpha: 0.55) : null,
          borderColor: active
              ? Colors.white.withValues(alpha: 0.25)
              : context.vibeGlassBorder,
          padding: const EdgeInsets.symmetric(
            horizontal: VibeSpacing.md,
            vertical: VibeSpacing.sm - 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                label == 'Архив' ? Icons.archive_rounded : Icons.lock_rounded,
                size: 16,
                color: active ? Colors.white : context.vibeTextSecondary,
              ),
              const SizedBox(width: VibeSpacing.xs),
              Text(
                label,
                style: VibeTypography.bodyMedium.copyWith(
                  color: active ? Colors.white : context.vibeTextSecondary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: VibeSpacing.xs),
              Text(
                '$count',
                style: VibeTypography.caption.copyWith(
                  color: active ? Colors.white70 : context.vibeTextTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAurionCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VibeSpacing.lg,
        VibeSpacing.sm,
        VibeSpacing.lg,
        0,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(VibeRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(VibeRadius.card),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AurionScreen(userName: widget.userName),
            ),
          ),
          splashColor: context.vibePrimary.withValues(alpha: 0.10),
          highlightColor: context.vibePrimary.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: VibeSpacing.lg,
              vertical: VibeSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: context.vibeSurface,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.vibePrimary.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(VibeRadius.card),
              border: Border.all(color: context.vibeDivider),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.vibePrimary.withValues(alpha: 0.14),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: context.vibePrimary,
                      size: VibeSizes.iconMd,
                    ),
                  ),
                ),
                const SizedBox(width: VibeSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Aurion',
                            style: VibeTypography.subtitle.copyWith(
                              color: context.vibeTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: VibeSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.vibePrimary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(
                                VibeRadius.sm,
                              ),
                            ),
                            child: Text(
                              'AI',
                              style: VibeTypography.label.copyWith(
                                color: context.vibePrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Твой встроенный ИИ-ассистент',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VibeTypography.caption.copyWith(
                          color: context.vibeTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: context.vibeTextTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VibeSpacing.lg,
        VibeSpacing.xs,
        VibeSpacing.lg,
        VibeSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            Icons.push_pin_rounded,
            size: 16,
            color: context.vibeTextSecondary,
          ),
          const SizedBox(width: VibeSpacing.xs),
          Text(
            'Закреплённые',
            style: VibeTypography.caption.copyWith(
              color: context.vibeTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeSpacing.lg,
        vertical: VibeSpacing.xs,
      ),
      child: Container(
        decoration: _islandDecoration(context),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            onTap: () => setState(() => _showArchive = true),
            leading: Container(
              width: VibeSizes.avatarLg,
              height: VibeSizes.avatarLg,
              decoration: BoxDecoration(
                color: context.vibeSurfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.archive_rounded,
                color: context.vibeTextSecondary,
              ),
            ),
            title: Text(
              'Архив',
              style: VibeTypography.subtitle.copyWith(
                color: context.vibeTextPrimary,
              ),
            ),
            subtitle: Text(
              'Чаты с выключенными уведомлениями',
              style: VibeTypography.body.copyWith(
                color: context.vibeTextSecondary,
                fontSize: 13,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.vibeTextTertiary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(VibeRadius.badge),
              ),
              child: Text(
                '${_archived.length}',
                style: VibeTypography.caption.copyWith(
                  color: context.vibeTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Общая подложка «острова»: лёгкий полупрозрачный фон с радиусом
  /// и тонкой рамкой — работает в обеих темах.
  BoxDecoration _islandDecoration(
    BuildContext context, {
    bool selected = false,
  }) {
    return BoxDecoration(
      color: selected
          ? context.vibePrimary.withValues(alpha: 0.12)
          : context.isDarkMode
          ? VibeColors.surfaceElevatedDark.withValues(alpha: 0.45)
          : Colors.white.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(VibeRadius.card),
      border: Border.all(
        color: selected
            ? context.vibePrimary.withValues(alpha: 0.40)
            : context.vibeBorder.withValues(
                alpha: context.isDarkMode ? 0.55 : 0.65,
              ),
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, VibeChat chat) {
    final id = chat.id;
    final name = chat.title;
    final selected = _selected.contains(id);
    final isArchived = _archived.contains(id);
    final isDnd = _dnd.contains(id);
    final pinned = _pinned.contains(id);
    final unread = _unreadOf(chat);
    final density = SettingsService.instance.listDensity;
    // 0 — компактно, 1 — просторно
    final vPad = 2.0 + density * 5.0;

    final tile = Dismissible(
      key: ValueKey('chat_$id'),
      direction: _selectionMode
          ? DismissDirection.none
          : DismissDirection.horizontal,
      confirmDismiss: (_) async {
        if (_selectionMode) return false;
        return true;
      },
      onDismissed: (direction) {
        setState(() {
          if (direction == DismissDirection.endToStart) {
            if (_dnd.contains(id)) {
              _dnd.remove(id);
            } else {
              _dnd.add(id);
            }
          } else {
            if (_archived.contains(id)) {
              _archived.remove(id);
            } else {
              _archived.add(id);
            }
          }
          _selected.remove(id);
        });
        if (direction == DismissDirection.endToStart) {
          VibeBackend.instance.setChatMuted(id, muted: !isDnd);
        } else {
          VibeBackend.instance.setChatArchived(id, archived: !isArchived);
        }
        HapticFeedback.mediumImpact();
        if (direction == DismissDirection.endToStart) {
          _snack(
            isDnd ? '$name — уведомления включены' : '$name — не беспокоить',
          );
        } else if (_archived.contains(id)) {
          _snack('$name — из архива');
        } else {
          _snack('$name — в архив');
        }
      },
      secondaryBackground: _swipeBackground(
        context: context,
        color: VibeColors.warning,
        icon: isDnd
            ? Icons.notifications_active_rounded
            : Icons.notifications_off_rounded,
        label: isDnd ? 'Включить уведомления' : 'Не беспокоить',
      ),
      background: _swipeBackground(
        context: context,
        color: VibeColors.surfaceElevatedDark,
        icon: isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
        label: isArchived ? 'Из архива' : 'Архив',
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: vPad),
        child: ListTile(
          onTap: () {
            if (_selectionMode) {
              _toggleSelect(id);
            } else {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, _, _) => ChatScreen(chat: chat),
                  transitionsBuilder: (_, animation, _, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.05, 0),
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
          },
          onLongPress: () => _showChatMenu(context, chat),
          leading: Hero(
            tag: 'avatar_${chat.id}',
            child: VibeAvatar(
              name: name,
              size: VibeSizes.avatarLg,
              online: chat.peerOnline,
              photoUrl: chat.peerAvatar,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: VibeTypography.subtitle.copyWith(
                    color: isDnd
                        ? context.vibeTextSecondary
                        : context.vibeTextPrimary,
                  ),
                ),
              ),
              if (pinned) ...[
                const SizedBox(width: VibeSpacing.xs),
                const Icon(
                  Icons.push_pin_rounded,
                  size: 16,
                  color: VibeColors.vivid,
                ),
              ],
              if (isDnd) ...[
                const SizedBox(width: VibeSpacing.xs),
                Icon(
                  Icons.notifications_off_rounded,
                  size: 16,
                  color: context.vibeTextTertiary,
                ),
              ],
            ],
          ),
          subtitle: Text(
            isArchived ? 'В архиве' : chat.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VibeTypography.body.copyWith(
              color: context.vibeTextSecondary,
              fontSize: 14,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pinned) ...[
                    const Icon(
                      Icons.push_pin_rounded,
                      size: 12,
                      color: VibeColors.vivid,
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (chat.kind != 'pm') ...[
                    Icon(
                      _typeIcon(chat.kind),
                      size: 15,
                      color: context.vibeTextTertiary,
                    ),
                    const SizedBox(width: 5),
                  ],
                  if (unread > 0 && _dnd.contains(id)) ...[
                    const Icon(Icons.circle, size: 6, color: VibeColors.vivid),
                    const SizedBox(width: 4),
                  ],
                  // Мини-пилюля со временем/датой последнего сообщения (как в TG).
                  // На светлой теме — тёмная рамка и заметный фон, иначе
                  // пилюля сливается с белым рядом. Если сообщений ещё нет —
                  // пустой пузырь не рисуем, вместо него деликатная метка «Новый».
                  if (chat.lastTime.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.isDarkMode
                            ? context.vibeSurfaceElevated
                            : const Color(0xFFEFEDF8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: context.isDarkMode
                              ? context.vibeBorder.withValues(alpha: 0.6)
                              : const Color(0x291C1B22),
                        ),
                      ),
                      child: Text(
                        chat.lastTime,
                        style: VibeTypography.caption.copyWith(
                          fontSize: 10.5,
                          fontWeight: unread > 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: unread > 0
                              ? VibeColors.vivid
                              : context.vibeTextSecondary,
                        ),
                      ),
                    )
                  else if (unread == 0 && !isArchived)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: VibeColors.vivid.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Новый',
                        style: VibeTypography.caption.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: VibeColors.vivid,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (unread > 0)
                VibeUnreadBadge(count: unread, muted: _dnd.contains(id)),
            ],
          ),
        ),
      ),
    );

    // «Остров»: лёгкая полупрозрачная подложка под каждой плиткой —
    // мягкая структура списка без резких карточек. Работает в обеих темах.
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: VibeSpacing.lg,
          vertical: VibeSpacing.xs,
        ),
        child: AnimatedContainer(
          duration: VibeAnimations.pulse,
          curve: VibeAnimations.standard,
          decoration: _islandDecoration(context, selected: selected),
          // Material отделяет ink-эффекты ListTile от DecoratedBox-острова,
          // иначе каждую перерисовку сыплется assertion и срезается ripple.
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                tile,
                if (selected)
                  Positioned(
                    left: 4,
                    top: 0,
                    bottom: 0,
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: context.vibePrimary,
                      size: 22,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _swipeBackground({
    required BuildContext context,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      color: color,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: VibeSpacing.sm),
          Text(
            label,
            style: VibeTypography.bodyMedium.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String kind) {
    switch (kind) {
      case 'group':
        return Icons.people_alt_outlined;
      case 'channel':
        return Icons.campaign_outlined;
      case 'biz':
        return Icons.business_outlined;
      default:
        return Icons.person_outline_rounded;
    }
  }

  void _snack(String msg) {
    HapticFeedback.lightImpact(); // ЛЕГКОЕ ВИБРО ПРИ УВЕДОМЛЕНИИ
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Кружок истории в карусели (как в Telegram):
/// непросмотренная — градиентное кольцо, просмотренная — тонкое серое;
/// превью контента кадрируется под круг (BoxFit.cover).
class _StoryCircle extends StatelessWidget {
  const _StoryCircle({
    required this.item,
    required this.onTap,
    this.placeholder = false,
  });

  final StoryItem item;
  final VoidCallback onTap;

  /// Пустой кружок «+» для «Моей истории» без контента.
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: !item.seen
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: VibeColors.brandGradient,
                    )
                  : null,
              border: item.seen
                  ? Border.all(
                      color: VibeColors.textTertiaryDark.withValues(alpha: 0.6),
                      width: 1.5,
                    )
                  : null,
            ),
            child: ClipOval(
              child: placeholder
                  ? Icon(
                      Icons.add_rounded,
                      color: context.vibePrimary,
                      size: 26,
                    )
                  : _preview(item, context),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              item.author,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: VibeTypography.caption.copyWith(
                color: item.seen
                    ? context.vibeTextTertiary
                    : context.vibeTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(StoryItem item, BuildContext context) {
    if (item.photo != null) {
      return Image.memory(
        item.photo!,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    if (item.photoUrl != null) {
      return SizedBox(
        width: 50,
        height: 50,
        child: VibeNetImage(
          source: item.photoUrl,
          errorBuilder: (_, _, _) =>
              const ColoredBox(color: VibeColors.surfaceDark),
        ),
      );
    }
    return VibeAvatar(name: item.author, size: 50, storyRing: false);
  }
}

class _ComposeFAB extends StatelessWidget {
  const _ComposeFAB({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: VibeColors.brandGradient,
        ),
        boxShadow: const [VibeShadows.floating],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
          tooltip: 'Новое сообщение',
        ),
      ),
    );
  }
}
