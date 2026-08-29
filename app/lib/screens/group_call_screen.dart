import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/vibe_colors.dart';
import '../core/theme/vibe_spacing.dart';
import '../core/theme/vibe_typography.dart';
import '../core/widgets/vibe_avatar.dart';
import '../core/widgets/vibe_icon_button.dart';
import '../data/backend.dart';
import '../data/livekit_service.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Групповой звонок как в TG: LiveKit SFU, сетка участников, mute/камера/завершить.
class GroupCallScreen extends StatefulWidget {
  const GroupCallScreen({super.key, required this.chat, this.participants = const []});

  final VibeChat chat;
  final List<VibeProfile> participants;

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  final _liveKit = LiveKitService.instance;
  bool _connecting = true;
  String? _error;
  StreamSubscription<LiveKitEvent>? _eventSub;
  late List<VibeProfile> _fallbackParts;
  bool _blur = false;
  DateTime? _callStart;

  @override
  void initState() {
    super.initState();
    _callStart = DateTime.now();
    _fallbackParts = List.of(widget.participants);
    if (_fallbackParts.isEmpty) {
      _fallbackParts = [
        VibeProfile(
            id: 'me',
            username: 'you',
            displayName: widget.chat.title,
            phone: null,
            fcmToken: null,
            uid: null,
            emoji: null,
            avatar: widget.chat.peerAvatar,
            bio: '',
            online: true),
      ];
    }
    _eventSub = _liveKit.events.listen((_) {
      if (mounted) setState(() {});
    });
    _join();
  }

