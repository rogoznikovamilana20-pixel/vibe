import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/vibe_animations.dart';
import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/services/link_preview.dart';
import '../../core/widgets/vibe_avatar.dart';
import '../../data/backend.dart';
import '../../data/settings_service.dart';
import '../models.dart';
import 'message_status_tick.dart';
import 'package:vibe_app/core/widgets/vibe_toast.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';
import '../../core/localization/vibe_localizations.dart';

/// ?????? ?????????: ?????/?????/??????/?????????/???????????, ?????-?????,
/// ??????? ??? ? ???????? ? ???????, ??????? ? ????????? ???????.
class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.msg,
    required this.onHeart,
    required this.onLongPress,
    required this.onReply,
    this.onReplyTap,
    this.onPhotoTap,
    required this.onOpenUrl,
    required this.scrollController,
    this.player,
    this.highlight = false,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.isGroup = false,
    this.chatId,
    this.pollVotes = const [],
    this.myVote,
    this.onOpenContact,
    this.onVote,
    this.isSelected = false,
    this.selectionMode = false,
    this.onToggleSelect,
  });

  final ChatMsg msg;
  final String? Function() onHeart;
  final VoidCallback onLongPress;
  final VoidCallback onReply;

  /// Тап по цитате ответа → прыжок к исходному сообщению (как в Telegram).
  final VoidCallback? onReplyTap;

  /// Тап по фото → полноэкранный просмотр (как в Telegram). null в
  /// режиме выбора сообщений.
  final VoidCallback? onPhotoTap;

  /// ???????? URL ?? ?????? ????????? (? ????????).
  final ValueChanged<String> onOpenUrl;
  final ScrollController scrollController;
  final AudioPlayer? player;

  /// ????????? ??? ?????? ? ???????????? ????????? (??? ? Telegram).
  final bool highlight;

  /// ?????? ??????? (3.10): ?????? (????? ??????) ? ?????? ?????????
  /// ?????? ?????? ? ??????? ???? ??????; ????????? ? ???????????? ??????.
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool isGroup;

  /// Id ???? ? ??? ??????????? ? ?????? ? ?????????? ?????.
  final String? chatId;

  /// ???????? ??????? ?????? (?????? ???????? > ????? ???????).
  final List<int> pollVotes;

  /// ???????, ?? ??????? ??? ????????? ??????? ????????????.
  final int? myVote;

  /// ?????????? ?? ???????? ?? ????????.
  final ValueChanged<String>? onOpenContact;

  /// ??????????? ? ?????? (????? ????????).
  final ValueChanged<int>? onVote;

  /// Multi-select (V4.1).
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback? onToggleSelect;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spark;
  bool _sparkVisible = false;
  String _burstEmoji = '❤️';

  // ??? ????????????? ?????????
  final GlobalKey _bubbleKey = GlobalKey();
  double _yPos = 0;

  // ??? ?????? ??????
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
    HapticFeedback.vibrate(); // Telegram: вибро при двойном тапе.
    final emoji = widget.onHeart();
    if (emoji != null) {
      setState(() {
        _burstEmoji = emoji;
        _sparkVisible = true;
      });
      _spark.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _sparkVisible = false);
      });
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (d.delta.dx > 0) {
      final threshold = 80.0;
      setState(() {
        _dragOffset += d.delta.dx * 0.6;
        if (_dragOffset > threshold && !_triggeredReply) {
          _triggeredReply = true;
          HapticFeedback.heavyImpact();
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

    // Telegram-??????: ???????? ? ?????? ???? (??? ????? ? ???????? ??
    // ???????), ????????? ? ????? (??? ?????? ?? ???????). ?????? ????????.
    final bubbleColor = isIncoming
        ? (context.isDarkMode
              ? VibeColors.bubbleInDark
              : VibeColors.bubbleInLight)
        : (context.isDarkMode
              ? VibeColors.bubbleOutDark
              : VibeColors.bubbleOutLight);

    // ?????? ???????: ?????? ?????? ??????? ??????????, ??????????? ????.
    final inMiddle = !widget.isFirstInGroup && !widget.isLastInGroup;
    final vPad = inMiddle ? 1.0 : 3.0;
    final flat = math.min(r, 4.0);
    final top = widget.isFirstInGroup ? r : flat;
    final bottomLeft = widget.isLastInGroup ? (isIncoming ? flat : r) : flat;
    final bottomRight = widget.isLastInGroup ? (isIncoming ? r : flat) : flat;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.translationValues(_dragOffset, 0, 0),
      curve: Curves.easeOutCubic,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Reply icon (appears on right swipe)
          if (_dragOffset > 0)
            Positioned(
              left: -48,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: (_dragOffset / 80).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.vibePrimary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      VibeIcons.reply,
                      color: _triggeredReply
                          ? context.vibePrimary
                          : context.vibeTextSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: vPad),
            child: Row(
              mainAxisAlignment: isIncoming
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Telegram-паттерн: в режиме выделения слева от сообщения
                // показывается кружок-чекбокс (выбран — заливка + галочка).
                if (widget.selectionMode) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SelectionCheck(isSelected: widget.isSelected),
                  ),
                ],
                if (!isIncoming) const Spacer(flex: 2),
                Semantics(
                  label: '${msg.text}${msg.incoming ? ', входящее' : ', исходящее'}${msg.edited ? ', изменено' : ''}',
                  button: false,
                  child: GestureDetector(
                    onHorizontalDragUpdate: widget.selectionMode
                        ? null
                        : _onHorizontalDragUpdate,
                    onHorizontalDragEnd: widget.selectionMode
                        ? null
                        : _onHorizontalDragEnd,
                    onDoubleTap: widget.selectionMode ? null : _onDoubleTap,
                    onLongPress: () {
                      HapticFeedback.selectionClick();
                      if (widget.selectionMode) {
                        widget.onToggleSelect?.call();
                      } else {
                        widget.onLongPress();
                      }
                    },
                    onTap: widget.selectionMode ? widget.onToggleSelect : null,
                    child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    child: Stack(
                      key: _bubbleKey,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding:
                              msg.type == MsgType.photo ||
                                  msg.stickerEmoji != null
                              ? EdgeInsets.zero
                              : const EdgeInsets.only(
                                  left: VibeSpacing.md,
                                  right: VibeSpacing.md,
                                  top: 6,
                                  bottom: 5,
                                ),
                          decoration: BoxDecoration(
                            color: widget.isSelected
                                ? context.vibePrimary.withValues(alpha: 0.3)
                                : widget.highlight
                                ? VibeColors.workBlue.withValues(alpha: 0.35)
                                : bubbleColor,
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
                        if (widget.isLastInGroup && SettingsService.instance.bubbleTail)
                          Positioned(
                            right: isIncoming ? null : 0,
                            left: isIncoming ? 0 : null,
                            bottom: -6,
                            child: CustomPaint(
                              size: const Size(11, 7),
                              painter: _TailPainter(
                                color: widget.highlight
                                    ? VibeColors.workBlue.withValues(
                                        alpha: 0.35,
                                      )
                                    : bubbleColor,
                                mirror: !isIncoming,
                              ),
                            ),
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
                            right: isIncoming ? null : -16,
                            left: isIncoming ? -16 : null,
                            top: -30,
                            child: IgnorePointer(
                              child: _ReactionBurst(
                                controller: _spark,
                                emoji: _burstEmoji,
                              ),
                            ),
                          ),
                      ],
                    ),
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

  Widget _bubbleContent(BuildContext context, ChatMsg msg, bool isIncoming) {
    final l = VibeLocalizations.of(context);
    if (msg.stickerEmoji != null) {
      return _StickerBubble(emoji: msg.stickerEmoji!, incoming: isIncoming);
    }
    if (msg.type == MsgType.photo) {
      return _PhotoBubble(
        msg: msg,
        incoming: isIncoming,
        onTap: widget.selectionMode ? null : widget.onPhotoTap,
        isGroup: widget.isGroup,
      );
    }
    if (msg.type == MsgType.voice) {
      final p = widget.player;
      if (p != null) {
        return _VoiceBubble(msg: msg, incoming: isIncoming, player: p, isGroup: widget.isGroup);
      }
      return _VoiceBubble(
        msg: msg,
        incoming: isIncoming,
        player: AudioPlayer(),
        isGroup: widget.isGroup,
      );
    }
    if (msg.type == MsgType.video) {
      return _VideoRoundBubble(msg: msg, incoming: isIncoming);
    }
    // 8.3.3: ???????? ? ????/???????/???????/?????; ????? ? ?????? ?????.
    final attach = msg.attachment;
    if (attach != null) {
      switch (attach.kind) {
        case AttachmentKind.file:
          return _FileBubble(
            attach: attach,
            chatId: widget.chatId,
            incoming: isIncoming,
          );
        case AttachmentKind.gif:
          return _GifBubble(
            attach: attach,
            time: msg.time,
            incoming: isIncoming,
          );
        case AttachmentKind.location:
          return _LocationBubble(attach: attach, incoming: isIncoming);
        case AttachmentKind.contact:
          return _ContactBubble(
            attach: attach,
            incoming: isIncoming,
            onOpenContact: widget.onOpenContact,
          );
        case AttachmentKind.poll:
          return _PollBubble(
            attach: attach,
            pollId: msg.serverId ?? '',
            incoming: isIncoming,
            votes: widget.pollVotes,
            myVote: widget.myVote,
            onVote: widget.onVote,
          );
        case AttachmentKind.pollVote:
          return const SizedBox.shrink();
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (msg.replyText != null)
          _ReplyQuote(context, msg, isIncoming, widget.onReplyTap),
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
                      : VibeColors.outgoingLink,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    l.messageForwardedFrom(msg.forwardedFrom!),
                    overflow: TextOverflow.ellipsis,
                    style: VibeTypography.caption.copyWith(
                      color: isIncoming
                          ? context.vibePrimary
                          : VibeColors.outgoingLink,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SelectableText.rich(
          TextSpan(
            children: buildLinkSpans(
              msg.text,
              isIncoming ? context.vibePrimary : VibeColors.outgoingLink,
              widget.onOpenUrl,
            ),
            style: VibeTypography.body.copyWith(
              fontSize: (SettingsService.instance.messageFontSize + SettingsService.instance.fontSizeDelta).clamp(12.0, 24.0),
              color: isIncoming ? context.vibeTextPrimary : Colors.white,
            ),
          ),
        ),
        // 8.4.4: ?????? ?????? ??? ??????? (OpenGraph-????????).
        if (VibeLinkPreview.instance.firstUrl(msg.text) != null)
          _LinkPreviewCard(
            text: msg.text,
            incoming: isIncoming,
            onOpen: widget.onOpenUrl,
          ),
        const SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Spacer(),
            if (msg.edited)
              Text(
                l.messageEdited,
                style: VibeTypography.caption.copyWith(
                  color: isIncoming
                      ? (context.isDarkMode
                            ? context.vibeTextTertiary
                            : VibeColors.mutedTextLight)
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
                          : VibeColors.mutedTextLight)
                    : Colors.white70,
                fontSize: 11,
              ),
            ),
            if (!isIncoming && SettingsService.instance.showTicks) ...[
              const SizedBox(width: 4),
              if (SettingsService.instance.showTicks)
                MessageStatusTick(status: widget.isGroup && (msg.status == MsgStatus.delivered || msg.status == MsgStatus.read) ? MsgStatus.sent : msg.status),
            ],
          ],
        ),
      ],
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote(this.context, this.msg, this.isIncoming, this.onTap);

  final BuildContext context;
  final ChatMsg msg;
  final bool isIncoming;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
                color: isIncoming ? context.vibePrimary : Colors.white,
              ),
            ),
            Text(
              msg.replyText ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isIncoming ? context.vibeTextSecondary : Colors.white70,
              ),
            ),
          ],
        ),
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
          child: Text(emoji, style: const TextStyle(fontSize: 64, height: 1)),
        ),
      ),
    );
  }
}

