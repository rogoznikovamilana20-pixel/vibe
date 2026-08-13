import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../chats/widgets/chat_list_item.dart';
import '../chats/widgets/compose_fab.dart';
import '../chats/widgets/story_circle.dart';
import '../chat/chat_list_controller.dart';
import '../core/widgets/vibe_collapsed_top_bar.dart';
import '../core/widgets/vibe_glass_surface.dart';
import '../core/widgets/vibe_island.dart';
import '../core/widgets/vibe_offline_banner.dart';
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
import 'lock_screen.dart';
import 'new_message_screen.dart';
import 'search_screen.dart';
import 'settings/privacy/passcode_screen.dart';
import 'story_composer_screen.dart';
import 'story_player.dart';

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

enum _Folder { all, personal, groups, channels, business }

class _ChatListScreenState extends State<ChatListScreen>
    with WidgetsBindingObserver {
  /// Поверхность данных экрана: живой бэкенд или фейк из теста.
  late final VibeBackendApi _backend = widget.backend ?? LiveVibeBackend();

  /// Data-plane списка чатов: лента, статусы, realtime (Single Writer).
  late final ChatListController _chat;

  _Folder _folder = _Folder.all;

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
                dnd ? 'Включить уведомления' : 'Не беспокоить',
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _chat.setMuted(chat.id, muted: !dnd);
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
                _chat.setArchived(chat.id, archivedNow: !archived);
              },
            ),
            ListTile(
              leading: Icon(
                hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: Colors.grey,
              ),
              title: Text(
                hidden ? 'Показать чат' : 'Скрыть чат',
                style: TextStyle(color: sheetText, fontSize: 16),
              ),
              subtitle: hidden
                  ? null
                  : const Text(
                      'Прячет чат из списка; доступ по пасскоду',
                      style: TextStyle(fontSize: 12),
                    ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _chat.setHidden(chat.id, hiddenNow: !hidden);
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
                  _chat.markChatRead(chat.id);
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
                _chat.toggleSelect(chat.id);
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance.appearanceVersion,
      builder: (context, _) => ListenableBuilder(
        listenable: _chat,
        builder: (context, _) {
          // Заблокированные пользователи: их личные чаты скрыты из списка.
          final blocked = SettingsService.instance.blockedUsers;
          final inFolder = _folder == _Folder.all
              ? _chat.chats.where((c) => !blocked.contains(c.peerId)).toList()
              : _chat.chats
                  .where((c) =>
                      !blocked.contains(c.peerId) && _folderOf(c) == _folder)
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
                  _folder == _Folder.all)
              ? 1
              : 0;
          final savedExtra =
              (!_showArchive && !_showHidden) ? 1 : 0;

          return Scaffold(
            backgroundColor: Colors.transparent,
            drawer: _buildDrawer(context),
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
                                return _buildChatTile(context, visible[index]);
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
                                  VibeSizes.bottomNavHeight + VibeSpacing.xxl * 2,
                            ),
                          ),
                          // 8.4.7: пустое состояние с призывом (CTA) —
                          // нет ни одного чата в текущем представлении.
                          if (visible.isEmpty)
                            SliverToBoxAdapter(
                              child: _buildEmptyFeed(context),
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
                  child: ComposeFAB(onTap: () => _openCompose(context)),
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
              tooltip: 'Снять выделение',
            ),
            IconButton(
              onPressed: _chat.markRead,
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Прочитано',
            ),
            IconButton(
              onPressed: _chat.markArchived,
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
                _chat.removeSelected();
              },
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Удалить',
            ),
            IconButton(
              onPressed: _chat.clearSelection,
              icon: const Icon(Icons.check_rounded),
              tooltip: 'Готово',
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

  /// 8.3.5: аватар в шапке открывает боковую шторку (как в Telegram).
  Widget _buildMeAvatar(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () => Scaffold.of(context).openDrawer(),
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

  /// 8.3.5: боковая шторка — профиль и быстрая навигация (вкладки условно
  /// пробрасываются в оболочку через [ChatListScreen.onOpenTab]).
  Widget _buildDrawer(BuildContext context) {
    final isDark = context.isDarkMode;
    final bg = isDark ? VibeColors.surface2Dark : VibeColors.surface2Light;
    return Drawer(
      backgroundColor: bg,
      width: 300,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: VibeSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: VibeSpacing.lg,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  widget.onOpenTab?.call(3);
                  Navigator.of(context).pop();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: VibeSpacing.md,
                  ),
                  child: Row(
                    children: [
                      ValueListenableBuilder<Uint8List?>(
                        valueListenable: ProfileAvatar.myPhoto,
                        builder: (context, photo, _) => VibeAvatar(
                          name: widget.userName,
                          emoji: widget.userEmoji,
                          size: 56,
                          photo: photo,
                          online: true,
                        ),
                      ),
                      const SizedBox(width: VibeSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VibeTypography.title,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Профиль',
                              style: VibeTypography.caption.copyWith(
                                color: context.vibeTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            _drawerTile(
              context,
              icon: Icons.people_outline_rounded,
              label: 'Контакты',
              onTap: () {
                widget.onOpenTab?.call(1);
                Navigator.of(context).pop();
              },
            ),
            _drawerTile(
              context,
              icon: Icons.bookmark_outline_rounded,
              label: 'Избранное',
              onTap: () {
                Navigator.of(context).pop();
                _openSaved();
              },
            ),
            _drawerTile(
              context,
              icon: Icons.archive_outlined,
              label: 'Архив',
              onTap: () => setState(() {
                _showArchive = true;
                _showHidden = false;
              }),
            ),
            _drawerTile(
              context,
              icon: Icons.lock_outline_rounded,
              label: 'Скрытые',
              onTap: () => setState(() {
                _showHidden = true;
                _showArchive = false;
              }),
            ),
            const Divider(height: 1),
            _drawerTile(
              context,
              icon: Icons.settings_outlined,
              label: 'Настройки',
              onTap: () {
                widget.onOpenTab?.call(2);
                Navigator.of(context).pop();
              },
            ),
            _drawerTile(
              context,
              icon: isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              label: isDark ? 'Дневной режим' : 'Ночной режим',
              onTap: () {
                final next = isDark ? ThemeMode.light : ThemeMode.dark;
                SettingsService.instance.setThemeMode(next);
                VibeApp.themeModeNotifier.value = next;
              },
            ),
            if (PasscodeService.instance.hasPasscode)
              _drawerTile(
                context,
                icon: Icons.lock_rounded,
                label: 'Заблокировать',
                onTap: () => _lockNow(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: context.vibePrimary),
      title: Text(label),
      onTap: onTap,
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

  /// 8.4.7: пустое состояние ленты — призыв начать переписку (CTA).
  Widget _buildEmptyFeed(BuildContext context) {
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
                ? 'Архив пуст'
                : _showHidden
                    ? 'Скрытых чатов нет'
                    : 'Нет чатов',
            style: VibeTypography.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: VibeSpacing.xs),
          Text(
            _showArchive || _showHidden
                ? 'Здесь будут чаты, которые вы спрячете сюда'
                : 'Начните переписку — это самый быстрый способ попробовать Vibe',
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
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Новое сообщение'),
          ),
        ],
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
    if (_chat.archived.isNotEmpty) {
      chips.add(_manageChip(context, 'Архив', _chat.archived.length));
    }
    if (_chat.hidden.isNotEmpty) {
      chips.add(_manageChip(context, 'Скрытые чаты', _chat.hidden.length));
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
    final active =
        (label == 'Архив' && _showArchive) ||
        (label == 'Скрытые чаты' && _showHidden);
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

  /// Открыть папку «Архив» или «Скрытые чаты». Скрытые охраняются
  /// пасскодом: без установленного ПИНа — предложение установить,
  /// иначе полноэкранный ввод кода (LockScreen) перед показом.
  Future<void> _openFolder(String label) async {
    if (label == 'Скрытые чаты') {
      final pass = PasscodeService.instance;
      if (!pass.hasPasscode) {
        final setup = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Защита скрытых чатов'),
            content: const Text(
              'Скрытые чаты охраняются код-паролем. '
              'Установите пасскод в настройках приватности.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Позже'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Установить'),
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
      _showArchive = label == 'Архив';
      _showHidden = label == 'Скрытые чаты';
    });
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

  Widget _buildSavedTile(BuildContext context) {
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
          'Сохранённые',
          style: VibeTypography.subtitle.copyWith(
            color: context.vibeTextPrimary,
          ),
        ),
        subtitle: Text(
          'Избранные сообщения',
          style: VibeTypography.body.copyWith(
            color: context.vibeTextSecondary,
            fontSize: 14,
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
          // Возврат из чата: подхватить черновик/статусы (как в Telegram).
          if (mounted) setState(() {});
        }
      },
      onLongPress: () => _showChatMenu(context, chat),
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
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}
