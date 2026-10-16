import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/social_controller.dart';

void main() {
  test(
    'saved account restores chat activity photo and username after logout',
    () async {
      String? saved;
      final c = SocialController(newAccount: true);
      c.persist = (value) async {
        saved = value;
      };
      c.claimUsername('my_username');
      c.requestFriend('ayesha');
      c.switchProfile('ayesha');
      c.respondToFriendRequest(c.pendingIncoming.single.id, true);
      c.switchProfile('hammad');
      c.sendMessage('ayesha', 'Saved message');
      c.favorite('ayesha');
      c.switchProfile('ayesha');
      c.respondToSosRequest('hammad', true);
      c.switchProfile('hammad');
      c.finishSos(c.createSos().id, cancelled: false);
      c.setPhoto('photo-bytes');
      c.setSignedIn(true);
      c.setSignedIn(false);
      await c.flush();
      final restored = SocialController.fromSnapshot(saved!);
      expect(restored.signedIn, isFalse);
      restored.setSignedIn(true);
      expect(restored.currentUser.username, 'my_username');
      expect(restored.photoFor('hammad'), 'photo-bytes');
      expect(restored.messagesWith('ayesha').single.text, 'Saved message');
      expect(restored.visibleEvents.single.status, LocalSosStatus.resolved);
      expect(restored.eligibleRecipients.single.id, 'ayesha');
      restored.switchProfile('sara');
      expect(restored.photoFor('sara'), isNull);
      expect(restored.visibleEvents, isEmpty);
      c.dispose();
      restored.dispose();
    },
  );

  test('failed saves are surfaced and retry writes the latest state', () async {
    final c = SocialController();
    c.persist = (_) async => throw StateError('disk full');
    c.setSignedIn(true);
    await expectLater(c.flush(), throwsStateError);
    expect(c.saveError, isNotNull);
    String? saved;
    c.persist = (value) async {
      saved = value;
    };
    c.retrySave();
    await c.flush();
    expect(c.saveError, isNull);
    expect(SocialController.fromSnapshot(saved!).signedIn, isTrue);
    c.dispose();
  });
}
