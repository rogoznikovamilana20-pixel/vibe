import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/services/notification_service.dart';
import '../core/theme/vibe_animations.dart';
import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/vibe_backdrop.dart';
import '../core/widgets/vibe_chat_icon.dart';
import '../core/widgets/vibe_glass_surface.dart';
import '../core/widgets/vibe_push_banner.dart';
import '../core/profile_avatar.dart';
import '../data/backend.dart';
import 'aurion_screen.dart';
import 'chat_list_screen.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'incoming_call_screen.dart';
import 'package:vibe_app/core/services/back_history_service.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';

/// Оболочка приложения: стеклянная нижняя навигация
/// Чаты / Контакты / Настройки / Профиль — как в Telegram.
class RootShell extends StatefulWidget {
  const RootShell({super.key, required this.userName, this.userEmoji});

  final String userName;
  final String? userEmoji;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  StreamSubscription<VibePushEvent>? _pushSub;
  double? _edgeStartX;

  VibePushEvent? _activePush;
  Timer? _pushTimer;

  // Desktop TG: выбранный чат в правой панели (как в TG Desktop) — ValueNotifier чтобы не перерисовывать список.
  final ValueNotifier<VibeChat?> _desktopSelectedChat = ValueNotifier(null);

  late final List<Widget> _screens;

  // Анимация переключения вкладок: короткий fade-content. Индекс живёт в
  // отдельном контроллере, чтобы FadeTransition перезапускался на каждой
  // смене, НЕ пересоздавая сами экраны (они в IndexedStack сохраняют state).
  late final AnimationController _tabFade;
  late final CurvedAnimation _tabCurve;

