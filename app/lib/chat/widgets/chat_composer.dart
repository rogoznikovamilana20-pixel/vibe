import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/vibe_animations.dart';
import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import 'message_bubble.dart';

/// Кнопка отправки / микрофона: держишь — запись, свайп вверх — замочек,
/// свайп влево — отмена (как в TG).
class SendButton extends StatefulWidget {
  const SendButton({
    super.key,
    required this.canSend,
    required this.recording,
    required this.locked,
    required this.onMicTap,
    required this.onSend,
    required this.onRelease,
    required this.onLock,
    required this.onUnlock,
    required this.onCancel,
  });

  final bool canSend;
  final bool recording;
  final bool locked;
  final VoidCallback onMicTap;
  final VoidCallback onSend;
  final VoidCallback onRelease;
  final VoidCallback onLock;
  final VoidCallback onUnlock;
  final VoidCallback onCancel;

  @override
  State<SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<SendButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  AnimationController get _pulseController {
    return _pulse ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  double _dragDy = 0;
  double _dragDx = 0;
  Timer? _holdTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulse?.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragDy += d.delta.dy;
      _dragDx += d.delta.dx;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (widget.recording) {
      if (_dragDx < -70) {
        // Свайп влево — отмена записи (как в TG: перетащил на корзину).
        HapticFeedback.heavyImpact(); // ВИБРО ПРИ ОТМЕНЕ
        widget.onCancel();
      } else if (_dragDy < -40) {
        HapticFeedback.selectionClick(); // ВИБРО ПРИ ЗАМОЧКЕ
        widget.onLock();
      } else if (_dragDy > 56 && widget.locked) {
        HapticFeedback.selectionClick();
        widget.onUnlock();
      } else if (!widget.locked) {
        widget.onRelease();
      }
    }
    setState(() {
      _dragDy = 0;
      _dragDx = 0;
    });
  }

  void _onTapDown(TapDownDetails d) {
    if (widget.canSend || widget.recording || widget.locked) return;
    _holdTimer?.cancel();
    _holdTimer = Timer(
      const Duration(milliseconds: 220),
      () {
        if (mounted && !widget.recording) widget.onMicTap();
      },
    );
  }

  void _onTapUp(TapUpDetails d) {
    _holdTimer?.cancel();
    if (widget.recording && !widget.locked) widget.onRelease();
  }

  void _onTapCancel() {
    _holdTimer?.cancel();
  }

  void _onTap() {
    HapticFeedback.lightImpact(); // КЛИК ПО КНОПКЕ
    if (widget.canSend) {
      widget.onSend();
    } else if (widget.recording && widget.locked) {
      widget.onSend();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stretch = widget.recording && !widget.locked
        ? (1 + 0.18 * _pulseController.value * (0.6 + 0.4 * ((now / 130) % 1)))
        : (widget.recording && widget.locked ? 1.0 : 1.0);

    return GestureDetector(
      onTap: _onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedContainer(
        duration: VibeAnimations.pulse,
        curve: VibeAnimations.springy,
        width: 48,
        height: 48,
        transform: Matrix4.diagonal3Values(stretch, stretch, 1),
        decoration: BoxDecoration(
          color: widget.canSend
              ? context.vibePrimary
              : (widget.recording
                  ? (widget.locked
                      ? context.vibePrimary
                      : VibeColors.warning.withValues(alpha: 0.16))
                  : context.vibeSurfaceVariant),
          shape: BoxShape.circle,
          border: widget.recording && !widget.locked
              ? Border.all(
                  color: VibeColors.warning.withValues(alpha: 0.5),
                  width: 2,
                )
              : null,
        ),
        child: AnimatedSwitcher(
          duration: VibeAnimations.fadeIn,
          child: widget.canSend
              ? const Icon(
                  Icons.send_rounded,
                  key: ValueKey('send'),
                  color: Colors.white,
                  size: 22,
                )
              : widget.locked
                  ? const Icon(
                      Icons.lock_rounded,
                      key: ValueKey('lock'),
                      color: Colors.white,
                      size: 22,
                    )
                  : Icon(
                      Icons.mic_rounded,
                      key: const ValueKey('mic'),
                      color: widget.recording ? VibeColors.warning : context.vibePrimary,
                      size: 22,
                    ),
        ),
      ),
    );
  }
}

/// Панель «Ответ …» / «Редактирование» над полем ввода.
class ReplyPanel extends StatelessWidget {
  const ReplyPanel({
    super.key,
    required this.author,
    required this.text,
    required this.onClose,
  });

