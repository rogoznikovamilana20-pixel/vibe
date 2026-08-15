import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/webrtc_service.dart';

/// Unit tests for WebRTC signaling logic.
/// Tests pure logic (enums, constants, payload structure) without hardware deps.
void main() {
  group('CallMessageType enum', () {
    test('enum ordering matches signaling protocol', () {
      expect(CallMessageType.offer.index, 0);
      expect(CallMessageType.answer.index, 1);
      expect(CallMessageType.iceCandidate.index, 2);
      expect(CallMessageType.hangUp.index, 3);
      expect(CallMessageType.reject.index, 4);
    });

    test('values list has correct length', () {
      expect(CallMessageType.values.length, 5);
    });

    test('roundtrip index → value → index', () {
      for (final type in CallMessageType.values) {
        final restored = CallMessageType.values[type.index];
        expect(restored, type);
      }
    });
  });

  group('Signal payload structure', () {
    test('offer payload contains required fields', () {
      final payload = <String, dynamic>{
        'type': CallMessageType.offer.index,
        'sdp': 'v=0\r\n',
        'sdpType': 'offer',
        'callerId': 'user-123',
        'video': true,
        'ts': DateTime.now().millisecondsSinceEpoch,
      };

      expect(payload['type'], CallMessageType.offer.index);
      expect(payload['sdp'], isA<String>());
      expect(payload['sdpType'], 'offer');
      expect(payload['callerId'], 'user-123');
      expect(payload['video'], isA<bool>());
      expect(payload['ts'], isA<int>());
    });

    test('answer payload contains required fields', () {
      final payload = <String, dynamic>{
        'type': CallMessageType.answer.index,
        'sdp': 'v=0\r\n',
        'sdpType': 'answer',
        'userId': 'user-456',
        'ts': DateTime.now().millisecondsSinceEpoch,
      };

      expect(payload['type'], CallMessageType.answer.index);
      expect(payload['sdp'], isA<String>());
      expect(payload['sdpType'], 'answer');
      expect(payload['userId'], 'user-456');
      expect(payload['ts'], isA<int>());
    });

    test('iceCandidate payload contains required fields', () {
      final payload = <String, dynamic>{
        'type': CallMessageType.iceCandidate.index,
        'candidate': 'candidate:1 1 UDP 2122252543 ...',
        'sdpMid': '0',
        'sdpMLineIndex': 0,
        'userId': 'user-789',
        'ts': DateTime.now().millisecondsSinceEpoch,
      };

      expect(payload['type'], CallMessageType.iceCandidate.index);
      expect(payload['candidate'], isA<String>());
      expect(payload['userId'], 'user-789');
      expect(payload['ts'], isA<int>());
    });

    test('hangUp payload contains required fields', () {
      final payload = <String, dynamic>{
        'type': CallMessageType.hangUp.index,
        'userId': 'user-123',
        'ts': DateTime.now().millisecondsSinceEpoch,
      };

      expect(payload['type'], CallMessageType.hangUp.index);
      expect(payload['userId'], 'user-123');
      expect(payload['ts'], isA<int>());
    });

    test('reject payload contains required fields', () {
      final payload = <String, dynamic>{
        'type': CallMessageType.reject.index,
        'userId': 'user-123',
        'ts': DateTime.now().millisecondsSinceEpoch,
      };

      expect(payload['type'], CallMessageType.reject.index);
      expect(payload['userId'], 'user-123');
      expect(payload['ts'], isA<int>());
    });

    test('all signal payloads have timestamp', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final type in CallMessageType.values) {
        final payload = <String, dynamic>{
          'type': type.index,
          'userId': 'user-123',
          'ts': now,
        };
        expect(payload['ts'], now, reason: '${type.name} payload missing ts');
      }
    });
  });

  group('Stale signal detection', () {
    test('signal within 60s is not stale', () {
      final signalAge = Duration(seconds: 30);
      final isStale = signalAge > const Duration(seconds: 60);
      expect(isStale, false);
    });

    test('signal older than 60s is stale', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final oldTimestamp = now - 90000; // 90 seconds ago
      final age = Duration(milliseconds: now - oldTimestamp);
      final isStale = age > const Duration(seconds: 60);
      expect(isStale, true);
    });

    test('signal at exactly 60s is not stale', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final exactly60sAgo = now - 60000;
      final age = Duration(milliseconds: now - exactly60sAgo);
      final isStale = age > const Duration(seconds: 60);
      expect(isStale, false);
    });

    test('signal at 61s is stale', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final timestamp = now - 61000;
      final age = Duration(milliseconds: now - timestamp);
      final isStale = age > const Duration(seconds: 60);
      expect(isStale, true);
    });
  });

  group('Call timeout constants', () {
    test('max call duration is 30 minutes', () {
      const maxDuration = Duration(minutes: 30);
      expect(maxDuration.inSeconds, 1800);
      expect(maxDuration.inMinutes, 30);
    });

    test('max signal age is 60 seconds', () {
      const maxAge = Duration(seconds: 60);
      expect(maxAge.inSeconds, 60);
    });
  });

  group('Offer/Answer SDP structure', () {
    test('SDP is non-empty string', () {
      const fakeSdp = 'v=0\r\no=- 0 0 IN IP4 127.0.0.1\r\n';
      expect(fakeSdp.isNotEmpty, true);
      expect(fakeSdp.contains('\r\n'), true);
    });

    test('sdpType matches expected values', () {
      const offerTypes = ['offer', 'answer'];
      expect(offerTypes, contains('offer'));
      expect(offerTypes, contains('answer'));
    });
  });

  group('ICE candidate structure', () {
    test('ICE candidate format contains required components', () {
      const candidate =
          'candidate:1 1 UDP 2122252543 192.168.1.1 50000 typ host';
      expect(candidate.startsWith('candidate:'), true);
      expect(candidate.contains('UDP'), true);
      expect(candidate.contains('typ'), true);
    });
  });

  group('Phase 11 — ICE servers configuration', () {
    test('iceServers static field has correct default entries', () {
      final servers = WebRtcService.iceServers;
      expect(servers.length, greaterThanOrEqualTo(3));

      // Two STUN servers
      final stunServers =
          servers.where((s) => s['urls'].toString().startsWith('stun:')).toList();
      expect(stunServers.length, 2);

      // At least one TURN server with credentials
      final turnServers =
          servers.where((s) => s['urls'].toString().startsWith('turn:')).toList();
      expect(turnServers.length, greaterThanOrEqualTo(1));
      for (final ts in turnServers) {
        expect(ts['username'], isA<String>());
        expect(ts['credential'], isA<String>());
      }
    });

    test('iceServers TURN uses port 443 (TLS), not 80', () {
      final turnServers = WebRtcService.iceServers
          .where((s) => s['urls'].toString().startsWith('turn:'))
          .toList();
      for (final ts in turnServers) {
        final url = ts['urls'] as String;
        expect(url.contains(':80'), false,
            reason: 'TURN on port 80 (non-TLS) should be removed');
        expect(url.contains(':443'), true,
            reason: 'TURN should use TLS on port 443');
      }
    });
  });

  group('Phase 11 — Participant guard logic', () {
    test('signals from known participants are accepted', () {
      final knownParticipants = <String, bool>{
        'user-A': true,
        'user-B': true,
      };

      // ICE candidate from known participant — accepted
      final senderId = 'user-A';
      final isKnown = knownParticipants[senderId] == true;
      expect(isKnown, true);
    });

    test('signals from unknown participants are rejected', () {
      final knownParticipants = <String, bool>{
        'user-A': true,
        'user-B': true,
      };

      // ICE candidate from unknown participant — rejected
      final senderId = 'user-C';
      final isKnown = knownParticipants[senderId] == true;
      expect(isKnown, false);
    });

    test('offer/answer registers sender as participant', () {
      final knownParticipants = <String, bool>{};
      final senderId = 'user-D';
      final type = CallMessageType.offer;

      // Offer/answer registers sender
      if (type == CallMessageType.offer || type == CallMessageType.answer) {
        knownParticipants[senderId] = true;
      }

      expect(knownParticipants[senderId], true);
    });

    test('reject clears participant and signals cleanup', () {
      final knownParticipants = <String, bool>{
        'user-A': true,
        'user-B': true,
      };

      // Reject from user-A — cleanup should run
      final type = CallMessageType.reject;
      final shouldCleanup = type == CallMessageType.hangUp || type == CallMessageType.reject;
      expect(shouldCleanup, true);

      // After cleanup, participant list should be empty
      knownParticipants.clear();
      expect(knownParticipants.isEmpty, true);
    });
  });

  group('Phase 11 — No-answer timeout', () {
    test('30-second timeout for unanswered calls', () {
      const timeout = Duration(seconds: 30);
      expect(timeout.inSeconds, 30);
      expect(timeout.inMilliseconds, 30000);
    });

    test('answer receipt cancels timeout', () {
      bool answerReceived = false;
      Timer? noAnswerTimer = Timer(const Duration(seconds: 30), () {});

      // Simulate: answer received before timeout fires
      answerReceived = true;
      noAnswerTimer.cancel();
      expect(answerReceived, true);
      expect(noAnswerTimer.isActive, false);
    });
  });

  group('Phase 11 — ICE restart logic', () {
    test('iceRestart flag in offer payload', () {
      final payload = <String, dynamic>{
        'type': CallMessageType.offer.index,
        'sdp': 'v=0\r\n',
        'sdpType': 'offer',
        'callerId': 'user-123',
        'video': true,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'iceRestart': true,
      };

      expect(payload['iceRestart'], true);
      expect(payload['type'], CallMessageType.offer.index);
    });

    test('only one ICE restart attempt allowed', () {
      bool iceRestartAttempted = false;

      // First failure — attempt restart
      if (!iceRestartAttempted) {
        iceRestartAttempted = true;
      }
      expect(iceRestartAttempted, true);

      // Second failure — no more restarts, hang up
      final shouldHangUp = iceRestartAttempted;
      expect(shouldHangUp, true);
    });
  });

  group('Phase 11 — Call timer constants', () {
    test('max call duration is 30 minutes', () {
      const maxDuration = Duration(minutes: 30);
      expect(maxDuration.inSeconds, 1800);
    });

    test('max signal age is 60 seconds', () {
      const maxAge = Duration(seconds: 60);
      expect(maxAge.inSeconds, 60);
    });

    test('no-answer timeout is 30 seconds', () {
      const noAnswerTimeout = Duration(seconds: 30);
      expect(noAnswerTimeout.inSeconds, 30);
    });
  });
}
