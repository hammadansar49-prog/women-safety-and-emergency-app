import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/social_controller.dart';

void main() {
  test('new accounts claim normalized usernames and become searchable', () {
    final social = SocialController(newAccount: true);
    addTearDown(social.dispose);
    expect(social.currentUser.username, isEmpty);
    social.claimUsername('  MeetHamad  ');
    expect(social.currentUser.username, 'meethamad');
    social.switchProfile('ayesha');
    expect(social.search('@MEETHAMAD').single.id, 'hammad');
    social.requestFriend(social.search('meethamad').single.id);
    social.switchProfile('hammad');
    expect(social.pendingIncoming.single.fromId, 'ayesha');
    expect(() => social.claimUsername('different'), throwsStateError);
  });

  test('duplicate and invalid usernames cannot be claimed', () {
    final social = SocialController(newAccount: true);
    addTearDown(social.dispose);
    for (final value in [
      ' AYESHA ',
      'sara',
      '',
      'ab',
      'has space',
      'with.dot',
      'abcdefghijklmnopqrstuvwxyz',
      'نام',
    ]) {
      expect(() => social.claimUsername(value), throwsStateError);
      expect(social.currentUser.username, isEmpty);
    }
    social.claimUsername('meethamad_49');
    expect(social.currentUser.username, 'meethamad_49');
  });
}
