import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_theme.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import 'chat_controller.dart';
import 'models.dart';

/// Одно медиа в галерее (фото или видео-кружок).
class ChatMediaItem {
  const ChatMediaItem({
    required this.kind,
    required this.photoSeed,
    this.photoUrl,
    this.videoUrl,
    this.videoPath,
  });

  final String kind; // 'photo' | 'video'
  final int photoSeed;
  final String? photoUrl;
  final String? videoUrl;
  final String? videoPath;
}

/// Галерея медиа чата (как в Telegram): сетка фото/видео-кружков,
/// тап — полноэкранный просмотр со свайпом между элементами.
class ChatMediaGalleryScreen extends StatefulWidget {
  const ChatMediaGalleryScreen({
    super.key,
    required this.controller,
    required this.chatTitle,
  });

  final ChatController controller;
  final String chatTitle;

  @override
  State<ChatMediaGalleryScreen> createState() =>
      _ChatMediaGalleryScreenState();
}

class _ChatMediaGalleryScreenState extends State<ChatMediaGalleryScreen> {
  List<ChatMediaItem> get _media => [
        for (final m in widget.controller.messages)
          if (m.type == MsgType.photo)
            ChatMediaItem(
              kind: 'photo',
              photoSeed: m.photoSeed,
              photoUrl: m.photoUrl,
            )
          else if (m.type == MsgType.video)
            ChatMediaItem(
              kind: 'video',
              photoSeed: m.photoSeed,
              videoUrl: m.videoUrl,
              videoPath: m.videoPath,
            ),
      ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final media = _media;
        return Scaffold(
          backgroundColor: context.vibeBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(
              'Медиа · ${media.length}',
              style: VibeTypography.subtitle.copyWith(
                color: context.vibeTextPrimary,
              ),
            ),
          ),
          body: media.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 48,
                        color: context.vibeTextTertiary,
                      ),
                      const SizedBox(height: VibeSpacing.md),
                      Text(
                        'Пока нет медиа',
                        style: VibeTypography.body.copyWith(
                          color: context.vibeTextSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(VibeSpacing.xs),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: media.length,
                  itemBuilder: (context, i) => _MediaTile(
                    item: media[i],
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MediaViewerScreen(
                            items: media,
                            initialIndex: i,
                          ),
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}

/// Плитка сетки: фото или видео с play-иконкой.
class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.item, required this.onTap});

  final ChatMediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _photoWidget(context),
          if (item.kind == 'video')
            Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _photoWidget(BuildContext context) {
    final url = item.photoUrl;
    if (item.kind == 'photo' && url != null && url.isNotEmpty) {
      return VibeNetImage(source: url, fit: BoxFit.cover);
    }
    const palette = [
      Color(0xFF8B5CF6),
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF6366F1),
    ];
    final c1 = palette[item.photoSeed % palette.length];
    final c2 = palette[(item.photoSeed + 2) % palette.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
      ),
      child: Icon(
        item.kind == 'video'
            ? Icons.video_call_outlined
            : Icons.water_drop_rounded,
        size: 28,
        color: Colors.white.withValues(alpha: 0.4),
      ),
    );
  }
}

/// Полноэкранный просмотр медиа: свайп между элементами, зум фото,
/// воспроизведение видео-кружков.
class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<ChatMediaItem> items;
  final int initialIndex;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _page = PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: widget.items.length,
            itemBuilder: (context, i) => _ViewerPage(item: widget.items[i]),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(VibeSpacing.md),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
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

class _ViewerPage extends StatefulWidget {
  const _ViewerPage({required this.item});

  final ChatMediaItem item;

  @override
  State<_ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<_ViewerPage> {
  VideoPlayerController? _video;
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.item.kind != 'video') return;
    final url = widget.item.videoUrl;
    try {
      if (url != null && url.isNotEmpty) {
        _video = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        _video = VideoPlayerController.file(File(widget.item.videoPath ?? ''));
      }
      await _video!.initialize();
      if (!mounted) return;
      _video!.setLooping(true);
      _video!.play();
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _videoError = true);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (item.kind == 'video') {
      if (_videoError) {
        return const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white54),
        );
      }
      final v = _video;
      if (v == null || !v.value.isInitialized) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        );
      }
      return GestureDetector(
        onTap: () => v.value.isPlaying ? v.pause() : v.play(),
        child: Center(
          child: AspectRatio(
            aspectRatio: v.value.aspectRatio,
            child: VideoPlayer(v),
          ),
        ),
      );
    }
    return _PhotoViewer(item: item);
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.item});

  final ChatMediaItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.photoUrl;
    return InteractiveViewer(
      maxScale: 5,
      child: Center(
        child: url != null && url.isNotEmpty
            ? VibeNetImage(
                source: url,
                fit: BoxFit.contain,
                placeholder: const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
              )
            : _gradient(item),
      ),
    );
  }

  Widget _gradient(ChatMediaItem item) {
    const palette = [
      Color(0xFF8B5CF6),
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF6366F1),
    ];
    final c1 = palette[item.photoSeed % palette.length];
    final c2 = palette[(item.photoSeed + 2) % palette.length];
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
      ),
    );
  }
}
