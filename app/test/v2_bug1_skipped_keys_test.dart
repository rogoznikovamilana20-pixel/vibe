import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/data/v2_ratchet.dart';

/// Bug #1: Skipped keys cleared during DH ratchet step.
///
/// VERIFIED FIX: dhRatchetStep now preserves skippedKeys from the old chain,
/// allowing out-of-order messages to be decrypted after a ratchet step.
void main() {
  group('Bug #1: Skipped keys preservation', () {
    test('dhRatchetStep preserves skippedKeys from old chain', () async {
      var state = V2RatchetState(
        sessionId: 'test',
        rootKey: List<int>.generate(32, (i) => i),
        receivingChainKey: List<int>.generate(32, (i) => i + 50),
        receivingMessageNumber: 5,
        skippedKeys: {
          3: List<int>.generate(32, (i) => i + 200),
          4: List<int>.generate(32, (i) => i + 210),
        },
      );

      final remoteKey = List<int>.generate(32, (i) => i + 300);

      state = await V2Ratchet.dhRatchetStep(state, remoteKey);

      // FIX VERIFIED: skippedKeys is preserved across ratchet step
      expect(state.skippedKeys.length, 2,
          reason: 'skippedKeys preserved across ratchet step');
      expect(state.skippedKeys.containsKey(3), isTrue);
      expect(state.skippedKeys.containsKey(4), isTrue);
    });

    test('ratchet step resets counters but keeps old message keys', () async {
      var state = V2RatchetState(
        sessionId: 'test',
        rootKey: List<int>.generate(32, (i) => i),
        receivingChainKey: List<int>.generate(32, (i) => i + 50),
        receivingMessageNumber: 10,
        sendingMessageNumber: 7,
        previousSendingChainLength: 5,
        skippedKeys: {
          8: List<int>.generate(32, (i) => i + 100),
          9: List<int>.generate(32, (i) => i + 110),
        },
      );

      final remoteKey = List<int>.generate(32, (i) => i + 300);

      state = await V2Ratchet.dhRatchetStep(state, remoteKey);

      // Counters are reset
      expect(state.sendingMessageNumber, 0);
      expect(state.receivingMessageNumber, 0);
      expect(state.previousSendingChainLength, 7); // was sendingMessageNumber

      // But skippedKeys are preserved
      expect(state.skippedKeys.length, 2);
      expect(state.skippedKeys.containsKey(8), isTrue);
      expect(state.skippedKeys.containsKey(9), isTrue);

      // Ratchet step incremented
      expect(state.ratchetStep, 1);
    });
  });
}
