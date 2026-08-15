import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend.dart';

/// Сигнальные типы для звонков
enum CallMessageType { offer, answer, iceCandidate, hangUp, reject }

/// Максимальная длительность звонка (30 минут).
const _kMaxCallDuration = Duration(minutes: 30);

/// Максимальный возраст сигнала для защиты от устаревших событий (60 сек).
const _kMaxSignalAge = Duration(seconds: 60);

/// Простой Signaling через Supabase Realtime-каналы.
/// Каждый звонок создаёт уникальный канал `call:<callId>`.
class WebRtcService {
  WebRtcService._();
  static final instance = WebRtcService._();

  /// TURN/ICE server configuration. Can be overridden for testing or
  /// when a production TURN server is available.
  static List<Map<String, dynamic>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    // TODO: Replace with production TURN server before release.
    // OpenRelay free TURN is NOT suitable for production.
    {
      'urls': 'turn:openrelay.metered.ca:443',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
  ];

  final _client = Supabase.instance.client;
  RealtimeChannel? _channel;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  bool _inCall = false;
  bool get inCall => _inCall;

  String? _currentCallId;

  Timer? _callTimeout;
  Timer? _noAnswerTimer;
  bool _answerReceived = false;
  bool _iceRestartAttempted = false;
  Map<String, bool>? _knownParticipants;

  // ── Public API ──────────────────────────────────────────────

  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> dispose() async {
    await localRenderer.dispose();
    await remoteRenderer.dispose();
    await _cleanup();
  }