  @override
  void initState() {
    super.initState();

    _tabFade = AnimationController(
      vsync: this,
      duration: VibeAnimations.fadeIn,
      value: 1,
    );
    _tabCurve = CurvedAnimation(
      parent: _tabFade,
      curve: VibeAnimations.standard,
    );

    // Экраны строятся ОДИН раз: переключение вкладок не должно
    // пересоздавать их и перегружать контент (это давало дерганье).
    _screens = [
      ChatListScreen(
        userName: widget.userName,
        userEmoji: widget.userEmoji,
        onOpenTab: _openTab,
      ),
      const ContactsScreen(),
      SettingsScreen(onOpenProfile: () => _openTab(3)),
      ProfileScreen(
        userName: widget.userName,
        userEmoji: widget.userEmoji,
        onOpenSettings: () => _openTab(2),
      ),
    ];

    // Навигация с тапа по пущу: открыть чат.
    NotificationService.instance.onOpenChatRequested = _openChatById;

    // Входящие звонки: показываем IncomingCallScreen.
    NotificationService.instance.onIncomingCall = _onIncomingCall;

    // Foreground-баннеры.
    _pushSub = NotificationService.instance.events.listen(_onPush);

    // Чат, открытый из-за тапа по системному пущу (приложение было свернуто).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.flushPendingOpen();
    });
  }

  @override
  void dispose() {
    _desktopSelectedChat.dispose();
    _tabFade.dispose();
    _pushSub?.cancel();
    _pushTimer?.cancel();
    NotificationService.instance.onOpenChatRequested = null;
    NotificationService.instance.onIncomingCall = null;
    super.dispose();
  }

  Future<void> _openChatById(String chatId) async {
    final chat = await VibeBackend.instance.chatById(chatId);
    if (chat == null || !mounted) return;
    BackHistoryService.instance.pushChat(chatId: chatId, title: chat.title);
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ChatScreen(chat: chat),
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

  void _onPush(VibePushEvent e) {
    _pushTimer?.cancel();
    setState(() => _activePush = e);
    _pushTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _activePush?.id == e.id) {
        setState(() => _activePush = null);
      }
    });
  }

  void _onPushTap() {
    final push = _activePush;
    if (push == null) return;
    setState(() => _activePush = null);
    final chatId = push.chatId;
    if (push.type == 'chat' && chatId != null && chatId.isNotEmpty) {
      _openChatById(chatId);
    }
  }

  void _onIncomingCall(VibePushEvent event) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callerName: event.title,
          callerId: event.callerId ?? '',
          callId: event.callId ?? event.id,
          callType: event.callType ?? 'voice',
          chatId: event.chatId,
        ),
      ),
    );
  }

  void _openTab(int i) {
    if (i != _index) {
      HapticFeedback.selectionClick();
      setState(() => _index = i);
      const titles = ['Чаты', 'Контакты', 'Настройки', 'Профиль'];
      if (i >= 0 && i < titles.length) {
        BackHistoryService.instance.pushTab(i, titles[i]);
      }
      // Без пересоздания экранов: короткий плавный вспышка-фейд контента.
      _tabFade
        ..duration = VibeAnimations.fadeIn
        ..forward(from: 0.4);
    }
  }

  void _onEdgeDragStart(DragStartDetails d) {
    _edgeStartX = d.globalPosition.dx;
  }

  void _onEdgeDragEnd(DragEndDetails d) {
    final startX = _edgeStartX;
    _edgeStartX = null;
    if (startX == null) return;
    final width = MediaQuery.sizeOf(context).width;
    final fromRightEdge = startX > width - 32;
    final velocity = d.primaryVelocity ?? 0;
    final isLeftSwipe = velocity < -500;
    if (fromRightEdge && isLeftSwipe) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AurionScreen(userName: widget.userName)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ||
        MediaQuery.sizeOf(context).width >= 900;
    if (isDesktop) {
      // TG Desktop референс: левая панель 420 (список чатов) + правая панель чат — без дубль-хедера.
      return Scaffold(
        backgroundColor: context.vibeBackground,
        body: Row(
          children: [
            // Левая панель — список чатов (TG Desktop: 420px)
            SizedBox(
              width: 420,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.vibeSurface,
                  border: Border(right: BorderSide(color: context.vibeDivider, width: 1)),
                ),
                child: ChatListScreen(
                  userName: widget.userName,
                  userEmoji: widget.userEmoji,
                  onOpenTab: _openTab,
                  onChatSelected: (chat) => _desktopSelectedChat.value = chat,
                ),
              ),
            ),
            // Правая панель — чат или плейсхолдер (как в TG Desktop)
            Expanded(
              child: ValueListenableBuilder<VibeChat?>(
                valueListenable: _desktopSelectedChat,
                builder: (context, chat, _) => chat == null
                    ? _DesktopPlaceholder(userName: widget.userName)
                    : ChatScreen(
                        key: ValueKey(chat.id),
                        chat: chat,
                      ),
              ),
            ),
          ],
        ),
        drawer: _VibeDrawer(
          userName: widget.userName,
          userEmoji: widget.userEmoji,
          onSelect: _openTab,
          selectedIndex: _index,
        ),
      );
    }
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          HapticFeedback.lightImpact();
          _openTab(0);
        }
      },
      child: Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      drawer: _VibeDrawer(
        userName: widget.userName,
        userEmoji: widget.userEmoji,
        onSelect: _openTab,
        selectedIndex: _index,
      ),
      body: GestureDetector(
        onHorizontalDragStart: _onEdgeDragStart,
        onHorizontalDragEnd: _onEdgeDragEnd,
        child: Stack(
        children: [
          const Positioned.fill(child: VibeBackdrop()),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                bottom:
                    VibeSizes.bottomNavHeight +
                    VibeSpacing.lg +
                    MediaQuery.of(context).padding.bottom,
              ),
              child: FadeTransition(
                opacity: _tabCurve,
                child: IndexedStack(index: _index, children: _screens),
              ),
            ),
          ),
          // Плавное растворение контента внизу, перед стеклянной капсулой:
          // лёгкое затемнение-блюр добавляет глубины и «живости» списку.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 140,
            child: IgnorePointer(child: _BottomFade()),
          ),
          // In-app баннер пуша (пришло сообщение, приложение открыто).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: VibePushBanner(
                push: _activePush,
                onTap: _onPushTap,
                onDismiss: () => setState(() => _activePush = null),
              ),
            ),
          ),
          // Нижняя стеклянная капсула — чистый оверлей поверх контента:
          // ничего под ней не «обрезается», контент плавно уходит под блюр.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: VibeSpacing.md),
                  child: ValueListenableBuilder<int>(
                    valueListenable: VibeBackend.instance.chatsUnreadTotal,
                    builder: (context, unread, _) => _VibeBottomNav(
                      index: _index,
                      onChanged: _openTab,
                      chatsUnread: unread,
                    ),
                  ),
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

