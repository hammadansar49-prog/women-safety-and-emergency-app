import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/social_controller.dart';

void main() {
  test('a stale cloud response cannot replace the next account graph', () {
    final social = SocialController(newAccount: true);
    addTearDown(social.dispose);
    social.enterAccount(
      'zz_phone_1022',
      null,
      name: 'Phone',
      username: 'zz_phone_1022',
    );
    social.applyCloudGraph(
      mine: 'zz_phone_1022',
      reqs: [(from: 'zz_eve_1', to: 'zz_phone_1022', status: 'pending')],
      links: [],
      names: {},
    );
    social.applyCloudGraph(
      mine: 'zz_eve_1',
      reqs: [(from: 'zz_eve_1', to: 'zz_phone_1022', status: 'pending')],
      links: [],
      names: {},
    );
    expect(social.pendingOutgoing, isEmpty);
    expect(social.pendingIncoming.single.fromId, 'zz_eve_1');
  });

  test('a snapshot owned by another username is rejected before switching', () {
    final social = SocialController(newAccount: true);
    addTearDown(social.dispose);
    social.enterAccount('zz_eve_1', null, name: 'EVE', username: 'zz_eve_1');
    final wrongSnapshot = social.snapshot();
    expect(
      () => social.enterAccount(
        'zz_phone_1022',
        wrongSnapshot,
        name: 'Phone',
        username: 'zz_phone_1022',
      ),
      throwsFormatException,
    );
    expect(social.currentUser.username, 'zz_eve_1');
  });

  test('switching accounts detaches the previous cloud writer immediately', () {
    final social = SocialController(newAccount: true);
    addTearDown(social.dispose);
    social.enterAccount('zz_eve_1', null, name: 'EVE', username: 'zz_eve_1');
    final sent = <CloudOp>[];
    social.onCloudOp = sent.add;
    social.enterAccount(
      'zz_phone_1022',
      null,
      name: 'Phone',
      username: 'zz_phone_1022',
    );
    social.adoptRemote('someone_else', 'someone_else');
    social.requestFriend('someone_else');
    expect(sent, isEmpty);
  });

  test('a second account never sees the first account data', () async {
    final store = <String, String>{};
    final social = SocialController(newAccount: true);
    social.persistAccount = (key, data) async => store[key] = data;

    // Account one: has a PIN, a friend and a message.
    social.enterAccount(
      'first_user',
      null,
      name: 'First',
      username: 'first_user',
    );
    social.setSignedIn(true);
    social.seedDemoFriend('ayesha');
    social.setPin('1234');
    social.sendMessage('ayesha', 'a private message');
    await social.flush();
    expect(store['first_user'], isNotNull);
    expect(store['first_user']!, contains('a private message'));

    // Sign out wipes memory.
    social.signOut();
    expect(social.signedIn, isFalse);
    expect(social.hasPin, isFalse);
    expect(social.currentUser.username, '');
    expect(social.profiles.length, 1);

    // Account two starts blank, with its own name.
    social.enterAccount(
      'second_user',
      store['second_user'],
      name: 'Second',
      username: 'second_user',
    );
    social.setSignedIn(true);
    expect(social.currentUser.name, 'Second');
    expect(social.currentUser.username, 'second_user');
    expect(social.hasPin, isFalse);
    expect(social.profiles.length, 1);
    await social.flush();
    expect(store['second_user']!, isNot(contains('a private message')));

    // Signing back into account one restores everything, PIN included.
    social.signOut();
    social.enterAccount('first_user', store['first_user'], name: '');
    social.setSignedIn(true);
    expect(social.currentUser.username, 'first_user');
    expect(social.hasPin, isTrue);
    expect(social.checkPin('1234'), isTrue);
    expect(social.checkPin('0000'), isFalse);
    expect(
      social.messagesWith('ayesha').map((m) => m.text),
      contains('a private message'),
    );
  });
}