class _PhotoBubble extends StatelessWidget {
  const _PhotoBubble({required this.msg, required this.incoming, this.onTap, this.isGroup = false});

  final ChatMsg msg;
  final bool incoming;
  final VoidCallback? onTap;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    final url = msg.photoUrl;
    if (url != null && url.isNotEmpty) {
      return _NetworkPhotoBubble(
        url: url,
        time: msg.time,
        incoming: incoming,
        status: msg.status,
        onTap: onTap,
        isGroup: isGroup,
      );
    }
    const palette = [
      VibeColors.primary,
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
        GestureDetector(
          onTap: onTap,
          child: Container(
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
                      l.messagePhotoToChat,
                      style: const TextStyle(fontSize: 10, color: Colors.white),
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
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield, size: 11, color: VibeColors.success),
            const SizedBox(width: 3),
            Text(
              msg.time,
              style: VibeTypography.caption.copyWith(
                color: incoming ? context.vibeTextTertiary : Colors.white70,
                fontSize: 11,
              ),
            ),
            if (!incoming && SettingsService.instance.showTicks) ...[
              const SizedBox(width: 3),
              MessageStatusTick(status: isGroup && (msg.status == MsgStatus.delivered || msg.status == MsgStatus.read) ? MsgStatus.sent : msg.status, size: 13),
            ],
          ],
        ),
      ],
    );
  }
}

