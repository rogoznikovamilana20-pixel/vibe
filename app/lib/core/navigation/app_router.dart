import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/backend.dart';
import '../../screens/chat_screen.dart';
import '../../screens/splash_screen.dart';
import '../../screens/root_shell.dart';

/// Центральный роутер Vibe — named routes + deep links (vibe://, https://vibe.me).
/// Постепенно мигрируем с императивного Navigator.push на go_router.
/// Пока — обёртка над существующими экранами, сохраняет TG-компоновку.
final GoRouter vibeRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/main',
      name: 'main',
      builder: (context, state) => RootShell(
        userName: state.extra is Map ? (state.extra as Map)['userName'] as String? ?? '' : '',
        userEmoji: state.extra is Map ? (state.extra as Map)['userEmoji'] as String? : null,
      ),
    ),
    GoRoute(
      path: '/chat/:id',
      name: 'chat',
      builder: (context, state) {
        final chatId = state.pathParameters['id']!;
        final extra = state.extra;
        if (extra is VibeChat) return ChatScreen(chat: extra);
        // Deep link без объекта — грузим по id
        return _ChatLoader(chatId: chatId);
      },
    ),
    // vibe.me/@username — резолв через профиль
    GoRoute(
      path: '/u/:username',
      name: 'profile',
      builder: (context, state) {
        final username = state.pathParameters['username']!;
        return _ProfileLoader(username: username);
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Route not found: ${state.uri}')),
  ),
);

class _ChatLoader extends StatefulWidget {
  const _ChatLoader({required this.chatId});
  final String chatId;
  @override
  State<_ChatLoader> createState() => _ChatLoaderState();
}

class _ChatLoaderState extends State<_ChatLoader> {
  VibeChat? _chat;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await VibeBackend.instance.chatById(widget.chatId);
      if (mounted) setState(() { _chat = c; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_chat == null) return Scaffold(body: Center(child: Text('Чат не найден: ${widget.chatId}')));
    return ChatScreen(chat: _chat!);
  }
}

class _ProfileLoader extends StatefulWidget {
  const _ProfileLoader({required this.username});
  final String username;
  @override
  State<_ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<_ProfileLoader> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('@${widget.username}')),
      body: Center(child: Text('Профиль @${widget.username} — скоро (deep link stub)')),
    );
  }
}
