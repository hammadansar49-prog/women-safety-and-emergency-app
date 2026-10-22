import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/social_controller.dart';

void main() {
  test(
    'presence and delivery receipts update UI without rewriting account backups',
    () async {
      final social = SocialController(newAccount: true);
      addTearDown(social.dispose);
      var saves = 0;
      var updates = 0;
      social.persistAccount = (_, _) async => saves++;
      social.enterAccount('alice', null, name: 'Alice', username: 'alice');
      await social.flush();
      final before = saves;
      final revision = social.durableRevision;
      social.addListener(() => updates++);
      social.applyPresence(
        'bob',
        Presence(online: true, lastSeen: DateTime.now(), openWith: 'alice'),
      );
      social.applyReceipt(
        'message',
        delivered: DateTime.now(),
        read: DateTime.now(),
      );
      await social.flush();
      expect(updates, greaterThanOrEqualTo(2));
      expect(social.presenceOf('bob').online, true);
      expect(social.statusOf('message'), MessageStatus.read);
      expect(
        saves,
        before,
        reason:
            'ephemeral status must not schedule persistent/cloud backup writes',
      );
      expect(social.durableRevision, revision);
      social.setName('Alice updated');
      await social.flush();
      expect(saves, before + 1);
      expect(social.durableRevision, greaterThan(revision));
    },
  );
}