class _NetworkPhotoBubble extends StatefulWidget {
  const _NetworkPhotoBubble({
    required this.url,
    required this.time,
    required this.incoming,
    required this.status,
    this.onTap,
    this.isGroup = false,
  });

  final String url;
  final String time;
  final bool incoming;
  final MsgStatus status;
  final VoidCallback? onTap;
  final bool isGroup;

  @override
  State<_NetworkPhotoBubble> createState() => _NetworkPhotoBubbleState();
}

class _NetworkPhotoBubbleState extends State<_NetworkPhotoBubble> {
  bool _manual = false;

  @override
  void initState() {
    super.initState();
    try {
      final s = SettingsService.instance;
      // Если всё выключено — ручная загрузка, иначе авто (учитываем настройки как в TG).
      _manual = !s.autoMediaMobile && !s.autoMediaWifi && !s.autoMediaRoaming;
    } catch (_) {
      _manual = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Пока ручная — показываем плейсхолдер с кнопкой.
    if (_manual) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _manual = false);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 220,
                height: 150,
                color: Colors.black26,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.vibePrimary.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.download_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Нажмите чтобы загрузить',
                      style: VibeTypography.caption.copyWith(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Фото',
                      style: VibeTypography.caption.copyWith(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield, size: 11, color: VibeColors.success),
              const SizedBox(width: 3),
              Text(
                widget.time,
                style: VibeTypography.caption.copyWith(
                  color: widget.incoming ? context.vibeTextTertiary : Colors.white70,
                  fontSize: 11,
                ),
              ),
              if (!widget.incoming && SettingsService.instance.showTicks) ...[
                const SizedBox(width: 3),
                MessageStatusTick(status: widget.isGroup && (widget.status == MsgStatus.delivered || widget.status == MsgStatus.read) ? MsgStatus.sent : widget.status, size: 13),
              ],
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 220,
              height: 150,
              child: VibeNetImage(
                source: widget.url,
                // 5.4: ?????????? ? ??????? ??????? ??????.
                cacheWidth: (220 * MediaQuery.of(context).devicePixelRatio)
                    .round(),
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
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield, size: 11, color: VibeColors.success),
            const SizedBox(width: 3),
            Text(
              widget.time,
              style: VibeTypography.caption.copyWith(
                color: widget.incoming ? context.vibeTextTertiary : Colors.white70,
                fontSize: 11,
              ),
            ),
            if (!widget.incoming && SettingsService.instance.showTicks) ...[
              const SizedBox(width: 3),
              MessageStatusTick(status: widget.isGroup && (widget.status == MsgStatus.delivered || widget.status == MsgStatus.read) ? MsgStatus.sent : widget.status, size: 13),
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
    this.isGroup = false,
  });

  final ChatMsg msg;
  final bool incoming;
  final AudioPlayer player;
  final bool isGroup;

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _progress;
  StreamSubscription<Duration>? _sub;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<Duration>? _durSub;
  Duration _pos = Duration.zero;
  bool _playing = false;
  double _speed = 1.0;
  static const _speedOptions = [0.5, 1.0, 1.5, 2.0];
  late final List<double> _waveform;

  @override
  void initState() {
    super.initState();
    // Фейк-волна как в TG (20 баров, потом заменим на реальную из файла)
    final seed = widget.msg.voiceSeconds * 31 + widget.msg.text.hashCode;
    final rnd = math.Random(seed);
    _waveform = List.generate(24, (_) => 0.25 + rnd.nextDouble() * 0.75);
    _progress = AnimationController(
      vsync: this,
      duration: Duration(
        seconds: widget.msg.voiceSeconds == 0 ? 1 : widget.msg.voiceSeconds,
      ),
      value: 0,
    );
    _sub = widget.player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _pos = pos);
      final dur = widget.player.state == PlayerState.playing ? _progress.duration : null;
      if (dur != null && dur.inMilliseconds > 0) {
        _progress.value = pos.inMilliseconds / dur.inMilliseconds;
      }
    });
    _durSub = widget.player.onDurationChanged.listen((dur) {
      if (!mounted || dur.inMilliseconds <= 0) return;
      _progress.duration = dur;
    });
    _completeSub = widget.player.onPlayerComplete.listen((_) {
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
    _completeSub?.cancel();
    _durSub?.cancel();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final l = VibeLocalizations.of(context);
    final localPath = widget.msg.voicePath;
    var url = widget.msg.voiceUrl;
    if ((localPath == null || localPath.isEmpty) &&
        (url == null || url.isEmpty)) {
      VibeToast.show(context, l.messageNoVoice);
      return;
    }
    setState(() => _playing = !_playing);
    if (_playing) {
      if (widget.player.state != PlayerState.playing) {
        await widget.player.stop();
        if (localPath != null && localPath.isNotEmpty) {
          await widget.player.play(DeviceFileSource(localPath));
          await widget.player.setPlaybackRate(_speed);
        } else {
          final signed = await VibeBackend.instance.mediaUrl(url);
          if (signed == null) {
            setState(() => _playing = false);
            return;
          }
          await widget.player.play(UrlSource(signed));
        }
        await widget.player.setPlaybackRate(_speed);
      } else {
        await widget.player.resume();
        await widget.player.setPlaybackRate(_speed);
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

  void _cycleSpeed() {
    HapticFeedback.lightImpact();
    final idx = _speedOptions.indexOf(_speed);
    setState(() => _speed = _speedOptions[(idx + 1) % _speedOptions.length]);
    if (_playing) widget.player.setPlaybackRate(_speed);
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
                    _playing ? VibeIcons.pause : VibeIcons.play,
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
                  height: 24,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _waveform.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Container(
                              height: 4 + 16 * _waveform[i],
                              decoration: BoxDecoration(
                                color: i / _waveform.length < _progress.value
                                    ? (isIncoming ? context.vibePrimary : Colors.white)
                                    : Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              _fmt(_pos),
              style: VibeTypography.caption.copyWith(
                color: isIncoming ? context.vibeTextSecondary : Colors.white70,
                fontSize: 11,
              ),
            ),
            if (widget.msg.text.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.msg.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VibeTypography.caption.copyWith(
                    color: isIncoming ? context.vibeTextSecondary : Colors.white70,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            if (_speed != 1.0 || _playing) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _cycleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_speed}x',
                    style: VibeTypography.caption.copyWith(
                      color: isIncoming ? context.vibePrimary : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
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
            const Icon(Icons.shield, size: 11, color: VibeColors.success),
            const SizedBox(width: 3),
            Text(
              widget.msg.time,
              style: VibeTypography.caption.copyWith(
                color: isIncoming ? context.vibeTextTertiary : Colors.white70,
                fontSize: 11,
              ),
            ),
            if (!isIncoming && SettingsService.instance.showTicks) ...[
              const SizedBox(width: 3),
              MessageStatusTick(status: widget.isGroup && (widget.msg.status == MsgStatus.delivered || widget.msg.status == MsgStatus.read) ? MsgStatus.sent : widget.msg.status, size: 13),
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

/// Взрыв реакции (как в Telegram: большой эмодзи летит из пузыря
/// в случайную точку с вращением и затуханием).
class _ReactionBurst extends StatelessWidget {
  _ReactionBurst({required this.controller, required this.emoji});

  final AnimationController controller;
  final String emoji;

  /// Случайные параметры полёта (в долях размера оверлея), как в TG:
  /// toX 0.2..0.8, toY 0..0.4, rotation ±60°, scale 0.8..1.2.
  final double _toX = 0.2 + 0.6 * (math.Random().nextDouble());
  final double _toY = 0.4 * math.Random().nextDouble();
  final double _rotation = 120 * (math.Random().nextDouble() - 0.5);
  final double _scale = 0.8 + 0.4 * math.Random().nextDouble();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        // TG: x-ось EASE_OUT_QUINT, y-ось default; появление — scale 0→1.
        final easeOutQuint = Curves.easeOutQuint.transform(t);
        final easeIn = Curves.easeIn.transform(t);
        final scale = easeIn + (1 - easeIn) * 0.28;
        final fade = 1 - Curves.easeOut.transform(t);
        final size = 88.0;
        return SizedBox(
          width: size,
          height: size,
          child: Transform.translate(
            offset: Offset(
              size * (_toX - 0.5) * easeOutQuint,
              -size * 0.5 * _toY * easeOutQuint,
            ),
            child: Transform.rotate(
              angle: _rotation * easeOutQuint * (math.pi / 180),
              child: Opacity(
                opacity: fade,
                child: Transform.scale(
                  scale: scale * _scale,
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 44)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ??????????? ? ??????? ????? ? ???????????????????? ?? ????? (??? ? ??).
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
                    VibeIcons.video,
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

/// ????????????? ????? ??????????? (?????? ??????????).
class EqualizerWave extends StatefulWidget {
  const EqualizerWave({super.key, required this.color});

  final Color color;

  @override
  State<EqualizerWave> createState() => _EqualizerWaveState();
}

class _EqualizerWaveState extends State<EqualizerWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..repeat();

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

/// 8.4.4: ???????? ?????? ?????? (OpenGraph) ??? ??????? ?????????.
/// ???????????? ????? ?????? ?????? ? ?????? ???? ??????; ?????? ?????
/// (??? ???? / ???? ??????????) ? ??????? ?????????? ??? ????????.
class _LinkPreviewCard extends StatelessWidget {
  const _LinkPreviewCard({
    required this.text,
    required this.incoming,
    required this.onOpen,
  });

  final String text;
  final bool incoming;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VibeLinkPreview.instance,
      builder: (context, _) {
        final meta = VibeLinkPreview.instance.metaFor(text);
        if (meta == null || meta.isEmpty) return const SizedBox.shrink();
        final thumb = meta.imageUrl == null
            ? null
            : ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: VibeNetImage(
                    source: meta.imageUrl!,
                    placeholder: Container(
                      color: Colors.black.withValues(alpha: 0.06),
                      child: const Icon(
                        Icons.image_outlined,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              );
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Material(
            color: incoming
                ? context.vibeSurfaceHighlight
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onOpen(meta.url),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?thumb,
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: thumb != null || meta.title != null ? 8 : 12,
                        right: 10,
                        top: 4,
                        bottom: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (meta.title != null)
                            Text(
                              meta.title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: incoming
                                    ? context.vibeTextPrimary
                                    : Colors.white,
                              ),
                            ),
                          if (meta.domain.isNotEmpty)
                            Text(
                              meta.domain,
                              style: TextStyle(
                                fontSize: 11,
                                color: incoming
                                    ? context.vibeTextSecondary
                                    : Colors.white60,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 8.3.3: ???????? ????? ? ???????? ? ??????/????????; ??? ? ??????????
/// ? ????????? ?????????? (??????????? URL ????? media-sign).
/// ?????: ?????????????? ????????????? ?????? (??? ? ??), ?? ????-????????.
class _GifBubble extends StatelessWidget {
  const _GifBubble({
    required this.attach,
    required this.time,
    required this.incoming,
  });

  final AttachmentData attach;
  final String time;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    final sending = attach.url == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 220,
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!sending)
                  VibeNetImage(
                    source: attach.url,
                    fit: BoxFit.cover,
                    cacheWidth:
                        (220 * MediaQuery.of(context).devicePixelRatio)
                            .round(),
                  )
                else
                  Container(
                    color: incoming
                        ? context.vibePrimary.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.10),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Text(
                      'GIF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      time,
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FileBubble extends StatelessWidget {
  const _FileBubble({
    required this.attach,
    required this.incoming,
    this.chatId,
  });

  final AttachmentData attach;
  final bool incoming;
  final String? chatId;

  static const _extIcons = {
    'pdf': Icons.picture_as_pdf_rounded,
    'doc': Icons.description_rounded,
    'docx': Icons.description_rounded,
    'xls': Icons.table_chart_rounded,
    'xlsx': Icons.table_chart_rounded,
    'zip': Icons.folder_zip_rounded,
    'rar': Icons.folder_zip_rounded,
    'txt': Icons.notes_rounded,
    'mp3': Icons.music_note_rounded,
    'mp4': Icons.movie_rounded,
  };

  String get _ext => (attach.name ?? '').split('.').last.toLowerCase();

  IconData get _icon => _extIcons[_ext] ?? Icons.insert_drive_file_rounded;

  String get _sizeText {
    final s = attach.size;
    if (s < 1024) return '$s Б';
    if (s < 1024 * 1024) return '${(s / 1024).toStringAsFixed(1)} КБ';
    return '${(s / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  Future<void> _download(BuildContext context) async {
    if (attach.url == null) return;
    final l = VibeLocalizations.of(context);
    VibeToast.show(context, l.fileSending);
    try {
      final signed = await VibeBackend.instance.mediaUrl(attach.url);
      if (signed == null) throw Exception('no url');
      final res = await http
          .get(Uri.parse(signed))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw Exception('http ${res.statusCode}');
      final dir = await getApplicationDocumentsDirectory();
      final name = attach.name ?? 'file';
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(res.bodyBytes);
      if (!context.mounted) return;
      VibeToast.show(context, l.fileSaved(name));
    } catch (_) {
      if (!context.mounted) return;
      VibeToast.show(context, l.fileDownloadFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    final primary = incoming ? context.vibePrimary : VibeColors.outgoingLink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(VibeRadius.card),
        onTap: () => _download(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_ext == 'gif' && attach.url != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: VibeNetImage(
                      source: attach.url,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        color: primary.withValues(alpha: 0.14),
                        child: Icon(_icon, color: primary, size: 22),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon, color: primary, size: 22),
                ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      attach.name ?? l.fileDefaultName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: incoming
                            ? context.vibeTextPrimary
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      attach.url == null ? l.fileUnknownSize : _sizeText,
                      style: TextStyle(
                        fontSize: 11,
                        color: incoming
                            ? context.vibeTextSecondary
                            : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              if (attach.url != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: incoming ? context.vibeTextSecondary : Colors.white60,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 8.3.3: ???????? ????????? ? ?????????? + ???????? ? ???????.
class _LocationBubble extends StatelessWidget {
  const _LocationBubble({required this.attach, required this.incoming});

  final AttachmentData attach;
  final bool incoming;

  Future<void> _openMaps() async {
    final uri = Uri.parse(
      'https://maps.google.com/?q=${attach.lat.toStringAsFixed(6)},${attach.lng.toStringAsFixed(6)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    final primary = incoming ? context.vibePrimary : VibeColors.outgoingLink;
    final lat = attach.lat.toStringAsFixed(6);
    final lng = attach.lng.toStringAsFixed(6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(VibeIcons.pin, color: primary, size: 18),
            const SizedBox(width: 8),
            Text(
              attach.label?.isNotEmpty == true
                  ? attach.label!
                  : l.messageLocation,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: incoming ? context.vibeTextPrimary : Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$lat, $lng',
          style: TextStyle(
            fontSize: 12,
            color: incoming ? context.vibeTextSecondary : Colors.white70,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(VibeRadius.md),
          onTap: _openMaps,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(VibeRadius.md),
            ),
            child: Text(
              l.messageOpenInMaps,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 8.3.3: ???????? ???????? ? ??????? ????????, ?????? ??????????.
class _ContactBubble extends StatelessWidget {
  const _ContactBubble({
    required this.attach,
    required this.incoming,
    this.onOpenContact,
  });

  final AttachmentData attach;
  final bool incoming;
  final ValueChanged<String>? onOpenContact;

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    final primary = incoming ? context.vibePrimary : VibeColors.outgoingLink;
    final name = attach.contactName ?? l.messageContactDefault;
    final initial = name.isEmpty ? '?' : name.characters.first;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: primary.withValues(alpha: 0.16),
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: incoming ? context.vibeTextPrimary : Colors.white,
                ),
              ),
              if (attach.nick?.isNotEmpty == true)
                Text(
                  '@${attach.nick}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: incoming
                        ? context.vibeTextSecondary
                        : Colors.white60,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          borderRadius: BorderRadius.circular(VibeRadius.md),
          onTap: () {
            if (attach.uid != null) onOpenContact?.call(attach.uid!);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(VibeRadius.md),
            ),
            child: Text(
              l.actionWrite,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 8.3.3: ???????? ?????? ? ????????, ???????????, ???????? ???????.
class _PollBubble extends StatelessWidget {
  const _PollBubble({
    required this.attach,
    required this.pollId,
    required this.incoming,
    required this.votes,
    required this.myVote,
    required this.onVote,
  });

  final AttachmentData attach;
  final String pollId;
  final bool incoming;
  final List<int> votes;
  final int? myVote;
  final ValueChanged<int>? onVote;

  int get _total => votes.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final l = VibeLocalizations.of(context);
    final primary = incoming ? context.vibePrimary : VibeColors.outgoingLink;
    final options = attach.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(VibeIcons.bubble, color: primary, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                attach.question ?? l.pollDefaultQuestion,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: incoming ? context.vibeTextPrimary : Colors.white,
                ),
              ),
            ),
          ],
        ),
        if (attach.anonymous || attach.multiple || attach.quiz) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              if (attach.anonymous)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('анонимно', style: TextStyle(fontSize: 10, color: primary)),
                ),
              if (attach.multiple)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('несколько', style: TextStyle(fontSize: 10, color: primary)),
                ),
              if (attach.quiz)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: VibeColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(attach.correctOption != null ? 'викторина ✓${attach.correctOption! + 1}' : 'викторина', style: TextStyle(fontSize: 10, color: VibeColors.success)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        for (var i = 0; i < options.length; i++) ...[
          _PollOption(
            index: i,
            label: options[i],
            count: i < votes.length ? votes[i] : 0,
            total: _total,
            selected: myVote == i,
            canVote: myVote == null && onVote != null,
            incoming: incoming,
            onTap: () => onVote?.call(i),
          ),
          if (i < options.length - 1) const SizedBox(height: 6),
        ],
        const SizedBox(height: 6),
        Text(
          _total == 0 ? l.pollVotesZero : '$_total ${_plural(_total)}',
          style: TextStyle(
            fontSize: 11,
            color: incoming ? context.vibeTextSecondary : Colors.white60,
          ),
        ),
      ],
    );
  }

  static String _plural(int n) {
    final m = n % 10;
    final h = n % 100;
    if (h >= 11 && h <= 14) return 'голосов';
    if (m == 1) return 'голос';
    if (m >= 2 && m <= 4) return 'голоса';
    return 'голосов';
  }
}

class _PollOption extends StatelessWidget {
  const _PollOption({
    required this.index,
    required this.label,
    required this.count,
    required this.total,
    required this.selected,
    required this.canVote,
    required this.incoming,
    required this.onTap,
  });

  final int index;
  final String label;
  final int count;
  final int total;
  final bool selected;
  final bool canVote;
  final bool incoming;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = incoming ? context.vibePrimary : VibeColors.outgoingLink;
    final textColor = incoming ? context.vibeTextPrimary : Colors.white;
    final pct = total == 0
        ? 0.0
        : (count / total * 100).clamp(0, 100).toDouble();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: canVote ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: (canVote || selected)
              ? primary.withValues(alpha: selected ? 0.16 : 0.07)
              : primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? primary.withValues(alpha: 0.7)
                : primary.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${index + 1}.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 4,
                  backgroundColor: primary.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Кружок-чекбокс выделения (Telegram-паттерн): пустой круг — не выбрано,
/// залитый круг с галочкой — выбрано.
class _SelectionCheck extends StatelessWidget {
  const _SelectionCheck({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? context.vibePrimary : Colors.transparent,
        border: Border.all(
          color: isSelected
              ? context.vibePrimary
              : context.vibeTextTertiary.withValues(alpha: 0.7),
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }
}

/// Telegram-хвост пузыря: маленький уголок снизу со стороны отправителя.
class _TailPainter extends CustomPainter {
  const _TailPainter({required this.color, required this.mirror});

  final Color color;

  /// true — хвост у правого края (исходящее), false — у левого.
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (mirror) {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, 0);
    } else {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.mirror != mirror;
}
