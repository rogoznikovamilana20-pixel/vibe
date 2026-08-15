import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/theme/vibe_colors.dart';
import '../../core/theme/vibe_spacing.dart';
import '../../core/theme/vibe_theme.dart';
import '../../core/theme/vibe_typography.dart';
import '../../core/widgets/vibe_icon_font.dart';
import '../../data/webrtc_service.dart';

/// Экран звонка (аудио/видео).
class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.peerName,
    required this.peerEmoji,
    this.callId = '',
    this.peerId = '',
    this.video = false,
    this.incoming = false,
  });

  final String peerName;
  final String peerEmoji;
  final String callId;
  final String peerId;
  final bool video;
  final bool incoming;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _service = WebRtcService.instance;
  bool _connecting = true;
  bool _video = false;
  bool _muted = false;
  bool _speakerOn = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _video = widget.video;
    _init();
  }

  Future<void> _init() async {
    await _service.initRenderers();
    if (widget.incoming) {
      await _service.answerCall(
        callId: widget.callId,
        callerId: widget.peerId,
        video: _video,
      );
    } else {
      await _service.startCall(
        callId: widget.callId,
        peerId: widget.peerId,
        video: _video,
      );
    }
    if (mounted) {
      setState(() => _connecting = false);
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  String get _formattedTime {
    final m = _elapsed.inMinutes;
    final s = _elapsed.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _hangUp() async {
    _timer?.cancel();
    await _service.hangUp();
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute() {
    final audioTrack = _service.localRenderer.srcObject?.getAudioTracks().firstOrNull;
    if (audioTrack != null) {
      audioTrack.enabled = !audioTrack.enabled;
      setState(() => _muted = !_muted);
    }
  }

  void _toggleSpeaker() {
    final audioTrack = _service.localRenderer.srcObject?.getAudioTracks().firstOrNull;
    if (audioTrack != null) {
      // Включаем/выключаем маршрутизацию на динамик через WebRTC API
      audioTrack.enableSpeakerphone(!_speakerOn);
      setState(() => _speakerOn = !_speakerOn);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _service.hangUp();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VibeColors.bgDark,
      body: SafeArea(
        child: _video && _service.inCall ? _buildVideoLayout() : _buildAudioLayout(),
      ),
    );
  }

  Widget _buildVideoLayout() {
    return Stack(
      children: [
        // Remote video (full screen)
        Positioned.fill(
          child: RTCVideoView(
            _service.remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
        // Local video (small corner)
        Positioned(
          right: 16,
          top: MediaQuery.paddingOf(context).top + 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 120,
              height: 160,
              child: RTCVideoView(
                _service.localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),
        ),
        // Bottom controls
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.paddingOf(context).bottom + 32,
          child: Column(
            children: [
              Text(
                widget.peerName,
                style: VibeTypography.display.copyWith(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: VibeSpacing.sm),
              Text(
                _connecting ? 'Подключение...' : (_service.inCall ? _formattedTime : 'Звонок завершён'),
                style: VibeTypography.body.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: VibeSpacing.xxl),
              if (!_connecting) _buildControls(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioLayout() {
    return Column(
      children: [
        const Spacer(flex: 2),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VibeColors.primary.withValues(alpha: 0.15),
          ),
          child: Center(
            child: Text(
              widget.peerEmoji.isNotEmpty ? widget.peerEmoji : widget.peerName.characters.firstOrNull ?? '?',
              style: const TextStyle(fontSize: 48),
            ),
          ),
        ),
        const SizedBox(height: VibeSpacing.lg),
        Text(
          widget.peerName,
          style: VibeTypography.display.copyWith(
            color: VibeColors.textPrimaryDark,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: VibeSpacing.sm),
        Text(
          _connecting ? 'Подключение...' : (_service.inCall ? _formattedTime : 'Звонок завершён'),
          style: VibeTypography.body.copyWith(color: VibeColors.textSecondaryDark),
        ),
        const Spacer(flex: 2),
        if (!_connecting) _buildControls(),
        const SizedBox(height: VibeSpacing.xxl),
      ],
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _circleButton(
              icon: _muted ? Icons.mic_off : Icons.mic,
              label: _muted ? 'Вкл. звук' : 'Выкл. звук',
              onTap: _toggleMute,
            ),
            _circleButton(
              icon: _speakerOn ? Icons.volume_up : Icons.volume_down,
              label: _speakerOn ? 'Динамик' : 'Телефон',
              onTap: _toggleSpeaker,
            ),
          ],
        ),
        const SizedBox(height: VibeSpacing.xxl),
        GestureDetector(
          onTap: _hangUp,
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.redAccent,
            ),
            child: const Icon(Icons.call_end, color: Colors.white, size: 36),
          ),
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? VibeColors.surfaceDark : VibeColors.surfaceDark.withValues(alpha: 0.4),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: VibeTypography.caption.copyWith(color: VibeColors.textSecondaryDark),
          ),
        ],
      ),
    );
  }
}
