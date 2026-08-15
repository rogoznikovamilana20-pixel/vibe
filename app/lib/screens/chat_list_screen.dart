
import 'package:vibe_app/core/widgets/vibe_toast.dart';import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/localization/vibe_localizations.dart';
import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../chats/widgets/chat_list_item.dart';
import '../chats/widgets/staggered_chat_list_item.dart';
import '../chats/widgets/compose_fab.dart';
import '../chats/widgets/story_circle.dart';
import '../chat/chat_list_controller.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_glass_surface.dart';
import '../core/widgets/vibe_island.dart';
import '../core/widgets/vibe_offline_banner.dart';
import '../core/widgets/vibe_skeleton.dart';
import '../core/widgets/vibe_top_bar.dart';
import '../core/widgets/vibe_top_frost.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/profile_avatar.dart';
import '../data/backend.dart';
import '../data/backend_api.dart';
import '../data/mock/mock_data.dart';
import '../data/passcode_service.dart';
import '../data/settings_service.dart';
import '../../main.dart';
import 'aurion_screen.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'folders_screen.dart';
import 'lock_screen.dart';
import 'new_message_screen.dart';
import 'search_screen.dart';
import 'settings/privacy/passcode_screen.dart';
import 'story_composer_screen.dart';
import 'story_player.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Список чатов: сториз, папки, свайпы, мультивыбор, боковое меню.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    super.key,
    required this.userName,
    this.userEmoji,
    this.onOpenTab,
    this.backend,
  });

  final String userName;
  final String? userEmoji;

  /// Тестовая подмена данных (widget-тесты); null — живой бэкенд.
  final VibeBackendApi? backend;

  /// Переход на вкладку нижнего бара (Aurion / Профиль) из боковой шторки.
  final ValueChanged<int>? onOpenTab;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with WidgetsBindingObserver {
  /// Поверхность данных экрана: живой бэкенд или фейк из теста.
  late final VibeBackendApi _backend = widget.backend ?? LiveVibeBackend();

  /// Data-plane списка чатов: лента, статусы, realtime (Single Writer).
  late final ChatListController _chat;

  /// Активная вкладка: 'all' | 'personal' | 'groups' | 'channels' |
  /// 'business' | id пользовательской папки (8.3.7).
  String _selectedTab = 'all';

  // Лента сториз (живёт на экране — не входит в data-plane чатов).
  final _stories = <Uint8List>[];
  final _remoteStories = <VibeStory>[];

  // Локальные просмотренные истории (не шлём на сервер).
  final _storySeen = <String>{};

  // Режим просмотра: архив / скрытые / основной список.
  bool _showArchive = false;
  bool _showHidden = false;
  // Скрытые чаты показываются только после ввода пасскода в сессии экрана.
  bool _hiddenUnlocked = false;
  // Защита от повторного входа в «Избранное» (двойной тап = двойной push).
  bool _openingSaved = false;

  // Notifier вместо setState: лёгкие слушатели для скролла
  // (градиент/фрост/коллапс-бар), без перестройки чатов.
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);
  final ValueNotifier<bool> _fabVisible = ValueNotifier(true);
  double _lastScrollPixels = 0;

  List<VibeChat> _visible = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chat = ChatListController(
      onSnack: _snack,
      onReloadStories: _loadStories,
      backend: _backend,
    );
    _chat.load();
    _loadStories();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Сворачивание приложения: скрытые чаты снова под замком.
    if (state == AppLifecycleState.paused) {
      _hiddenUnlocked = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chat.dispose();
    super.dispose();
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
      // Скрытие FAB при скролле вниз, показ при скролле вверх (как в Telegram).
      final delta = value - _lastScrollPixels;
      if (delta > 2) {
        _fabVisible.value = false;
      } else if (delta < -2 || value < 10) {
        _fabVisible.value = true;
      }
      _lastScrollPixels = value;
    }
    return false;
  }

  /// Спрятать выделенные чаты (в HMS-список).
  void _markHidden() {
    HapticFeedback.lightImpact();
    _chat.markHidden();
    setState(() {
      _showHidden = true;
      _showArchive = false;
    });
  }

  /// Меню чата по долгому нажатию: закрепить, архив, уведомления, выбрать.
  Future<void> _showChatMenu(BuildContext context, VibeChat chat) {
    final pinned = _chat.pinned.contains(chat.id);
    final archived = _chat.archived.contains(chat.id);
    final dnd = _chat.dnd.contains(chat.id);
    final hidden = _chat.hidden.contains(chat.id);
    final sheetTheme = Theme.of(context);
    final sheetBg = sheetTheme.brightness == Brightness.dark
        ? VibeColors.surface2Dark
        : VibeColors.surface2Light;
    final l = VibeLocalizations.of(context);
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
                pinned ? VibeIcons.pin : VibeIcons.pin,
                color: pinned ? Colors.amber : Colors.grey,
              ),
              title: Text(
                pinned ? l.chatUnpinChat : l.chatPinChat,
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _chat.togglePin(chat.id);
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
                dnd ? l.chatEnableNotifications : l.chatDoNotDisturb,
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _chat.setMuted(chat.id, muted: !dnd);
              },
            ),
            ListTile(
              leading: Icon(
                archived ? Icons.unarchive_rounded : VibeIcons.archive,
                color: Colors.grey,
              ),
              title: Text(
                archived ? l.chatUnarchive : l.chatArchiveTo,
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _chat.setArchived(chat.id, archivedNow: !archived);
              },
            ),
            ListTile(
              leading: Icon(
                hidden ? VibeIcons.eye : Icons.visibility_off_rounded,
                color: Colors.grey,
              ),
              title: Text(
                hidden ? l.chatShowChat : l.chatHideChat,
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              subtitle: hidden
                  ? null
                  : Text(
                      l.chatHideSubtitle,
                      style: const TextStyle(fontSize: 12),
                    ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _chat.setHidden(chat.id, hiddenNow: !hidden);
              },
            ),
            ListTile(
              leading: const Icon(VibeIcons.check, color: Colors.grey),
              title: Text(
                l.chatMarkRead,
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                if (chat.unread > 0) {
                  _chat.markChatRead(chat.id);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.mark_chat_unread_rounded, color: Colors.grey),
              title: Text(
                l.chatMarkUnread,
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _chat.toggleUnread(chat.id);
              },
            ),
            ListTile(
              leading: Icon(
                VibeIcons.folder,
                color: Colors.grey,
              ),
              title: Text(
                _folderLabel(chat) ?? l.chatMoveToFolder,
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              subtitle: Text(
                l.chatFolderHint,
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickFolder(chat);
              },
            ),
            Divider(color: Color(0x1FFFFFFF).withValues(alpha: 0.4)),
            ListTile(
              leading: const Icon(Icons.checklist_rounded, color: Colors.grey),
              title: Text(
                l.chatSelectChats,
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _chat.toggleSelect(chat.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<(String, String)> _folderEntries(BuildContext context) {
    final l = VibeLocalizations.of(context);
    return [
      ('all', l.folderAll),
      ('personal', l.folderPersonal),
      ('groups', l.folderGroups),
      ('channels', l.folderChannels),
      ('business', l.folderBusiness),
    ];
  }

  /// Умная вкладка чата по типу (для пользовательских папок — назначение).
  String _tabOf(VibeChat chat) {
    switch (chat.kind) {
      case 'group':
        return 'groups';
      case 'channel':
        return 'channels';
      case 'biz':
        return 'business';
      default:
        return 'personal';
    }
  }

  /// Попадает ли чат в активную вкладку (8.3.7: пользовательские папки
  /// учитывают ручное назначение папки).
  bool _inSelectedTab(VibeChat chat) {
    if (_selectedTab == 'all') return true;
    final settings = SettingsService.instance;
    if (settings.folderOf(chat.id) == _selectedTab) return true;
    return _tabOf(chat) == _selectedTab;
  }

  /// Название папки чата (для меню «В папку») или null.
  String? _folderLabel(VibeChat chat) {
    final settings = SettingsService.instance;
    final id = settings.folderOf(chat.id);
    if (id == null) return null;
    for (final f in settings.chatFolders) {
      if (f.id == id) return 'Папка: ${f.emoji} ${f.title}';
    }
    return VibeLocalizations.of(context).chatMoveToFolder;
  }

  /// Подшит выбора папки для чата (8.3.7).
  Future<void> _pickFolder(VibeChat chat) async {
    final settings = SettingsService.instance;
    final current = settings.folderOf(chat.id);
    final sheetTheme = Theme.of(context);
    final sheetBg = sheetTheme.brightness == Brightness.dark
        ? VibeColors.surface2Dark
        : VibeColors.surface2Light;
    final sheetText = Color(
      sheetTheme.brightness == Brightness.dark ? 0xFFF5F3FA : 0xFF1C1B22,
    );
    final l = VibeLocalizations.of(context);
    final folders = settings.chatFolders;
    await showModalBottomSheet<void>(
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
                current == null
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: Colors.grey,
              ),
              title: Text(
                l.folderNoFolder,
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                if (current != null) {
                  await settings.setFolderForChat(chat.id, null);
                }
              },
            ),
            for (final f in folders)
              ListTile(
                leading: Icon(
                  current == f.id
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: current == f.id ? context.vibePrimary : Colors.grey,
                ),
                title: Text(
                  '${f.emoji} ${f.title}',
                  style: TextStyle(color: sheetText, fontSize: 16),
                ),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  if (current != f.id) {
                    await settings.setFolderForChat(chat.id, f.id);
                  }
                },
              ),
            if (folders.isEmpty)
              Padding(
                padding: const EdgeInsets.all(VibeSpacing.lg),
                child: Text(
                  l.folderEmptyHint,
                  style: VibeTypography.caption.copyWith(
                    color: context.vibeTextTertiary,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.manage_search_rounded,
                  color: Colors.grey),
              title: Text(
                l.folderManage,
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _openFoldersScreen(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance.appearanceVersion,
      builder: (context, _) => ListenableBuilder(
        listenable: _chat,
        builder: (context, _) {
          // Заблокированные пользователи: их личные чаты скрыты из списка.
          final blocked = SettingsService.instance.blockedUsers;
          final inFolder = _chat.chats
              .where((c) =>
                  !blocked.contains(c.peerId) && _inSelectedTab(c))
              .toList();

          // Режим просмотра: архив / скрытые / основной список.
          final List<VibeChat> visible;
          if (_showArchive) {
            visible =
                inFolder.where((c) => _chat.archived.contains(c.id)).toList();
          } else if (_showHidden) {
            visible = inFolder.where((c) => _chat.hidden.contains(c.id)).toList();
          } else {
            visible = inFolder
                .where((c) =>
                    !_chat.archived.contains(c.id) && !_chat.hidden.contains(c.id))
                .toList();
          }
          _visible = visible;

          // Закреплённые — всегда первыми (в основном списке).
          final showPinSection =
              !_showArchive &&
              !_showHidden &&
              _chat.pinned.isNotEmpty &&
              visible.any((c) => _chat.pinned.contains(c.id));
          if (showPinSection) {
            visible.sort((a, b) {
              final pa = _chat.pinned.contains(a.id) ? 0 : 1;
              final pb = _chat.pinned.contains(b.id) ? 0 : 1;
              return pa.compareTo(pb);
            });
          }
          final pinExtra = showPinSection ? 1 : 0;
          final archiveExtra =
              (_chat.archived.isNotEmpty &&
                  !_showArchive &&
                  !_showHidden &&
                  _selectedTab == 'all')
              ? 1
              : 0;
          final savedExtra =
              (!_showArchive && !_showHidden) ? 1 : 0;

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: SafeArea(
                      bottom: false,
                      child: RefreshIndicator(
                        color: context.vibePrimary,
                        backgroundColor: Colors.transparent,
                        displacement: 60,
                        onRefresh: () async {
                          HapticFeedback.mediumImpact();
                          await _chat.loadChats();
                        },
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
                          // Компактный отступ сверху
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),
                          SliverToBoxAdapter(child: _buildStories(context)),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          SliverToBoxAdapter(child: _buildTab(context)),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: VibeSpacing.sm),
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
                                if (i == 0 && savedExtra == 1) {
                                  return _buildSavedTile(context);
                                }
                                if (i == savedExtra && showPinSection) {
                                  return _buildPinnedHeader(context);
                                }
                                if (i == savedExtra + pinExtra &&
                                    archiveExtra == 1) {
                                  return _buildArchiveTile(context);
                                }
                                final index =
                                    i - savedExtra - pinExtra - archiveExtra;
                                if (index >= visible.length) {
                                  return const SizedBox.shrink();
                                }
                                return LongPressDraggable<VibeChat>(
                                  data: visible[index],
                                  feedback: Material(
                                    elevation: 8,
                                    borderRadius: BorderRadius.circular(VibeRadius.lg),
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width - 32,
                                      child: _buildChatTile(context, visible[index]),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.3,
                                    child: _buildChatTile(context, visible[index]),
                                  ),
                                  onDragStarted: () => HapticFeedback.mediumImpact(),
                                  child: DragTarget<VibeChat>(
                                    onWillAcceptWithDetails: (details) {
                                      return details.data.id != visible[index].id;
                                    },
                                    onAcceptWithDetails: (details) {
                                      HapticFeedback.heavyImpact();
                                      _reorderChat(details.data, visible[index]);
                                    },
                                    builder: (context, candidateData, rejectedData) {
                                      final isTarget = candidateData.isNotEmpty;
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        decoration: isTarget
                                            ? BoxDecoration(
                                                border: Border(
                                                  top: BorderSide(
                                                    color: context.vibePrimary,
                                                    width: 2,
                                                  ),
                                                ),
                                              )
                                            : null,
                                        child: StaggeredChatListItem(
                                          index: index,
                                          child: _buildChatTile(context, visible[index]),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                              childCount: visible.length +
                                  savedExtra +
                                  pinExtra +
                                  archiveExtra,
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(
                              height:
                                  VibeSizes.bottomNavHeight + VibeSpacing.lg,
                            ),
                          ),
                          // 8.4.7: пустое состояние с призывом (CTA) —
                          // нет ни одного чата в текущем представлении.
                          if (visible.isEmpty && !_chat.loading)
                            SliverToBoxAdapter(
                              child: _buildEmptyFeed(context),
                            ),
                          if (visible.isEmpty && _chat.loading)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 100),
                                child: ChatListSkeleton(count: 8),
                              ),
                            ),
                        ],
                      ),
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
                          builder: (context, offset, _) {
                            final l = VibeLocalizations.of(context);
                            return VibeCollapsedTopBar(
                            // Начинает появляться только после 60 пикселей, когда большая шапка уже точно скрыта
                            progress: ((offset - 60) / 180).clamp(0.0, 1.0),
                            title: VibeTopBarTitle(l.chatTitle),
                            actions: [
                              if (PasscodeService.instance.hasPasscode)
                                IconButton(
                                  onPressed: () => _lockNow(context),
                                  icon: const Icon(VibeIcons.lock, size: 22),
                                  color: context.vibeTextPrimary,
                                  tooltip: l.actionLock,
                                ),
                              IconButton(
                                onPressed: () => _openSearch(context),
                                icon: const Icon(VibeIcons.search, size: 22),
                                color: context.vibeTextPrimary,
                                tooltip: l.tooltipSearch,
                              ),
                              IconButton(
                                onPressed: () => _showChatsMenu(context),
                                icon: const Icon(VibeIcons.moreVertical, size: 22),
                                color: context.vibeTextPrimary,
                                tooltip: l.actionChatsMenu,
                              ),
                            ],
                          );
                          },
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: VibeSpacing.lg,
                  bottom: VibeSizes.bottomNavHeight + VibeSpacing.md,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _fabVisible,
                    builder: (context, visible, child) => AnimatedScale(
                      scale: visible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: AnimatedOpacity(
                        opacity: visible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: child,
                      ),
                    ),
                    child: ComposeFAB(onTap: () => _openCompose(context)),
                  ),
                ),
              ],
            ),
          );
        },
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
                    begin: const Offset(0.3, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: VibeAnimations.springy,
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
    final l = VibeLocalizations.of(context);
    if (_chat.selectionMode) {
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
              '${_chat.selected.length}',
              style: VibeTypography.subtitle.copyWith(
                color: context.vibePrimary,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _chat.clearSelection,
              icon: const Icon(Icons.clear_rounded),
              tooltip: l.actionClearSelection,
            ),
            IconButton(
              onPressed: _chat.markRead,
              icon: const Icon(VibeIcons.checkAll),
              tooltip: l.actionRead,
            ),
            IconButton(
              onPressed: _chat.markArchived,
              icon: const Icon(VibeIcons.archive),
              tooltip: l.actionArchive,
            ),
            IconButton(
              onPressed: _markHidden,
              icon: const Icon(VibeIcons.lock),
              tooltip: l.actionHide,
            ),
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                _chat.removeSelected();
              },
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l.actionDelete,
            ),
            IconButton(
              onPressed: _chat.clearSelection,
              icon: const Icon(VibeIcons.check),
              tooltip: l.actionDone,
            ),
          ],
        ),
      );
    }
    return VibeTopBar(
      leading: _buildMeAvatar(context),
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
          VibeTopBarTitle(l.chatTitle),
        ],
      ),
      actions: [
        if (PasscodeService.instance.hasPasscode)
          VibeTopBarIcon(
            icon: VibeIcons.lock,
            tooltip: l.actionLock,
            onTap: () => _lockNow(context),
          ),
        VibeTopBarIcon(
          icon: VibeIcons.search,
          tooltip: l.tooltipSearch,
          onTap: () => _openSearch(context),
        ),
        VibeTopBarIcon(
          icon: VibeIcons.moreVertical,
          tooltip: l.actionChatsMenu,
          onTap: () => _showChatsMenu(context),
        ),
      ],
    );
  }

  /// Аватар в шапке открывает вкладку «Профиль» (как в Telegram).
  Widget _buildMeAvatar(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
          onTap: () => widget.onOpenTab?.call(3),
      child: Padding(
        padding: const EdgeInsets.only(right: VibeSpacing.sm),
        child: ValueListenableBuilder<Uint8List?>(
          valueListenable: ProfileAvatar.myPhoto,
          builder: (context, photo, _) => VibeAvatar(
            name: widget.userName,
            emoji: widget.userEmoji,
            size: 40,
            photo: photo,
          ),
        ),
      ),
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
    final l = VibeLocalizations.of(context);
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
                isDark ? l.themeDayMode : l.themeNightMode,
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
                l.actionCreateGroup,
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
                l.actionSaved,
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
      await _openChat(context, chat);
    } finally {
      _openingSaved = false;
    }
  }

  String _greeting() {
    final l = VibeLocalizations.of(context);
    final h = DateTime.now().hour;
    if (h < 5) return '${l.greetingNight}, ${widget.userName}';
    if (h < 12) return '${l.greetingMorning}, ${widget.userName}';
    if (h < 18) return '${l.greetingDay}, ${widget.userName}';
    return '${l.greetingEvening}, ${widget.userName}';
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
                    begin: const Offset(0.3, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: VibeAnimations.springy,
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

  /// Анимация перехода в чат: fade + slide (как в Telegram).
  Future<void> _openChat(BuildContext context, VibeChat chat) async {
    final index = _chat.chats.indexWhere((c) => c.id == chat.id);
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ChatScreen(
          chat: chat,
          backend: _backend,
          chats: _chat.chats,
          initialIndex: index >= 0 ? index : 0,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.3, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: VibeAnimations.springy,
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
      final stories = await _backend.listStories();
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
    final l = VibeLocalizations.of(context);
    final items = <StoryItem>[];
    for (var i = 0; i < _stories.length; i++) {
      final id = 'own-$i';
      items.add(
        StoryItem(
          id: id,
          author: l.storyMyStory,
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
          author: s.authorName ?? l.storyFriend,
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
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: VibeSpacing.xl),
        itemBuilder: (context, i) {
          final item = items[i];
          final isMyCircle = item.isOwn && i == 0;
          return StoryCircle(
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
      _snack(VibeLocalizations.of(context).storyPublished);
    } catch (e) {
      _snack('${VibeLocalizations.of(context).storyPublishFailed}: $e');
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
    final settings = SettingsService.instance;
    return SizedBox(
      height: 44,
      child: ListenableBuilder(
        listenable: settings.foldersVersion,
        builder: (context, _) {
          final folders = _folderEntries(context);
          final userFolders = settings.chatFolders;
          final itemCount = folders.length + userFolders.length + 1;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
            itemCount: itemCount,
            itemBuilder: (context, i) {
              if (i >= folders.length + userFolders.length) {
                return _buildAddTabChip(context);
              }
              final String id;
              final String label;
              if (i < folders.length) {
                id = folders[i].$1;
                label = folders[i].$2;
              } else {
                final f = userFolders[i - folders.length];
                id = f.id;
                label = '${f.emoji} ${f.title}';
              }
              final active = id == _selectedTab;
              return Padding(
                padding: const EdgeInsets.only(right: 24),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick(); // ТАКТИЛЬНЫЙ ОТКЛИК
                    setState(() => _selectedTab = id);
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
                    child: Text(label),
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
      );
        },
      ),
    );
  }

  /// Чип «+» в конце вкладок — управление папками (8.3.7).
  Widget _buildAddTabChip(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _openFoldersScreen(context);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: context.vibePrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                VibeIcons.plus,
                size: 18,
                color: context.vibePrimary,
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  /// Экран управления папками (8.3.7).
  Future<void> _openFoldersScreen(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoldersScreen(chats: [..._chat.chats]),
      ),
    );
  }

  /// 8.4.7: пустое состояние ленты — призыв начать переписку (CTA).
  Widget _buildEmptyFeed(BuildContext context) {
    final l = VibeLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeSpacing.xxl,
        vertical: VibeSpacing.xxl,
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: context.vibePrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.forum_outlined,
              size: 40,
              color: context.vibePrimary,
            ),
          ),
          const SizedBox(height: VibeSpacing.lg),
          Text(
            _showArchive
                ? l.archiveEmpty
                : _showHidden
                    ? l.hiddenEmpty
                    : l.chatEmpty,
            style: VibeTypography.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: VibeSpacing.xs),
          Text(
            _showArchive || _showHidden
                ? l.hiddenEmptySubtitle
                : l.chatEmptySubtitle,
            style: VibeTypography.caption.copyWith(
              color: context.vibeTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: VibeSpacing.lg),
          FilledButton.icon(
            onPressed: _showArchive || _showHidden
                ? null
                : () => _openCompose(context),
            icon: const Icon(VibeIcons.edit, size: 18),
            label: Text(l.actionNewMessage),
          ),
        ],
      ),
    );
  }

  Widget _buildManageRow(BuildContext context) {
    final l = VibeLocalizations.of(context);
    // В режиме просмотра архива/скрытых — строка «назад».
    if (_showArchive || _showHidden) {
      final label = _showArchive ? l.archiveTitle : l.hiddenTitle;
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
                    _showHidden ? VibeIcons.lock : VibeIcons.archive,
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
                  l.actionBackToChats,
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
    if (_chat.archived.isNotEmpty) {
      chips.add(_manageChip(context, l.archiveTitle, _chat.archived.length));
    }
    if (_chat.hidden.isNotEmpty) {
      chips.add(_manageChip(context, l.hiddenTitle, _chat.hidden.length));
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
      child: Row(
        children: [
          ...chips,
          const Spacer(),
          if (_chat.dnd.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.notifications_off_rounded,
                  size: 16,
                  color: context.vibeTextTertiary,
                ),
                const SizedBox(width: VibeSpacing.xs),
                Text(
                  '${_chat.dnd.length}',
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
    final l = VibeLocalizations.of(context);
    final active =
        (label == l.archiveTitle && _showArchive) ||
        (label == l.hiddenTitle && _showHidden);
    return Padding(
      padding: const EdgeInsets.only(right: VibeSpacing.sm),
      child: GestureDetector(
        onTap: () => _openFolder(label),
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
                label == l.archiveTitle ? VibeIcons.archive : VibeIcons.lock,
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

  /// Открыть папку «Архив» или «Скрытые чаты». Скрытые охраняются
  /// пасскодом: без установленного ПИНа — предложение установить,
  /// иначе полноэкранный ввод кода (LockScreen) перед показом.
  Future<void> _openFolder(String label) async {
    final l = VibeLocalizations.of(context);
    if (label == l.hiddenTitle) {
      final pass = PasscodeService.instance;
      if (!pass.hasPasscode) {
        final setup = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text(l.hiddenProtectionTitle),
            content: Text(l.hiddenProtectionBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(l.actionLater),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: Text(l.actionSet),
              ),
            ],
          ),
        );
        if (setup != true || !mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PasscodeSettingsScreen()),
        );
        return;
      }
      if (!_hiddenUnlocked) {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const LockScreen()),
        );
        if (ok != true || !mounted) return;
        _hiddenUnlocked = true;
      }
    }
    setState(() {
      _showArchive = label == l.archiveTitle;
      _showHidden = label == l.hiddenTitle;
    });
  }

  Widget _buildAurionCard(BuildContext context) {
    final l = VibeLocalizations.of(context);
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
                        l.aurionCardSubtitle,
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

  Widget _buildSavedTile(BuildContext context) {
    final l = VibeLocalizations.of(context);
    return VibeIsland(
      child: ListTile(
        onTap: _openSaved,
        leading: Container(
          width: VibeSizes.avatarLg,
          height: VibeSizes.avatarLg,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: VibeColors.brandGradient),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bookmark_rounded, color: Colors.white),
        ),
        title: Text(
          l.actionSaved,
          style: VibeTypography.subtitle.copyWith(
            color: context.vibeTextPrimary,
          ),
        ),
        subtitle: Text(
          l.profileSavedMessages,
          style: VibeTypography.body.copyWith(
            color: context.vibeTextSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedHeader(BuildContext context) {
    final l = VibeLocalizations.of(context);
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
            VibeIcons.pin,
            size: 16,
            color: context.vibeTextSecondary,
          ),
          const SizedBox(width: VibeSpacing.xs),
          Text(
            l.chatPinned,
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
    final l = VibeLocalizations.of(context);
    return VibeIsland(
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
            VibeIcons.archive,
            color: context.vibeTextSecondary,
          ),
        ),
        title: Text(
          l.archiveTitle,
          style: VibeTypography.subtitle.copyWith(
            color: context.vibeTextPrimary,
          ),
        ),
        subtitle: Text(
          l.archiveSubtitle,
          style: VibeTypography.body.copyWith(
            color: context.vibeTextSecondary,
            fontSize: 14,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: context.vibeSurfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${_chat.archived.length}',
            style: VibeTypography.caption.copyWith(
              color: context.vibeTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, VibeChat chat) {
    final id = chat.id;
    final name = chat.title;
    final isDnd = _chat.dnd.contains(id);

    return ChatListItem(
      chat: chat,
      selected: _chat.selected.contains(id),
      isArchived: _chat.archived.contains(id),
      isDnd: isDnd,
      pinned: _chat.pinned.contains(id),
      unread: _chat.unreadOf(chat),
      selectionMode: _chat.selectionMode,
      density: SettingsService.instance.listDensity,
      draft: SettingsService.instance.draftFor(id),
      onTap: () async {
        if (_chat.selectionMode) {
          _chat.toggleSelect(id);
        } else {
          await Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (_, _, _) =>
                  ChatScreen(chat: chat, backend: _backend),
              transitionsBuilder: (_, animation, _, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0.3, 0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: VibeAnimations.springy,
                          ),
                        ),
                    child: child,
                  ),
                );
              },
              transitionDuration: VibeAnimations.fadeIn,
            ),
          );
          // Возврат из чата: подхватить черновик/статусы (как в Telegram).
          if (mounted) setState(() {});
        }
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showChatMenu(context, chat);
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _chat.toggleDnd(id);
        } else {
          _chat.toggleArchived(id);
        }
        HapticFeedback.mediumImpact();
        if (direction == DismissDirection.endToStart) {
          _snack(
            isDnd ? '$name — уведомления включены' : '$name — не беспокоить',
          );
        } else if (_chat.archived.contains(id)) {
          _snack('$name — из архива');
        } else {
          _snack('$name — в архив');
        }
      },
    );
  }

  void _snack(String msg) {
    HapticFeedback.lightImpact(); // ЛЕГКОЕ ВИБРО ПРИ УВЕДОМЛЕНИИ
    VibeToast.show(context, msg);
  }

  void _reorderChat(VibeChat dragged, VibeChat target) {
    final fromIdx = _chat.chats.indexWhere((c) => c.id == dragged.id);
    final toIdx = _chat.chats.indexWhere((c) => c.id == target.id);
    if (fromIdx < 0 || toIdx < 0 || fromIdx == toIdx) return;
    setState(() {
      final item = _chat.chats.removeAt(fromIdx);
      _chat.chats.insert(toIdx, item);
    });
    _snack(VibeLocalizations.of(context).chatReordered);
  }
}
