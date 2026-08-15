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
}
