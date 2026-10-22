import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/presence_channel.dart';
import 'package:safeher/social_controller.dart';

void main() {
  group('reading a stored presence record', () {
    test('an online record carries what the chat header needs', () {
      final state = RtdbPresence.readSnapshot({
        'online': true,
        'at': 1700000000000,
        'typing': true,
        'openWith': 'ayesha',
      });
      expect(state.online, isTrue);
      expect(state.typing, isTrue);
      expect(state.openWith, 'ayesha');
      expect(state.lastSeen, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    });

    test('typing never survives going offline', () {
      // The server writes {online: false} on a dropped connection without
      // touching the other fields, so a stale "typing" can arrive with it.
      final state = RtdbPresence.readSnapshot({
        'online': false,
        'at': 1700000000000,
        'typing': true,
      });
      expect(state.online, isFalse);
      expect(state.typing, isFalse);
    });

    test('a missing or malformed record reads as plainly offline', () {
      for (final value in [null, 'nonsense', 42, <String, Object?>{}]) {
        final state = RtdbPresence.readSnapshot(value);
        expect(state.online, isFalse);
        expect(state.typing, isFalse);
        expect(state.lastSeen, isNull);
      }
    });
  });

  group('local expiry', () {
    SocialController withPresence(Presence p) {
      final social = SocialController();
      addTearDown(social.dispose);
      social.applyPresence('ayesha', p);
      return social;
    }

    test('a stuck "typing" clears itself', () {
      final at = DateTime(2026, 1, 1, 12);
      final social = withPresence(
        Presence(online: true, typing: true, lastSeen: at),
      );
      social.expireTyping(at.add(const Duration(seconds: 6)));
      expect(social.presenceOf('ayesha').typing, isFalse);
      // Only the typing hint goes: the store, not a timer, decides online.
      expect(social.presenceOf('ayesha').online, isTrue);
    });

    test('online is never expired locally, however long it has been quiet', () {
      final at = DateTime(2026, 1, 1, 12);
      final social = withPresence(
        Presence(online: true, openWith: 'me', lastSeen: at),
      );
      // Without a heartbeat there is nothing to go stale. Expiring this would
      // show a buddy as offline purely for not having changed state.
      social.expireTyping(at.add(const Duration(hours: 3)));
      expect(social.presenceOf('ayesha').online, isTrue);
      expect(social.presenceOf('ayesha').openWith, 'me');
    });
  });
}
