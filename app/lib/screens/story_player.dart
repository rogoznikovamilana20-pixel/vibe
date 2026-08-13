import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/theme/vibe_spacing.dart';
import '../core/widgets/vibe_avatar.dart';
import '../data/backend.dart';
import '../data/settings_service.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Продолжительность показа фото-истории (как в Telegram).
const kStoryPhotoDuration = Duration(seconds: 15);

/// История для плеера: фото (локально/по сети) или видео (до 3 минут).
class StoryItem {
  StoryItem({
    required this.id,
    required this.author,
    this.photo,
    this.photoUrl,
    this.videoUrl,
    this.isOwn = false,
    this.seen = false,
  });

  final String id;
  final String author;
  final Uint8List? photo;
  final String? photoUrl;
  final String? videoUrl;
  final bool isOwn;
  bool seen;

  bool get isVideo => videoUrl != null;
}

/// Полноэкранный плеер историй как в Telegram:
/// сегменты-прогресс сверху, автопереход (фото — 15с, видео — по
/// длительности), свайп/тап по сторонам, пауза видео, и финальный
/// блюр «Вы просмотрели все истории».
class StoryPlayerScreen extends StatefulWidget {
  const StoryPlayerScreen({
    super.key,
    required this.items,
    required this.startIndex,
    required this.onSeen,
  });

  final List<StoryItem> items;
  final int startIndex;

  /// Вызывается, когда история помечена просмотренной.
  final void Function(StoryItem item) onSeen;

  @override
  State<StoryPlayerScreen> createState() => _StoryPlayerScreenState();
}

class _StoryPlayerScreenState extends State<StoryPlayerScreen> {
  late int _index;
  double _progress = 0.0; // 0..1 для фото; позиция/время для видео
  Timer? _timer;
  VideoPlayerController? _video;
  bool _paused = false;
  bool _finished = false;
  bool _showHint = false;
  Timer? _hintTimer;

  StoryItem get _current => widget.items[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex;
    // Обучающая подсказка — только при самом первом открытии историй.
    if (!SettingsService.instance.storiesHintShown) {
      _showHint = true;
      SettingsService.instance.setStoriesHintShown();
      _hintTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showHint = false);
      });
    }
    _startCurrent();
  }

  void _startCurrent() {
    final item = _current;
    _progress = 0;
    if (item.isVideo) {
      _initVideo(item.videoUrl!);
    } else {
      _startPhotoTimer();
    }
  }

  Future<void> _initVideo(String urlOrPath) async {
    _video?.dispose();
    final url = await VibeBackend.instance.mediaUrl(urlOrPath);
    if (url == null) return _next();
    final video = url.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(url))
        : VideoPlayerController.file(File(url));
    _video = video;
    try {
      await video.initialize();
      if (!mounted) return;
      await video.setLooping(false);
      await video.play();
      setState(() {});
      video.addListener(_onVideoTick);
    } catch (_) {
      if (mounted) _next();
    }
  }

  void _onVideoTick() {
    final video = _video;
    if (video == null) return;
    final dur = video.value.duration;
    if (dur.inMilliseconds <= 0) return;
    setState(() => _progress = video.value.position.inMilliseconds /
        dur.inMilliseconds);
    if (video.value.isCompleted) {
      _next();
    }
  }

  void _startPhotoTimer() {
    _timer?.cancel();
    final start = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return;
      final elapsed =
          DateTime.now().difference(start).inMilliseconds / 1000.0;
      setState(() {
        _progress =
            (elapsed / kStoryPhotoDuration.inSeconds).clamp(0.0, 1.0);
      });
      if (_progress >= 1) {
        t.cancel();
        _next();
      }
    });
  }

  void _markSeen() {
    final item = _current;
    if (!item.seen) {
      item.seen = true;
      widget.onSeen(item);
    }
  }

  void _next() {
    _markSeen();
    _timer?.cancel();
    _video?.removeListener(_onVideoTick);
    if (_index >= widget.items.length - 1) {
      // Все истории просмотрены — финальный блюр.
      if (mounted) setState(() => _finished = true);
      _video?.pause();
      return;
    }
    setState(() => _index++);
    _startCurrent();
  }

  void _prev() {
    if (_index == 0) return;
    _timer?.cancel();
    _video?.removeListener(_onVideoTick);
    setState(() => _index--);
    _startCurrent();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hintTimer?.cancel();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    final items = widget.items;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.localPosition.dx < w / 2) {
            _prev();
          } else {
            _next();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildContent(item),
            // Сегменты-прогресс.
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    VibeSpacing.sm,
                    VibeSpacing.sm,
                    VibeSpacing.sm,
                    0,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        Expanded(
                          child: _StorySegment(
                            filled: i < _index
                                ? 1.0
                                : (i == _index ? _progress : 0.0),
                            active: i == _index,
                          ),
                        ),
                        if (i < items.length - 1) const SizedBox(width: 4),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Имя автора + управление.
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    VibeSpacing.md,
                    VibeSpacing.lg + VibeSpacing.sm,
                    VibeSpacing.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      VibeAvatar(
                        name: item.author,
                        size: 36,
                        photo: item.photo,
                        photoUrl: item.photoUrl,
                        storyRing: true,
                      ),
                      const SizedBox(width: VibeSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_showHint) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Свайпайте или тапайте по краям',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (item.isVideo) ...[
                        IconButton(
                          onPressed: () {
                            final v = _video;
                            if (v == null) return;
                            setState(() => _paused = !_paused);
                            _paused ? v.pause() : v.play();
                          },
                          icon: Icon(
                            _paused
                                ? VibeIcons.play
                                : VibeIcons.pause,
                            color: Colors.white,
                          ),
                        ),
                      ],
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(VibeIcons.close),
                        color: Colors.white,
                        tooltip: 'Закрыть',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_finished) _buildFinishedOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(StoryItem item) {
    if (item.isVideo && _video != null && _video!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _video!.value.size.width,
          height: _video!.value.size.height,
          child: VideoPlayer(_video!),
        ),
      );
    }
    if (item.photo != null) {
      return Image.memory(item.photo!, fit: BoxFit.cover);
    }
    if (item.photoUrl != null) {
      return VibeNetImage(
        source: item.photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _StoryGradientPlaceholder(author: item.author),
      );
    }
    return _StoryGradientPlaceholder(author: item.author);
  }

  /// Финальный блюр: «Вы просмотрели все истории».
  Widget _buildFinishedOverlay(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                VibeIcons.checkAll,
                size: 48,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(height: VibeSpacing.lg),
              const Text(
                'Вы просмотрели все истории',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: VibeSpacing.sm),
              Text(
                'Новых пока нет — приходите позже',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: VibeSpacing.xl),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: VibeSpacing.xl,
                    vertical: VibeSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Text(
                    'Закрыть',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

class _StorySegment extends StatelessWidget {
  const _StorySegment({required this.filled, required this.active});

  final double filled; // 0..1
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.white.withValues(alpha: 0.3)),
            Align(
              alignment: Alignment.centerLeft,
              child: LayoutBuilder(
                builder: (context, c) => Container(
                  width: c.maxWidth * filled.clamp(0.0, 1.0),
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Градиентная заставка для истории без фото.
class _StoryGradientPlaceholder extends StatelessWidget {
  const _StoryGradientPlaceholder({required this.author});

  final String author;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1B4D), Color(0xFF0D0A1E)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VibeAvatar(name: author, size: 120),
            const SizedBox(height: VibeSpacing.lg),
            Text(
              author,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'История без фото',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: VibeSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: VibeSpacing.md,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Автопереход через 15 секунд',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}