  Future<void> startCall({
    required String callId,
    required String peerId,
    required bool video,
  }) async {
    if (_inCall) return;
    _currentCallId = callId;
    _inCall = true;

    await _setupLocalStream(video);
    await _createPeerConnection();
    _subscribeToChannel(callId);

    // Send push notification to peer about incoming call
    try {
      final callerName = VibeBackend.instance.myProfile?.displayName ?? 'Пользователь';
      await _client.functions.invoke('send-call-invite', body: {
        'chat_id': callId,
        'call_id': callId,
        'caller_id': _client.auth.currentUser!.id,
        'caller_name': callerName,
        'call_type': video ? 'video' : 'voice',
      });
    } catch (_) {
      // Non-critical: call still works via Realtime signaling
    }

    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': video,
    });
    await _peerConnection!.setLocalDescription(offer);

    _sendSignal(callId, {
      'type': CallMessageType.offer.index,
      'sdp': offer.sdp,
      'sdpType': offer.type,
      'callerId': _client.auth.currentUser!.id,
      'video': video,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });

    _startCallTimer();

    _answerReceived = false;
    _noAnswerTimer?.cancel();
    _noAnswerTimer = Timer(const Duration(seconds: 30), () {
      if (!_answerReceived && _inCall) {
        debugPrint('WebRTC: no answer within 30s, hanging up');
        hangUp();
      }
    });
  }

  Future<void> answerCall({
    required String callId,
    required String callerId,
    required bool video,
  }) async {
    if (_inCall) return;
    _currentCallId = callId;
    _inCall = true;

    await _setupLocalStream(video);
    await _createPeerConnection();
    _subscribeToChannel(callId);
    _startCallTimer();
  }

  Future<void> hangUp() async {
    if (_currentCallId != null) {
      _sendSignal(_currentCallId!, {
        'type': CallMessageType.hangUp.index,
        'userId': _client.auth.currentUser!.id,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await _cleanup();
  }

  Future<void> rejectCall(String callId, String callerId) async {
    _sendSignal(callId, {
      'type': CallMessageType.reject.index,
      'userId': _client.auth.currentUser!.id,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    await _cleanup();
  }

  // ── Private ─────────────────────────────────────────────────

  Future<void> _setupLocalStream(bool video) async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
            }
          : false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    localRenderer.srcObject = _localStream;
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection({
      'iceServers': WebRtcService.iceServers,
    });

    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
      }
    };

    _peerConnection!.onIceCandidate = (candidate) {
      if (_currentCallId != null) {
        _sendSignal(_currentCallId!, {
          'type': CallMessageType.iceCandidate.index,
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'userId': _client.auth.currentUser!.id,
          'ts': DateTime.now().millisecondsSinceEpoch,
        });
      }
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint('WebRTC connection: $state');
      if (state.name.contains('failed')) {
        // Attempt ICE restart once
        if (!_iceRestartAttempted) {
          _iceRestartAttempted = true;
          _attemptIceRestart();
        } else {
          hangUp();
        }
      } else if (state.name.contains('closed')) {
        hangUp();
      }
    };
  }

  void _subscribeToChannel(String callId) {
    _channel?.unsubscribe();
    _channel = _client.channel('call:$callId');

    _channel!.onBroadcast(
      event: 'signal',
      callback: (payload) async {
        final data = Map<String, dynamic>.from(payload as Map);
        final myId = _client.auth.currentUser?.id;
        final senderId = data['userId'] ?? data['callerId'];

        if (senderId == myId) return;

        // Track participants — only accept signals from chat members
        _knownParticipants ??= {};
        final type = CallMessageType.values[data['type'] as int];
        if (type == CallMessageType.offer || type == CallMessageType.answer) {
          _knownParticipants![senderId] = true;
        }
        // For non-initial signals, verify sender was a participant
        if (type != CallMessageType.offer && type != CallMessageType.answer) {
          if (_knownParticipants![senderId] != true) {
            debugPrint('WebRTC: rejected signal from unknown participant $senderId');
            return;
          }
        }

        // Защита от устаревших событий
        final ts = data['ts'] as int?;
        if (ts != null && _isStale(ts)) return;

        switch (type) {
          case CallMessageType.offer:
            // Принимаем offer и отправляем answer (только если уже в звонке)
            if (_inCall && _peerConnection != null) {
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(data['sdp'] as String, data['sdpType'] as String),
              );
              final answer = await _peerConnection!.createAnswer();
              await _peerConnection!.setLocalDescription(answer);
              _sendSignal(callId, {
                'type': CallMessageType.answer.index,
                'sdp': answer.sdp,
                'sdpType': answer.type,
                'userId': _client.auth.currentUser!.id,
                'ts': DateTime.now().millisecondsSinceEpoch,
              });
            }
            break;

          case CallMessageType.answer:
            _answerReceived = true;
            _noAnswerTimer?.cancel();
            if (_peerConnection != null) {
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(data['sdp'] as String, data['sdpType'] as String),
              );
            }
            break;

          case CallMessageType.iceCandidate:
            if (_peerConnection != null && data['candidate'] != null) {
              await _peerConnection!.addCandidate(
                RTCIceCandidate(
                  data['candidate'] as String,
                  data['sdpMid'] as String?,
                  data['sdpMLineIndex'] as int?,
                ),
              );
            }
            break;

          case CallMessageType.hangUp:
          case CallMessageType.reject:
            await _cleanup();
            break;
        }
      },
    );

    _channel!.subscribe();
  }

  bool _isStale(int timestampMs) {
    final age = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - timestampMs);
    return age > _kMaxSignalAge;
  }

  void _startCallTimer() {
    _callTimeout?.cancel();
    _callTimeout = Timer(_kMaxCallDuration, () {
      hangUp();
    });
  }

  void _sendSignal(String callId, Map<String, dynamic> data) {
    final ch = _channel;
    if (ch != null) {
      ch.sendBroadcastMessage(event: 'signal', payload: data);
    } else {
      _client.channel('call:$callId').sendBroadcastMessage(
            event: 'signal',
            payload: data,
          );
    }
  }

  Future<void> _cleanup() async {
    _callTimeout?.cancel();
    _callTimeout = null;
    _noAnswerTimer?.cancel();
    _noAnswerTimer = null;
    _answerReceived = false;
    _iceRestartAttempted = false;
    _knownParticipants = null;
    _inCall = false;
    _currentCallId = null;

    try {
      _localStream?.getTracks().forEach((t) => t.stop());
      _remoteStream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}

    await _peerConnection?.close();
    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    await _channel?.unsubscribe();
    _channel = null;
  }

  Future<void> _attemptIceRestart() async {
    try {
      if (_peerConnection == null) return;
      final offer = await _peerConnection!.createOffer({
        'iceRestart': true,
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _peerConnection!.setLocalDescription(offer);
      if (_currentCallId != null) {
        _sendSignal(_currentCallId!, {
          'type': CallMessageType.offer.index,
          'sdp': offer.sdp,
          'sdpType': offer.type,
          'callerId': _client.auth.currentUser!.id,
          'video': true,
          'ts': DateTime.now().millisecondsSinceEpoch,
          'iceRestart': true,
        });
      }
    } catch (_) {
      hangUp();
    }
  }
}