  final String author;
  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        VibeSpacing.md,
        VibeSpacing.sm,
        VibeSpacing.xs,
        VibeSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.vibeSurfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: context.vibePrimary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ответ $author',
                  style: VibeTypography.label.copyWith(
                    color: context.vibePrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VibeTypography.caption.copyWith(
                    color: context.vibeTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: context.vibeTextSecondary,
            tooltip: 'Отменить ответ',
          ),
        ],
      ),
    );
  }
}

/// Пилюля записи голосового: таймер, эквалайзер, отмена/отправка.
class RollingPill extends StatelessWidget {
  const RollingPill({
    super.key,
    required this.seconds,
    required this.locked,
    required this.onCancel,
    required this.onSend,
  });

  final int seconds;
  final bool locked;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: VibeSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.vibeSurfaceVariant,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: (locked ? context.vibePrimary : VibeColors.warning)
              .withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          const EqualizerWave(color: VibeColors.warning),
          const SizedBox(width: VibeSpacing.md),
          Text(
            '0:${seconds.toString().padLeft(2, '0')}',
            style: VibeTypography.bodyMedium.copyWith(
              color: context.vibeTextPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: VibeSpacing.sm),
          Expanded(
            child: Text(
              locked
                  ? 'Зафиксировано — тап по кнопке: отправить'
                  : 'Свайп вверх — зафиксировать · влево — отменить',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VibeTypography.caption.copyWith(
                color: context.vibeTextSecondary,
              ),
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 22),
            color: VibeColors.error,
            tooltip: 'Отмена',
          ),
          if (locked)
            IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded, size: 20),
              color: context.vibePrimary,
              tooltip: 'Отправить',
            ),
        ],
      ),
    );
  }
}

/// Пилюля записи видеокружка: круглый предпросмотр камеры, таймер.
class VideoRollPill extends StatelessWidget {
  const VideoRollPill({
    super.key,
    required this.cam,
    required this.seconds,
    required this.locked,
    required this.onCancel,
    required this.onSend,
  });

  final CameraController? cam;
  final int seconds;
  final bool locked;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.md),
      decoration: BoxDecoration(
        color: context.vibeSurfaceVariant,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: (locked ? context.vibePrimary : VibeColors.warning)
              .withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Круглый предпросмотр камеры во время записи (как в TG).
          if (cam != null && cam!.value.isInitialized)
            SizedBox(
              width: 38,
              height: 38,
              child: ClipOval(
                child: CameraPreview(
                  cam!,
                  child: const SizedBox.shrink(),
                ),
              ),
            )
          else
            const SizedBox(width: 38, height: 38),
          const SizedBox(width: VibeSpacing.sm),
          Text(
            '0:${seconds.toString().padLeft(2, '0')}',
            style: VibeTypography.bodyMedium.copyWith(
              color: context.vibeTextPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: VibeSpacing.sm),
          Expanded(
            child: Text(
              locked ? 'Зафиксировано' : 'Свайп вверх — зафиксировать · влево — отмена',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VibeTypography.caption.copyWith(
                color: context.vibeTextSecondary,
              ),
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 22),
            color: VibeColors.error,
            tooltip: 'Отмена',
          ),
          if (locked)
            IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded, size: 20),
              color: context.vibePrimary,
              tooltip: 'Отправить',
            ),
        ],
      ),
    );
  }
}

/// Плитка вложения в меню «прикрепить» (фото/файл/опрос/локация…).
class AttachmentItem extends StatelessWidget {
  const AttachmentItem({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.35), color],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: VibeTypography.caption.copyWith(
              color: context.vibeTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Быстрая реакция в панели действий над сообщением.
class ReactionButton extends StatelessWidget {
  const ReactionButton({super.key, required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.vibeSurfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

/// Строка действия в меню сообщения / чата (иконка + подпись).
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: context.vibePrimary),
      title: Text(
        label,
        style: VibeTypography.body.copyWith(
          color: context.vibeTextPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}
