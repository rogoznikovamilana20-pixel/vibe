import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// LiveKit SFU сервис для групповых звонков.
///
/// Использует `livekit_client` для подключения к комнате `group_{chatId}`.
/// Токен берётся из Edge Function `livekit-token`.
class LiveKitService {
  LiveKitService._();
  static final instance = LiveKitService._();

  Room? _room;
  EventsListener<RoomEvent>? _listener;

  final _eventsController = StreamController<LiveKitEvent>.broadcast();
  Stream<LiveKitEvent> get events => _eventsController.stream;

  final ValueNotifier<bool> inCall = ValueNotifier(false);
  final ValueNotifier<bool> muted = ValueNotifier(false);
  final ValueNotifier<bool> cameraEnabled = ValueNotifier(false);
  final ValueNotifier<List<Participant>> participants = ValueNotifier([]);

  Room? get room => _room;
  bool get isInCall => inCall.value;

  String? _currentRoomName;
  String? get currentRoomName => _currentRoomName;

  /// Подключиться к групповой комнате.
  Future<bool> joinRoom(String chatId) async {
    if (inCall.value) return false;

    final roomName = 'group_$chatId';
    _currentRoomName = roomName;

    try {
      // 1) Получить токен из Edge Function
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      final res = await supabase.functions.invoke(
        'livekit-token',
        body: {
          'room_name': roomName,
          'participant_identity': user.id,
          'participant_name': user.email ?? user.id,
        },
      );

      if (res.status != 200 || res.data == null) {
        debugPrint('LiveKit token error: ${res.data}');
        return false;
      }

      final token = (res.data as Map)['token'] as String?;
      final url = (res.data as Map)['url'] as String?;
      if (token == null || url == null) return false;

      // 2) Подключиться к комнате
      _room = Room();
      _listener = _room!.createListener();

      _listener!
        ..on<RoomConnectedEvent>((_) {
          inCall.value = true;
          _refreshParticipants();
        })
        ..on<RoomDisconnectedEvent>((_) {
          _cleanup();
        })
        ..on<ParticipantConnectedEvent>((e) {
          participants.value = [..._room!.remoteParticipants.values];
          _eventsController.add(LiveKitEvent.participantJoined(e.participant.identity));
        })
        ..on<ParticipantDisconnectedEvent>((e) {
          participants.value = [..._room!.remoteParticipants.values];
          _eventsController.add(LiveKitEvent.participantLeft(e.participant.identity));
        })
        ..on<TrackSubscribedEvent>((e) {
          _refreshParticipants();
        })
        ..on<TrackUnsubscribedEvent>((_) {
          _refreshParticipants();
        });

      await _room!.connect(url, token);

      // 3) Опубликовать локальные треки (аудио вкл, видео выкл по умолчанию)
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      muted.value = false;
      cameraEnabled.value = false;

      // 4) Отправить пуш остальным участникам группы
      try {
        await supabase.functions.invoke('send-call-invite', body: {
          'chat_id': chatId,
          'call_id': roomName,
          'caller_id': user.id,
          'caller_name': user.email ?? 'Пользователь',
          'call_type': 'group',
        });
      } catch (_) {
        // non-critical
      }

      inCall.value = true;
      _refreshParticipants();
      return true;
    } catch (e) {
      debugPrint('LiveKit join error: $e');
      await _cleanup();
      return false;
    }
  }

  Future<void> leaveRoom() async {
    await _cleanup();
  }

  Future<void> toggleMute() async {
    final room = _room;
    if (room == null) return;
    final newMuted = !muted.value;
    await room.localParticipant?.setMicrophoneEnabled(!newMuted);
    muted.value = newMuted;
  }

  Future<void> toggleCamera() async {
    final room = _room;
    if (room == null) return;
    final newEnabled = !cameraEnabled.value;
    await room.localParticipant?.setCameraEnabled(newEnabled);
    cameraEnabled.value = newEnabled;
  }

  Future<void> setScreenShare(bool enabled) async {
    final room = _room;
    if (room == null) return;
    await room.localParticipant?.setScreenShareEnabled(enabled);
  }

  void _refreshParticipants() {
    final room = _room;
    if (room == null) return;
    participants.value = [...room.remoteParticipants.values];
  }

  Future<void> _cleanup() async {
    try {
      await _listener?.dispose();
    } catch (_) {}
    _listener = null;

    try {
      await _room?.disconnect();
    } catch (_) {}
    _room = null;

    _currentRoomName = null;
    inCall.value = false;
    muted.value = false;
    cameraEnabled.value = false;
    participants.value = [];
  }

  void dispose() {
    _eventsController.close();
    _cleanup();
  }
}

/// Событие LiveKit для UI.
class LiveKitEvent {
  const LiveKitEvent._(this.type, this.identity);

  factory LiveKitEvent.participantJoined(String id) =>
      LiveKitEvent._('joined', id);
  factory LiveKitEvent.participantLeft(String id) =>
      LiveKitEvent._('left', id);

  final String type; // joined | left
  final String identity;
}
