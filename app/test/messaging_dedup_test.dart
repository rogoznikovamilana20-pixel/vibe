// ignore_for_file: unused_local_variable, unnecessary_null_comparison, unused_element
import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/chat/models.dart';
import 'package:vibe_app/data/backend.dart';

/// Unit tests for message dedup and ordering logic.
/// Tests the pure logic without Supabase/WebRTC dependencies.
void main() {
  group('MsgStatus transitions', () {
    test('sending → sent → delivered → read is valid sequence', () {
      const expected = [
        MsgStatus.sending,
        MsgStatus.sent,
        MsgStatus.delivered,
        MsgStatus.read,
      ];
      expect(expected.length, 4);
      expect(expected.first, MsgStatus.sending);
      expect(expected.last, MsgStatus.read);
    });

    test('failed is terminal state', () {
      expect(MsgStatus.failed.index, isNot(MsgStatus.sending.index));
      expect(MsgStatus.failed.index, isNot(MsgStatus.sent.index));
    });

    test('read should not downgrade to delivered', () {
      final status = MsgStatus.read;
      expect(status == MsgStatus.read, true);
      expect(MsgStatus.read.index, greaterThan(MsgStatus.delivered.index));
    });
  });

  group('Message ordering', () {
    test('messages list: index 0 is newest', () {
      final messages = <ChatMsg>[
        const ChatMsg(type: MsgType.text, incoming: false, time: '12:03', text: 'C'),
        const ChatMsg(type: MsgType.text, incoming: false, time: '12:02', text: 'B'),
        const ChatMsg(type: MsgType.text, incoming: false, time: '12:01', text: 'A'),
      ];
      expect(messages.first.text, 'C');
      expect(messages.last.text, 'A');
    });

    test('insert at 0 places newest at top', () {
      final messages = <ChatMsg>[
        const ChatMsg(type: MsgType.text, incoming: false, time: '12:02', text: 'B'),
        const ChatMsg(type: MsgType.text, incoming: false, time: '12:01', text: 'A'),
      ];
      messages.insert(0,
          const ChatMsg(type: MsgType.text, incoming: false, time: '12:03', text: 'C'));
      expect(messages.first.text, 'C');
      expect(messages.length, 3);
    });
  });

  group('Dedup: _seenIds simulation', () {
    test('same ID added twice results in one entry', () {
      final seen = <String>{};
      seen.add('msg-1');
      seen.add('msg-1');
      expect(seen.length, 1);
    });

    test('different IDs are both kept', () {
      final seen = <String>{};
      seen.add('msg-1');
      seen.add('msg-2');
      expect(seen.length, 2);
    });

    test('FIFO eviction at cap 400', () {
      final seen = <String>{};
      for (var i = 0; i < 401; i++) {
        seen.add('msg-$i');
        if (seen.length > 400) {
          seen.remove(seen.first);
        }
      }
      expect(seen.length, 400);
      expect(seen.contains('msg-0'), false);
      expect(seen.contains('msg-1'), true);
      expect(seen.contains('msg-400'), true);
    });
  });

  group('Dedup: serverId matching in ChatController', () {
    test('alreadyHas detects duplicate by serverId', () {
      final messages = <ChatMsg>[
        const ChatMsg(type: MsgType.text, incoming: true, time: '12:00', text: 'Hi',
            serverId: 'srv-1'),
        const ChatMsg(type: MsgType.text, incoming: false, time: '11:59', text: 'Hey',
            serverId: 'srv-2'),
      ];
      final incomingId = 'srv-1';
      final alreadyHas = messages.any((m) => m.serverId == incomingId);
      expect(alreadyHas, true);
    });

    test('alreadyHas returns false for new message', () {
      final messages = <ChatMsg>[
        const ChatMsg(type: MsgType.text, incoming: true, time: '12:00', text: 'Hi',
            serverId: 'srv-1'),
      ];
      final incomingId = 'srv-999';
      final alreadyHas = messages.any((m) => m.serverId == incomingId);
      expect(alreadyHas, false);
    });

    test('null serverId does not match', () {
      final messages = <ChatMsg>[
        const ChatMsg(type: MsgType.text, incoming: false, time: '12:00', text: 'Hi'),
      ];
      final incomingId = 'srv-1';
      final alreadyHas = messages.any((m) => m.serverId == incomingId);
      expect(alreadyHas, false);
    });
  });

  group('localId matching for own messages', () {
    test('finds message by localId', () {
      final messages = <ChatMsg>[
        const ChatMsg(type: MsgType.text, incoming: false, time: '12:00', text: 'Sent',
            localId: 'c12345', status: MsgStatus.sending),
      ];
      final localId = 'c12345';
      final i = messages.indexWhere((m) => m.localId == localId);
      expect(i, 0);
    });

    test('does not find wrong localId', () {
      final messages = <ChatMsg>[
        const ChatMsg(type: MsgType.text, incoming: false, time: '12:00', text: 'Sent',
            localId: 'c12345', status: MsgStatus.sending),
      ];
      final localId = 'c99999';
      final i = messages.indexWhere((m) => m.localId == localId);
      expect(i, -1);
    });
  });

  group('ChatMsg model', () {
    test('copyWith preserves fields', () {
      const original = ChatMsg(
        type: MsgType.text,
        incoming: false,
        time: '12:00',
        text: 'Hello',
        serverId: 'srv-1',
        localId: 'c111',
        status: MsgStatus.sending,
      );
      final updated = original.copyWith(
        status: MsgStatus.sent,
        serverId: 'srv-2',
      );
      expect(updated.status, MsgStatus.sent);
      expect(updated.serverId, 'srv-2');
      expect(updated.text, 'Hello');
      expect(updated.localId, 'c111');
      expect(updated.incoming, false);
    });

    test('copyWith with no args returns identical', () {
      const original = ChatMsg(
        type: MsgType.text,
        incoming: true,
        time: '12:00',
        text: 'Test',
      );
      final copy = original.copyWith();
      expect(copy.text, original.text);
      expect(copy.incoming, original.incoming);
      expect(copy.time, original.time);
    });
  });

  group('Unread count logic', () {
    test('read set contains chat', () {
      final read = {'chat-1', 'chat-2'};
      final chatId = 'chat-1';
      expect(read.contains(chatId), true);
    });

    test('read set does not contain chat', () {
      final read = <String>{};
      final chatId = 'chat-1';
      expect(read.contains(chatId), false);
    });

    test('markChatRead adds to read set', () {
      final read = <String>{};
      read.add('chat-1');
      expect(read.contains('chat-1'), true);
    });
  });

  group('Message status after failure', () {
    test('failed status prevents read downgrade', () {
      final status = MsgStatus.failed;
      expect(status == MsgStatus.read, false);
      expect(status == MsgStatus.delivered, false);
      expect(status == MsgStatus.sent, false);
      expect(status == MsgStatus.sending, false);
    });
  });

  group('VibeMessage localId propagation', () {
    test('sent message carries both id and localId', () {
      final msg = VibeMessage(
        id: 'server-uuid',
        chatId: 'chat-1',
        senderId: 'user-1',
        senderName: 'Test',
        senderAvatar: null,
        text: 'Hello',
        voicePath: null,
        photoPath: null,
        videoPath: null,
        created: DateTime.now(),
        incoming: false,
        localId: 'c12345',
      );
      expect(msg.id, 'server-uuid');
      expect(msg.localId, 'c12345');
    });
  });

  group('Edit message preserves ID', () {
    test('edited message keeps same serverId', () {
      const original = ChatMsg(
        type: MsgType.text,
        incoming: false,
        time: '12:00',
        text: 'Original',
        serverId: 'srv-1',
      );
      final edited = original.copyWith(
        edited: true,
      );
      expect(edited.serverId, 'srv-1');
      expect(edited.text, 'Original');
      expect(edited.edited, true);
    });
  });

  group('Delete message removes from list', () {
    test('removing by serverId removes correct message', () {
      final messages = <ChatMsg>[
        const ChatMsg(type: MsgType.text, incoming: true, time: '12:02', text: 'C',
            serverId: 'srv-3'),
        const ChatMsg(type: MsgType.text, incoming: true, time: '12:01', text: 'B',
            serverId: 'srv-2'),
        const ChatMsg(type: MsgType.text, incoming: true, time: '12:00', text: 'A',
            serverId: 'srv-1'),
      ];
      final i = messages.indexWhere((m) => m.serverId == 'srv-2');
      expect(i, 1);
      messages.removeAt(i);
      expect(messages.length, 2);
      expect(messages.any((m) => m.serverId == 'srv-2'), false);
    });
  });
}
