import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/vibe_animations.dart';
import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_avatar.dart';
import '../../data/backend.dart';
import '../../data/settings_service.dart';
import '../models.dart';
import 'message_status_tick.dart';

/// Пузырь сообщения: текст/медиа/стикер/голосовое/видеокружок, свайп-ответ,
/// двойной тап — сердечко с искрами, реакции и статусные галочки.
class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.msg,
    required this.onHeart,
    required this.onLongPress,
    required this.onReply,
    required this.onOpenUrl,
    required this.scrollController,
    this.player,
    this.highlight = false,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  final ChatMsg msg;
  final VoidCallback onHeart;
  final VoidCallback onLongPress;
  final VoidCallback onReply;

  /// Открытие URL из текста сообщения (в браузере).
  final ValueChanged<String> onOpenUrl;
  final ScrollController scrollController;
  final AudioPlayer? player;

  /// Подсветка при прыжке к закреплённому сообщению (как в Telegram).
  final bool highlight;

  /// Свёртка цепочек (3.10): первый (самый старый) в группе сообщений
  /// одного автора — верхние углы полные; последний — направленный «хвост».
  final bool isFirstInGroup;
  final bool isLastInGroup;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spark;
  bool _sparkVisible = false;

  // Для динамического градиента
  final GlobalKey _bubbleKey = GlobalKey();
  double _yPos = 0;

  // Для свайпа ответа
  double _dragOffset = 0;
  bool _triggeredReply = false;

  @override
  void initState() {
    super.initState();
    _spark = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    widget.scrollController.addListener(_updateY);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_updateY);
    _spark.dispose();
    super.dispose();
  }

  void _updateY() {
    if (!mounted) return;
    final box = _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final pos = box.localToGlobal(Offset.zero).dy;
      if ((pos - _yPos).abs() > 2) {
        setState(() => _yPos = pos);
      }
    }
  }

  void _onDoubleTap() {
    HapticFeedback.vibrate(); // ИСПРАВЛЕНО: Стандартный мощный отклик
    widget.onHeart();
    setState(() => _sparkVisible = true);
    _spark.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _sparkVisible = false);
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (d.delta.dx < 0) {
      setState(() {
        _dragOffset += d.delta.dx * 0.4; // Сопротивление свайпу
        if (_dragOffset < -60 && !_triggeredReply) {
          _triggeredReply = true;
          HapticFeedback.mediumImpact();
        }
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    if (_triggeredReply) {
      widget.onReply();
    }
    setState(() {
      _dragOffset = 0;
      _triggeredReply = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final isIncoming = msg.incoming;
    final r = SettingsService.instance.bubbleRadius.clamp(4.0, 24.0);

    // Расчет динамического цвета для исходящих
    final screenHeight = MediaQuery.of(context).size.height;
    final progress = (_yPos / screenHeight).clamp(0.0, 1.0);
    
    // Плавный перелив от основного фиолетового к более насыщенному
    final bubbleColor = isIncoming
        ? (context.isDarkMode ? const Color(0xFF19172C) : Colors.white)
        : Color.lerp(
            const Color(0xFF8B4DFF), 
            const Color(0xFF5B21B6), 
            progress
          );

    // Свёртка цепочек: внутри группы отступы компактные, «сросшиеся» углы.
    final inMiddle = !widget.isFirstInGroup && !widget.isLastInGroup;
    final vPad = inMiddle ? 1.0 : 3.0;
    final flat = math.min(r, 4.0);
    final top = widget.isFirstInGroup ? r : flat;
    final bottomLeft = widget.isLastInGroup
        ? (isIncoming ? flat : r)
        : flat;
    final bottomRight = widget.isLastInGroup
        ? (isIncoming ? r : flat)
        : flat;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.translationValues(_dragOffset, 0, 0),
      curve: Curves.easeOutCubic,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Иконка ответа, которая появляется при свайпе
          if (_dragOffset < 0)
            Positioned(
              right: -40,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: (_dragOffset.abs() / 60).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.vibePrimary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.reply_rounded,
                      color: _triggeredReply ? context.vibePrimary : context.vibeTextSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: vPad),
            child: Row(
              mainAxisAlignment: isIncoming ? MainAxisAlignment.start : MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isIncoming) const Spacer(flex: 2),
                GestureDetector(
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  onDoubleTap: _onDoubleTap,
                  onLongPress: () {
                    HapticFeedback.selectionClick();
                    widget.onLongPress();
                  },
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    child: Stack(
                      key: _bubbleKey,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: msg.type == MsgType.photo || msg.stickerEmoji != null
                              ? EdgeInsets.zero
                              : const EdgeInsets.symmetric(
                                  horizontal: VibeSpacing.md,
                                  vertical: VibeSpacing.sm,
                                ),
                          decoration: BoxDecoration(
                            color: widget.highlight
                                ? VibeColors.workBlue.withValues(alpha: 0.35)
                                : bubbleColor,
                            border: (!context.isDarkMode && isIncoming)
                                ? Border.all(
                                    color: const Color(0x1F1C1B22),
                                  )
                                : null,
                            boxShadow: context.isDarkMode
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(top),
                              topRight: Radius.circular(top),
                              bottomLeft: Radius.circular(bottomLeft),
                              bottomRight: Radius.circular(bottomRight),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _bubbleContent(context, msg, isIncoming),
                        ),
                        if (msg.reactions.isNotEmpty)
                          Positioned(
                            right: isIncoming ? 8 : null,
                            left: isIncoming ? null : 8,
                            bottom: -12,
                            child: _ReactionChip(reactions: msg.reactions),
                          ),
                        if (_sparkVisible)
                          Positioned(
                            right: 4,
                            top: -6,
                            child: IgnorePointer(
                              child: _SparkBurst(controller: _spark),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isIncoming) const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubbleContent(
    BuildContext context,
    ChatMsg msg,
    bool isIncoming,
  ) {
    if (msg.stickerEmoji != null) {
      return _StickerBubble(emoji: msg.stickerEmoji!, incoming: isIncoming);
    }
    if (msg.type == MsgType.photo) {
      return _PhotoBubble(msg: msg, incoming: isIncoming);
    }
    if (msg.type == MsgType.voice) {
      final p = widget.player;
      if (p != null) {
        return _VoiceBubble(msg: msg, incoming: isIncoming, player: p);
      }
      return _VoiceBubble(msg: msg, incoming: isIncoming, player: AudioPlayer());
    }
    if (msg.type == MsgType.video) {
      return _VideoRoundBubble(msg: msg, incoming: isIncoming);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (msg.replyText != null) _ReplyQuote(context, msg, isIncoming),
        if (msg.forwardedFrom != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.reply_all_rounded,
                  size: 13,
                  color: isIncoming
                      ? context.vibePrimary
                      : const Color(0xFFB7A7FF),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Переслано от ${msg.forwardedFrom}',
                    overflow: TextOverflow.ellipsis,
                    style: VibeTypography.caption.copyWith(
                      color: isIncoming
                          ? context.vibePrimary
                          : const Color(0xFFB7A7FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Text.rich(
          TextSpan(
            children: buildLinkSpans(
              msg.text,
              isIncoming
                  ? context.vibePrimary
                  : const Color(0xFFC9B4FF),
              widget.onOpenUrl,
            ),
            style: VibeTypography.body.copyWith(
              fontSize: 15 + SettingsService.instance.fontSizeDelta,
              color: isIncoming ? context.vibeTextPrimary : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Spacer(),
            if (msg.edited)
              Text(
                'изменено',
                style: VibeTypography.caption.copyWith(
                  color: isIncoming
                      ? (context.isDarkMode
                          ? context.vibeTextTertiary
                          : const Color(0xFF5A5766))
                      : Colors.white54,
                  fontSize: 9,
                ),
              ),
            if (msg.edited) const SizedBox(width: 4),
            Text(
              msg.time,
              style: VibeTypography.caption.copyWith(
                color: isIncoming
                    ? (context.isDarkMode
                        ? context.vibeTextTertiary
                        : const Color(0xFF5A5766))
                    : Colors.white70,
                fontSize: 10,
              ),
            ),
            if (!isIncoming) ...[
              const SizedBox(width: 4),
              MessageStatusTick(status: msg.status),
            ],
          ],
        ),
      ],
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote(this.context, this.msg, this.isIncoming);

  final BuildContext context;
  final ChatMsg msg;
  final bool isIncoming;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isIncoming ? context.vibePrimary : Colors.white,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg.replyAuthor ?? '',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isIncoming
                  ? context.vibePrimary
                  : Colors.white,
            ),
          ),
          Text(
            msg.replyText ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isIncoming
                  ? context.vibeTextSecondary
                  : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _StickerBubble extends StatelessWidget {
  const _StickerBubble({required this.emoji, required this.incoming});

  final String emoji;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Container(
        width: 128,
        height: 128,
        decoration: BoxDecoration(
          color: context.isDarkMode
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(VibeRadius.card),
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 64, height: 1),
          ),
        ),
      ),
    );
  }
}

class _PhotoBubble extends StatelessWidget {
  const _PhotoBubble({required this.msg, required this.incoming});

  final ChatMsg msg;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    final url = msg.photoUrl;
    if (url != null && url.isNotEmpty) {
      return _NetworkPhotoBubble(url: url, time: msg.time, incoming: incoming);
    }
    const palette = [
      Color(0xFF8B5CF6),
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF6366F1),
    ];
    final c1 = palette[msg.photoSeed % palette.length];
    final c2 = palette[(msg.photoSeed + 2) % palette.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 220,
          height: 150,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c1, c2],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                bottom: -18,
                child: Icon(
                  Icons.water_drop_rounded,
                  size: 90,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              Positioned(
                left: 12,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Фото · демо',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const Center(
                child: Icon(
                  Icons.image_rounded,
                  size: 42,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shield,
              size: 11,
              color: VibeColors.success,
            ),
            const SizedBox(width: 3),
            Text(
              msg.time,
              style: VibeTypography.caption.copyWith(
                color: incoming
                    ? context.vibeTextTertiary
                    : Colors.white70,
                fontSize: 11,
              ),
            ),
            if (!incoming) ...[
              const SizedBox(width: 3),
              const Icon(
                Icons.done_all_rounded,
                size: 13,
                color: Colors.white70,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _NetworkPhotoBubble extends StatelessWidget {
  const _NetworkPhotoBubble({
    required this.url,
    required this.time,
    required this.incoming,
  });

  final String url;
  final String time;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 220,
            height: 150,
            child: VibeNetImage(
              source: url,
              errorBuilder: (_, _, _) => Container(
                color: Colors.black26,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white38,
                  size: 40,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shield,
              size: 11,
              color: VibeColors.success,
            ),
            const SizedBox(width: 3),
            Text(
              time,
              style: VibeTypography.caption.copyWith(
                color: incoming
                    ? context.vibeTextTertiary
                    : Colors.white70,
                fontSize: 11,
              ),
            ),
            if (!incoming) ...[
              const SizedBox(width: 3),
              const Icon(
                Icons.done_all_rounded,
                size: 13,
                color: Colors.white70,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _VoiceBubble extends StatefulWidget {
  const _VoiceBubble({
    required this.msg,
    required this.incoming,
    required this.player,
  });

  final ChatMsg msg;
  final bool incoming;
  final AudioPlayer player;

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _progress;
  StreamSubscription<Duration>? _sub;
  Duration _pos = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: Duration(
        seconds: widget.msg.voiceSeconds == 0
            ? 1
            : widget.msg.voiceSeconds,
      ),
      value: 0,
    );
    _sub = widget.player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _pos = pos);
    });
    widget.player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _pos = Duration.zero;
        _progress.value = 0;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final localPath = widget.msg.voicePath;
    var url = widget.msg.voiceUrl;
    if ((localPath == null || localPath.isEmpty) &&
        (url == null || url.isEmpty)) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Нет аудиофайла')));
      return;
    }
    setState(() => _playing = !_playing);
    if (_playing) {
      if (widget.player.state != PlayerState.playing) {
        await widget.player.stop();
        if (localPath != null && localPath.isNotEmpty) {
          await widget.player.play(DeviceFileSource(localPath));
        } else {
          final signed = await VibeBackend.instance.mediaUrl(url);
          if (signed == null) {
            setState(() => _playing = false);
            return;
          }
          await widget.player.play(UrlSource(signed));
        }
      } else {
        await widget.player.resume();
      }
      _progress
        ..duration = Duration(seconds: widget.msg.voiceSeconds)
        ..forward();
    } else {
      await widget.player.pause();
      _progress.stop();
    }
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    final total = widget.msg.voiceSeconds;
    final rest = ((total - s)).clamp(0, total);
    return '${rest % 60}с';
  }

  @override
  Widget build(BuildContext context) {
    final isIncoming = widget.incoming;
    final isExternal =
        widget.msg.voicePath != null || widget.msg.voiceUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _toggle,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: AnimatedSwitcher(
                duration: VibeAnimations.fadeIn,
                child: Icon(
                  _playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  key: ValueKey(_playing),
                  color: isIncoming ? context.vibePrimary : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _progress,
            builder: (context, _) {
              return SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress.value,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(
                      isIncoming ? context.vibePrimary : Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            _fmt(_pos),
            style: VibeTypography.caption.copyWith(
              color: isIncoming
                  ? context.vibeTextSecondary
                  : Colors.white70,
              fontSize: 11,
            ),
          ),
          if (!isExternal) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.mic_none_rounded,
              size: 14,
              color: Colors.white38,
            ),
          ],
        ],
      ),
      const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shield,
              size: 11,
              color: VibeColors.success,
            ),
            const SizedBox(width: 3),
            Text(
              widget.msg.time,
              style: VibeTypography.caption.copyWith(
                color: isIncoming
                    ? context.vibeTextTertiary
                    : Colors.white70,
                fontSize: 11,
              ),
            ),
            if (!isIncoming) ...[
              const SizedBox(width: 3),
              const Icon(
                Icons.done_all_rounded,
                size: 13,
                color: Colors.white70,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.reactions});

  final List<ChatReaction> reactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: context.vibeSurfaceHigh,
        borderRadius: BorderRadius.circular(VibeRadius.badge),
        border: Border.all(color: context.vibeDivider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in reactions) ...[
            Text(r.emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 2),
            Text(
              '${r.count}',
              style: VibeTypography.label.copyWith(
                color: context.vibePrimary,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _SparkBurst extends StatelessWidget {
  const _SparkBurst({required this.controller});

  final AnimationController controller;

  static const _angles = [0.0, 0.7, 1.4, 2.1, 2.8, 3.5, 4.2, 4.9];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = Curves.easeOut.transform(controller.value);
        final fade = 1 - controller.value;
        return SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final (_, angle) in _angles.indexed)
                Transform.translate(
                  offset: Offset(
                    math.cos(angle) * 26 * t,
                    math.sin(angle) * 26 * t,
                  ),
                  child: Opacity(
                    opacity: fade,
                    child: Text(
                      '✦',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color.lerp(
                          context.vibePrimary,
                          Colors.white,
                          0.45,
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.scale(
                scale: 1 + 0.35 * Curves.easeOutBack.transform(t),
                child: const Text('❤️', style: TextStyle(fontSize: 26)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Видеокружок — круглое видео с автовоспроизведением по кругу (как в ТГ).
class _VideoRoundBubble extends StatefulWidget {
  const _VideoRoundBubble({required this.msg, required this.incoming});

  final ChatMsg msg;
  final bool incoming;

  @override
  State<_VideoRoundBubble> createState() => _VideoRoundBubbleState();
}

class _VideoRoundBubbleState extends State<_VideoRoundBubble> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final local = widget.msg.videoPath;
    final url = await VibeBackend.instance.mediaUrl(widget.msg.videoUrl);
    VideoPlayerController? c;
    if (local != null && local.isNotEmpty) {
      c = VideoPlayerController.file(File(local));
    } else if (url != null) {
      c = VideoPlayerController.networkUrl(Uri.parse(url));
    }
    if (c == null) return;
    try {
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.play();
      setState(() => _controller = c);
    } catch (_) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: ClipOval(
        child: _controller == null
            ? const ColoredBox(
                color: VibeColors.surfaceDark,
                child: Center(
                  child: Icon(
                    Icons.videocam_rounded,
                    color: VibeColors.textTertiaryDark,
                  ),
                ),
              )
            : FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
      ),
    );
  }
}

/// Анимированная волна эквалайзера (запись голосового).
class EqualizerWave extends StatefulWidget {
  const EqualizerWave({super.key, required this.color});

  final Color color;

  @override
  State<EqualizerWave> createState() => _EqualizerWaveState();
}

class _EqualizerWaveState extends State<EqualizerWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(5, (i) {
            final phase = (_controller.value * 3.14 + i * 1.1) % 3.14;
            final h = 6 + 14 * (0.5 + 0.5 * math.sin(phase));
            return Container(
              width: 3,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
