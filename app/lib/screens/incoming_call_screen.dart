import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_icon_font.dart';
import '../../data/webrtc_service.dart';
import 'call_screen.dart';

/// Экран входящего звонка — полноэкранный, показывается поверх всего.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerId,
    required this.callId,
    required this.callType,
    this.chatId,
  });

  final String callerName;
  final String callerId;
  final String callId;
  final String callType; // "voice" | "video"
  final String? chatId;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  Timer? _timeout;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Автоотклонение через 30 секунд
    _timeout = Timer(const Duration(seconds: 30), () {
      if (mounted && !_answered) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timeout?.cancel();
    super.dispose();
  }

  void _answer() {
    _answered = true;
    _timeout?.cancel();
    Navigator.of(context).pop(); // закрываем этот экран
    // Переходим в CallScreen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          peerName: widget.callerName,
          peerEmoji: '',
          callId: widget.callId,
          peerId: widget.callerId,
          video: widget.callType == 'video',
          incoming: true,
        ),
      ),
    );
  }

  void _reject() {
    WebRtcService.instance.rejectCall(widget.callId, widget.callerId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'video';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _reject();
      },
      child: Scaffold(
        backgroundColor: VibeColors.bgDark,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Caller avatar with pulse animation
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, child) {
                  final scale = 1.0 + _pulseCtrl.value * 0.08;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isVideo ? VibeColors.primary : VibeColors.success)
                            .withValues(alpha: 0.15 + _pulseCtrl.value * 0.1),
                        border: Border.all(
                          color: (isVideo ? VibeColors.primary : VibeColors.success)
                              .withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                          size: 56,
                          color: isVideo ? VibeColors.primary : VibeColors.success,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: VibeSpacing.xl),
              Text(
                widget.callerName,
                style: VibeTypography.display.copyWith(
                  color: VibeColors.textPrimaryDark,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: VibeSpacing.sm),
              Text(
                isVideo ? 'Видеозвонок' : 'Голосовой звонок',
                style: VibeTypography.body.copyWith(
                  color: VibeColors.textSecondaryDark,
                ),
              ),
              const Spacer(flex: 2),
              // Answer / Reject buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject
                  GestureDetector(
                    onTap: _reject,
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent,
                          ),
                          child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: VibeSpacing.sm),
                        Text(
                          'Отклонить',
                          style: VibeTypography.caption.copyWith(
                            color: VibeColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Answer
                  GestureDetector(
                    onTap: _answer,
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: VibeColors.success,
                          ),
                          child: Icon(
                            isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: VibeSpacing.sm),
                        Text(
                          'Ответить',
                          style: VibeTypography.caption.copyWith(
                            color: VibeColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: VibeSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