  Future<void> _join() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    final ok = await _liveKit.joinRoom(widget.chat.id);
    if (!mounted) return;
    setState(() {
      _connecting = false;
      if (!ok) _error = 'Не удалось подключиться к звонку';
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    // Не делаем leave синхронно в dispose — пусть юзер нажмёт завершить,
    // но если экран закрыли свайпом — тоже выходим.
    unawaited(_liveKit.leaveRoom());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = _liveKit.muted.value;
    final cameraOn = _liveKit.cameraEnabled.value;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B12),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(VibeSpacing.md, VibeSpacing.sm, VibeSpacing.md, VibeSpacing.sm),
              child: Row(
                children: [
                  VibeIconButton(
                    icon: Icons.keyboard_arrow_down_rounded,
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Свернуть',
                    color: Colors.white,
                  ),
                  const SizedBox(width: VibeSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.chat.title,
                            style: VibeTypography.subtitle.copyWith(color: Colors.white, fontSize: 16),
                            overflow: TextOverflow.ellipsis),
                        ValueListenableBuilder<List<lk.Participant>>(
                          valueListenable: _liveKit.participants,
                          builder: (_, parts, __) {
                            final count = parts.length + 1; // + local
                            final status = _connecting
                                ? 'подключение…'
                                : (_error != null
                                    ? _error!
                                    : '$count участников · ${muted ? 'микро выкл' : 'в эфире'}');
                            return Text(status,
                                style: VibeTypography.caption.copyWith(color: Colors.white70, fontSize: 12));
                          },
                        ),
                      ],
                    ),
                  ),
                  VibeIconButton(
                    icon: VibeIcons.moreVertical,
                    onPressed: () {},
                    tooltip: 'Меню',
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            if (_connecting)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white70),
                      SizedBox(height: 12),
                      Text('Подключение…', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.signal_wifi_bad_rounded, color: Colors.white54, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _join, child: const Text('Повторить')),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(VibeSpacing.md),
                  child: ValueListenableBuilder<List<lk.Participant>>(
                    valueListenable: _liveKit.participants,
                    builder: (context, remoteParts, _) {
                      // Локальный + удалённые
                      final total = remoteParts.length + 1;
                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: VibeSpacing.md,
                          crossAxisSpacing: VibeSpacing.md,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: total,
                        itemBuilder: (context, i) {
                          final isLocal = i == 0;
                          if (isLocal) {
                            return _ParticipantTile(
                              name: 'Вы',
                              subtitle: 'Вы',
                              isMuted: muted,
                              isLocal: true,
                              cameraOn: cameraOn,
                              room: _liveKit.room,
                              participant: _liveKit.room?.localParticipant,
                              blur: _blur,
                            );
                          }
                          final p = remoteParts[i - 1];
                          return _ParticipantTile(
                            name: p.identity,
                            subtitle: 'участник',
                            isMuted: p.audioTrackPublications.isEmpty ||
                                (p.audioTrackPublications.first.muted),
                            isLocal: false,
                            cameraOn: p.videoTrackPublications.isNotEmpty &&
                                p.videoTrackPublications.first.track != null,
                            room: _liveKit.room,
                            participant: p,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            Container(
              padding: EdgeInsets.fromLTRB(
                  VibeSpacing.lg, VibeSpacing.md, VibeSpacing.lg, MediaQuery.of(context).viewPadding.bottom + VibeSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1B22),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _liveKit.muted,
                    builder: (_, isMuted, __) => _CallAction(
                      icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: isMuted ? VibeColors.error : Colors.white10,
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        await _liveKit.toggleMute();
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _liveKit.cameraEnabled,
                    builder: (_, camOn, __) => _CallAction(
                      icon: camOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                      color: camOn ? VibeColors.primary : Colors.white10,
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        await _liveKit.toggleCamera();
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                  _CallAction(
                    icon: _blur ? Icons.blur_on_rounded : Icons.blur_off_rounded,
                    color: _blur ? VibeColors.primary : Colors.white10,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _blur = !_blur);
                    },
                  ),
                  _CallAction(
                    icon: Icons.call_end_rounded,
                    color: VibeColors.error,
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      // Запись метрики длительности звонка
                      final secs = _callStart != null ? DateTime.now().difference(_callStart!).inSeconds : 0;
                      try {
                        if (secs > 5) {
                          final uid = VibeBackend.instanceOrNull?.myProfileId ?? Supabase.instance.client.auth.currentUser?.id;
                          if (uid != null) {
                            final biz = await Supabase.instance.client.from('businesses').select('id').eq('owner_id', uid).limit(1);
                            if (biz.isNotEmpty) {
                              final bid = biz.first['id'] as String;
                              await Supabase.instance.client.from('business_metrics_daily').upsert({'business_id': bid, 'date': DateTime.now().toIso8601String().substring(0,10), 'views': 0, 'clicks': 0, 'orders': 0, 'revenue': 0, 'unique_chats': 1}, onConflict: 'business_id,date');
                            }
                          }
                        }
                      } catch (_) {}
                      await _liveKit.leaveRoom();
                      if (mounted) Navigator.of(context).maybePop();
                    },
                  ),
                  _CallAction(
                    icon: Icons.screen_share_rounded,
                    color: Colors.white10,
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      // Тоггл шаринга экрана
                      final room = _liveKit.room;
                      if (room == null) return;
                      final sharing = room.localParticipant?.isScreenShareEnabled() ?? false;
                      await _liveKit.setScreenShare(!sharing);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.name,
    required this.subtitle,
    required this.isMuted,
    required this.isLocal,
    required this.cameraOn,
    this.room,
    this.participant,
    this.blur = false,
  });

  final String name;
  final String subtitle;
  final bool isMuted;
  final bool isLocal;
  final bool cameraOn;
  final lk.Room? room;
  final lk.Participant? participant;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final hasVideo = cameraOn && participant != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Видео если есть, иначе аватар
          if (hasVideo && participant != null)
            Positioned.fill(
              child: Builder(
                builder: (context) {
                  final tracks = participant!.videoTrackPublications;
                  final pub = tracks.isNotEmpty ? tracks.first : null;
                  final track = pub?.track;
                  if (track is lk.VideoTrack) {
                    final video = lk.VideoTrackRenderer(track);
                    if (blur && isLocal) {
                      return ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: video);
                    }
                    return video;
                  }
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VibeAvatar(name: name, size: 72),
                        const SizedBox(height: VibeSpacing.sm),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.sm),
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VibeTypography.body.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: VibeTypography.caption.copyWith(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VibeAvatar(name: name, size: 72),
                  const SizedBox(height: VibeSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: VibeSpacing.sm),
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VibeTypography.body.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: VibeTypography.caption.copyWith(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                  color: isMuted && isLocal ? VibeColors.error : Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: Icon(isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, size: 14, color: Colors.white),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: isLocal ? VibeColors.success : Colors.white24, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallAction extends StatelessWidget {
  const _CallAction({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