class _VibeBottomNav extends StatelessWidget {
  const _VibeBottomNav({
    required this.index,
    required this.onChanged,
    this.chatsUnread = 0,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final int chatsUnread;

  static const _destinations = [
    (Icons.chat_bubble_outline_rounded, VibeIcons.bubble, 'Чаты'),
    (Icons.people_outline_rounded, VibeIcons.group, 'Контакты'),
    (Icons.settings_outlined, VibeIcons.settings, 'Настройки'),
    (VibeIcons.user, VibeIcons.user, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.lg),
      child: VibeGlassSurface(
        radius: VibeRadius.pill,
        blur: VibeBlur.nav,
        padding: const EdgeInsets.symmetric(
          horizontal: VibeSpacing.sm,
          vertical: VibeSpacing.xs,
        ),
        child: SizedBox(
          height: VibeSizes.bottomNavHeight - VibeSpacing.xs * 2,
          child: Row(
            children: [
              for (var i = 0; i < _destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    active: i == index,
                    badge: i == 0 ? chatsUnread : 0,
                    iconWidget: i == 3
                        ? _NavAvatar(active: i == index)
                        : i == 0
                        ? VibeChatIcon(
                            size: VibeSizes.iconMd,
                            filled: i == index,
                            color: i == index
                                ? context.vibePrimary
                                : VibeColors.inactiveNav,
                          )
                        : Icon(
                            i == index
                                ? _destinations[i].$2
                                : _destinations[i].$1,
                            size: VibeSizes.iconMd,
                            color: i == index
                                ? context.vibePrimary
                                : VibeColors.inactiveNav,
                          ),
                    label: _destinations[i].$3,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.active,
    required this.iconWidget,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  final bool active;
  final Widget iconWidget;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VibeRadius.pill),
      child: Center(
        child: AnimatedContainer(
          duration: VibeAnimations.pulse,
          curve: VibeAnimations.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: VibeSpacing.lg,
            vertical: VibeSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: active
                ? context.vibePrimary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(VibeRadius.pill),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: VibeSizes.iconMd,
                height: VibeSizes.iconMd,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      iconWidget,
                      if (badge > 0)
                        Positioned(
                          top: -6,
                          right: -10,
                          child: _UnreadBadge(count: badge),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: VibeSpacing.xs),
                child: Text(
                  label,
                  style: VibeTypography.label.copyWith(
                    color: active
                        ? context.vibePrimary
                        : VibeColors.textTertiaryDark,
                    fontWeight: FontWeight.w600,
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

/// Компактный счётчик непрочитанных в нижней навигации (как в Telegram).
class _UnreadBadge extends StatefulWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  State<_UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<_UnreadBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_UnreadBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.count > 99 ? '99+' : '${widget.count}';
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: VibeColors.unreadBlue,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Кнопка «Профиль» в навигации — круглый аватар текущего пользователя,
/// как в Telegram. Фото из байтов; если его нет — градиентный кружочек
/// с силуэтом человечка.
class _NavAvatar extends StatelessWidget {
  const _NavAvatar({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final profile = VibeBackend.myProfileNotifier.value;
    return ValueListenableBuilder<Uint8List?>(
      valueListenable: ProfileAvatar.myPhoto,
      builder: (context, photo, _) => AnimatedContainer(
        duration: VibeAnimations.pulse,
        curve: VibeAnimations.standard,
        padding: EdgeInsets.all(active ? 2 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? context.vibePrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: VibeAvatar(
          name: profile?.displayName ?? '',
          size: 26,
          emoji: profile?.emoji,
          photo: photo,
          fallbackIcon: VibeIcons.user,
        ),
      ),
    );
  }
}

/// Боковая шторка как в TG Desktop — профиль сверху + разделы.
class _VibeDrawer extends StatelessWidget {
  const _VibeDrawer({
    required this.userName,
    required this.userEmoji,
    required this.onSelect,
    required this.selectedIndex,
  });

  final String userName;
  final String? userEmoji;
  final ValueChanged<int> onSelect;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final profile = VibeBackend.myProfileNotifier.value;
    final name = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : userName;
    return Drawer(
      width: 320,
      backgroundColor: context.vibeSurface,
      child: Column(
        children: [
          // Header как в TG Desktop: градиент + аватар 64 + имя + телефон/юзернейм
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: VibeColors.brandGradient,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<Uint8List?>(
                  valueListenable: ProfileAvatar.myPhoto,
                  builder: (ctx, photo, _) => VibeAvatar(
                    name: name,
                    size: 64,
                    emoji: userEmoji ?? profile?.emoji,
                    photo: photo,
                  ),
                ),
                const SizedBox(height: 12),
                Text(name,
                    style: VibeTypography.title.copyWith(
                        color: Colors.white, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  profile?.username.isNotEmpty == true
                      ? '@${profile!.username}'
                      : profile?.phone ?? '',
                  style: VibeTypography.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerTile(context, icon: Icons.chat_bubble_outline, label: 'Чаты', selected: selectedIndex == 0, onTap: () { Navigator.pop(context); onSelect(0); }),
                _drawerTile(context, icon: Icons.people_outline, label: 'Контакты', selected: selectedIndex == 1, onTap: () { Navigator.pop(context); onSelect(1); }),
                _drawerTile(context, icon: Icons.call_outlined, label: 'Звонки', selected: false, onTap: () { Navigator.pop(context); VibeToast.show(context, 'Звонки — скоро'); }),
                const Divider(height: 16),
                _drawerTile(context, icon: Icons.settings_outlined, label: 'Настройки', selected: selectedIndex == 2, onTap: () { Navigator.pop(context); onSelect(2); }),
                _drawerTile(context, icon: VibeIcons.user, label: 'Профиль', selected: selectedIndex == 3, onTap: () { Navigator.pop(context); onSelect(3); }),
                _drawerTile(context, icon: Icons.bookmark_border, label: 'Избранное', selected: false, onTap: () async { Navigator.pop(context); onSelect(0); final id = await VibeBackend.instance.ensureSavedChat(); final chat = await VibeBackend.instance.chatById(id); if (chat != null && context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(chat: chat))); }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Vibe  •  TG-parity build',
                style: VibeTypography.caption
                    .copyWith(color: context.vibeTextTertiary, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _drawerTile(BuildContext context,
      {required IconData icon,
      required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon,
          color: selected ? context.vibePrimary : context.vibeTextSecondary),
      title: Text(label,
          style: VibeTypography.body.copyWith(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected
                  ? context.vibePrimary
                  : context.vibeTextPrimary)),
      selected: selected,
      selectedTileColor: context.vibePrimary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
    );
  }
}

/// Плейсхолдер правой панели TG Desktop — «Выберите чат».
class _DesktopPlaceholder extends StatelessWidget {
  const _DesktopPlaceholder({required this.userName});
  final String userName;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.vibeBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: VibeColors.brandGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 24),
            Text('Выберите чат',
                style: VibeTypography.title.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text('Откройте чат из списка слева\nчтобы начать общение',
                textAlign: TextAlign.center,
                style: VibeTypography.body.copyWith(
                    color: context.vibeTextSecondary, height: 20 / 14)),
            const SizedBox(height: 20),
            Text('Vibe • TG Desktop parity',
                style: VibeTypography.caption
                    .copyWith(color: context.vibeTextTertiary)),
          ],
        ),
      ),
    );
  }
}

/// Плавный вертикальный градиент снизу: контент «растворяется» перед баром.
/// Цвет подтягивается из темы — в светлой мягкий свет, в тёмной глубокая тень.
class _BottomFade extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 1.0],
          colors: [
            isDark ? const Color(0x0C0C0B1A) : const Color(0x00FFFFFF),
            isDark
                ? const Color(0x990C0B1A)
                : Colors.white.withValues(alpha: 0.95),
          ],
        ),
      ),
    );
  }
}
