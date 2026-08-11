import 'dart:async';

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
import 'chat_list_screen.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

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

  VibePushEvent? _activePush;
  Timer? _pushTimer;

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

    // Foreground-баннеры.
    _pushSub = NotificationService.instance.events.listen(_onPush);

    // Чат, открытый из-за тапа по системному пущу (приложение было свернуто).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.flushPendingOpen();
    });
  }

  @override
  void dispose() {
    _tabFade.dispose();
    _pushSub?.cancel();
    _pushTimer?.cancel();
    NotificationService.instance.onOpenChatRequested = null;
    super.dispose();
  }

  Future<void> _openChatById(String chatId) async {
    final chat = await VibeBackend.instance.chatById(chatId);
    if (chat == null || !mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)));
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

  void _openTab(int i) {
    if (i != _index) {
      HapticFeedback.selectionClick();
      setState(() => _index = i);
      // Без пересоздания экранов: короткий плавный вспышка-фейд контента.
      _tabFade
        ..duration = VibeAnimations.fadeIn
        ..forward(from: 0.4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
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
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Чаты'),
    (Icons.people_outline_rounded, Icons.people_rounded, 'Контакты'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Настройки'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Профиль'),
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
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
      ),
    );
  }
}

/// Компактный счётчик непрочитанных в нижней навигации (как в Telegram).
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
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
          fallbackIcon: Icons.person_rounded,
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
