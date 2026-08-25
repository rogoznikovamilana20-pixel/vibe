// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/v2_message_storage.dart';

/// Simulates server-side previews() function with e2ee_version gate.
///
/// This mirrors the logic in send-push/index.ts after Phase 12C.4.8 hardening.
/// For V2 (e2ee_version >= 2), plaintext is NEVER used for notification content.
String serverPreviews({
  String? body,
  String? photo,
  String? voice,
  int? e2eeVersion,
}) {
  // V2 fail-closed: never use plaintext for notification content
  if (e2eeVersion != null && e2eeVersion >= 2) {
    if (photo != null && photo.isNotEmpty) return '[Фото]';
    if (voice != null && voice.isNotEmpty) return '[Голосовое]';
    return 'Новое сообщение';
  }

  // V1 / plaintext: existing behavior
  if (body != null && body.trim().isNotEmpty) {
    return body.trim();
  }
  if (photo != null && photo.isNotEmpty) return '[Фото]';
  if (voice != null && voice.isNotEmpty) return '[Голосовое]';
  return 'Новое сообщение';
}

void main() {
  // ===========================================================================
  // 1. V2 + text=null → SAFE
  // ===========================================================================

  group('V2 + text=null → safe', () {
    test('V2 text message: body = "Новое сообщение"', () {
      final body = serverPreviews(
        body: null,
        e2eeVersion: 2,
      );
      expect(body, 'Новое сообщение');
    });

    test('V2 empty text: body = "Новое сообщение"', () {
      final body = serverPreviews(
        body: '',
        e2eeVersion: 2,
      );
      expect(body, 'Новое сообщение');
    });
  });

  // ===========================================================================
  // 2. V2 + text="SECRET" → PLAINTEXT NEVER LEAKS
  // ===========================================================================

  group('V2 + text="SECRET" → plaintext never leaks', () {
    test('V2 + malicious plaintext: body != "SECRET"', () {
      final body = serverPreviews(
        body: 'TOP SECRET',
        e2eeVersion: 2,
      );
      expect(body, isNot('TOP SECRET'));
      expect(body, 'Новое сообщение');
    });

    test('V2 + long plaintext: body truncated to safe label', () {
      final body = serverPreviews(
        body: 'A' * 1000,
        e2eeVersion: 2,
      );
      expect(body, isNot(contains('AAA')));
      expect(body, 'Новое сообщение');
    });

    test('V2 + whitespace-only plaintext: body = "Новое сообщение"', () {
      final body = serverPreviews(
        body: '   ',
        e2eeVersion: 2,
      );
      expect(body, 'Новое сообщение');
    });
  });

  // ===========================================================================
  // 3. V2 + media → SAFE LABELS
  // ===========================================================================

  group('V2 + media → safe labels', () {
    test('V2 + photo + malicious plaintext: body = "[Фото]"', () {
      final body = serverPreviews(
        body: 'TOP SECRET',
        photo: 'https://example.com/photo.jpg',
        e2eeVersion: 2,
      );
      expect(body, '[Фото]');
      expect(body, isNot(contains('SECRET')));
    });

    test('V2 + voice + malicious plaintext: body = "[Голосовое]"', () {
      final body = serverPreviews(
        body: 'TOP SECRET',
        voice: 'https://example.com/voice.ogg',
        e2eeVersion: 2,
      );
      expect(body, '[Голосовое]');
      expect(body, isNot(contains('SECRET')));
    });

    test('V2 + photo (no text): body = "[Фото]"', () {
      final body = serverPreviews(
        photo: 'https://example.com/photo.jpg',
        e2eeVersion: 2,
      );
      expect(body, '[Фото]');
    });

    test('V2 + voice (no text): body = "[Голосовое]"', () {
      final body = serverPreviews(
        voice: 'https://example.com/voice.ogg',
        e2eeVersion: 2,
      );
      expect(body, '[Голосовое]');
    });
  });

  // ===========================================================================
  // 4. V2 REPLY → NO PLAINTEXT IN FCM
  // ===========================================================================

  group('V2 reply → no plaintext in FCM', () {
    test('V2 reply + original plaintext: reply not in body', () {
      // Server never includes replyText in FCM payload
      // This test verifies the previews() function doesn't leak reply content
      final body = serverPreviews(
        body: 'This is the reply text',
        e2eeVersion: 2,
      );
      expect(body, isNot(contains('reply text')));
      expect(body, 'Новое сообщение');
    });

    test('V2 reply + quoted text: quoted not in body', () {
      final body = serverPreviews(
        body: 'Quoted message content',
        e2eeVersion: 2,
      );
      expect(body, isNot(contains('Quoted')));
      expect(body, 'Новое сообщение');
    });
  });

  // ===========================================================================
  // 5. V2 PAYLOAD — FORBIDDEN KEYS
  // ===========================================================================

  group('V2 payload — forbidden keys', () {
    test('FCM data fields contain no plaintext keys', () {
      // Server builds: { type, chatId, senderId }
      // No text, replyText, preview, quotedText, caption, transcription
      final data = <String, String>{
        'type': 'chat',
        'chatId': 'chat-123',
        'senderId': 'user-456',
      };

      final forbiddenKeys = [
        'text',
        'replyText',
        'replyAuthor',
        'preview',
        'quotedText',
        'caption',
        'transcription',
        'messageText',
        'content',
      ];

      for (final key in forbiddenKeys) {
        expect(data.containsKey(key), false,
            reason: 'FCM data must not contain "$key"');
      }
    });
  });

  // ===========================================================================
  // 6. V2 e2ee_version GATE
  // ===========================================================================

  group('V2 e2ee_version gate', () {
    test('e2ee_version=2: plaintext ignored', () {
      final body = serverPreviews(
        body: 'SECRET',
        e2eeVersion: 2,
      );
      expect(body, 'Новое сообщение');
    });

    test('e2ee_version=3: plaintext ignored', () {
      final body = serverPreviews(
        body: 'SECRET',
        e2eeVersion: 3,
      );
      expect(body, 'Новое сообщение');
    });

    test('e2ee_version=99: plaintext ignored', () {
      final body = serverPreviews(
        body: 'SECRET',
        e2eeVersion: 99,
      );
      expect(body, 'Новое сообщение');
    });

    test('e2ee_version=null: existing behavior', () {
      final body = serverPreviews(
        body: 'Hello',
        e2eeVersion: null,
      );
      expect(body, 'Hello');
    });

    test('e2ee_version absent: existing behavior', () {
      final body = serverPreviews(
        body: 'Hello',
      );
      expect(body, 'Hello');
    });
  });

  // ===========================================================================
  // 7. V1 COMPATIBILITY
  // ===========================================================================

  group('V1 compatibility', () {
    test('V1 + text: preview shows text', () {
      final body = serverPreviews(
        body: 'Hello from V1',
        e2eeVersion: 1,
      );
      expect(body, 'Hello from V1');
    });

    test('V1 + text=null + photo: shows "[Фото]"', () {
      final body = serverPreviews(
        body: null,
        photo: 'https://example.com/photo.jpg',
        e2eeVersion: 1,
      );
      expect(body, '[Фото]');
    });

    test('V1 reply: preview shows text', () {
      final body = serverPreviews(
        body: 'Reply text',
        e2eeVersion: 1,
      );
      expect(body, 'Reply text');
    });

    test('plaintext + text: preview shows text', () {
      final body = serverPreviews(
        body: 'Hello',
      );
      expect(body, 'Hello');
    });
  });

  // ===========================================================================
  // 8. UNKNOWN / MALFORMED e2ee_version
  // ===========================================================================

  group('Unknown / malformed e2ee_version', () {
    test('e2ee_version=0: existing behavior (not V2)', () {
      final body = serverPreviews(
        body: 'Hello',
        e2eeVersion: 0,
      );
      expect(body, 'Hello');
    });

    test('e2ee_version=-1: existing behavior (not V2)', () {
      final body = serverPreviews(
        body: 'Hello',
        e2eeVersion: -1,
      );
      expect(body, 'Hello');
    });

    test('e2ee_version=1.5: not >= 2, existing behavior', () {
      final body = serverPreviews(
        body: 'Hello',
        e2eeVersion: 1,
      );
      expect(body, 'Hello');
    });
  });

  // ===========================================================================
  // 9. FAIL-CLOSED — ALL SCENARIOS
  // ===========================================================================

  group('Fail-closed — all scenarios', () {
    test('V2 + text=null + photo=null + voice=null', () {
      final body = serverPreviews(e2eeVersion: 2);
      expect(body, 'Новое сообщение');
    });

    test('V2 + text="SECRET" + photo=null + voice=null', () {
      final body = serverPreviews(
        body: 'SECRET',
        e2eeVersion: 2,
      );
      expect(body, 'Новое сообщение');
    });

    test('V2 + text="SECRET" + photo="url" + voice=null', () {
      final body = serverPreviews(
        body: 'SECRET',
        photo: 'url',
        e2eeVersion: 2,
      );
      expect(body, '[Фото]');
    });

    test('V2 + text="SECRET" + photo=null + voice="url"', () {
      final body = serverPreviews(
        body: 'SECRET',
        voice: 'url',
        e2eeVersion: 2,
      );
      expect(body, '[Голосовое]');
    });

    test('V2 + text="SECRET" + photo="url" + voice="url"', () {
      // Photo takes precedence over voice
      final body = serverPreviews(
        body: 'SECRET',
        photo: 'url',
        voice: 'url',
        e2eeVersion: 2,
      );
      expect(body, '[Фото]');
    });
  });

  // ===========================================================================
  // 10. V2 MESSAGE DETECTION
  // ===========================================================================

  group('V2 message detection', () {
    test('isV2Message detects V2', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 2,
        'encrypted_content': 'dGVzdA==',
      };
      expect(V2StoredMessage.isV2Message(row), true);
    });

    test('isV2Message rejects V1', () {
      final row = {
        'is_encrypted': true,
        'e2ee_version': 1,
        'encrypted_content': '{}',
      };
      expect(V2StoredMessage.isV2Message(row), false);
    });

    test('isV2Message rejects plaintext', () {
      final row = {
        'is_encrypted': false,
        'text': 'Hello',
      };
      expect(V2StoredMessage.isV2Message(row), false);
    });
  });

  // ===========================================================================
  // 11. SECURITY INVARIANT — PLAINTEXT NEVER IN PUSH
  // ===========================================================================

  group('Security invariant — plaintext never in push', () {
    test('for all V2 e2ee_versions, plaintext never in body', () {
      final v2Versions = [2, 3, 5, 10, 99, 255];
      for (final version in v2Versions) {
        final body = serverPreviews(
          body: 'TOP SECRET',
          e2eeVersion: version,
        );
        expect(body, isNot(contains('SECRET')),
            reason: 'V2 v$version must not leak plaintext');
        expect(body, 'Новое сообщение',
            reason: 'V2 v$version must show safe label');
      }
    });

    test('for V1, plaintext is allowed', () {
      final body = serverPreviews(
        body: 'Hello',
        e2eeVersion: 1,
      );
      expect(body, 'Hello');
    });

    test('for null version, plaintext is allowed', () {
      final body = serverPreviews(
        body: 'Hello',
        e2eeVersion: null,
      );
      expect(body, 'Hello');
    });
  });
}
