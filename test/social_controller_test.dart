import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/social_controller.dart';

void connect(SocialController c, String a, String b) {
  c.switchProfile(a);
  c.requestFriend(b);
  c.switchProfile(b);
  c.respondToFriendRequest(c.pendingIncoming.single.id, true);
  c.switchProfile(a);
}

void approve(SocialController c, String a, String b) {
  c.switchProfile(a);
  c.favorite(b);
  c.switchProfile(b);
  c.respondToSosRequest(a, true);
  c.switchProfile(a);
}

void main() {
  late SocialController c;
  setUp(() => c = SocialController());
  tearDown(() => c.dispose());

  test(
    'profiles, search and returned collections are isolated and immutable',
    () {
      expect(c.currentUserId, 'hammad');
      expect(c.search(' AYE ').single.id, 'ayesha');
      expect(c.search('hammad'), isEmpty);
      expect(c.search(''), isEmpty);
      expect(() => c.profiles.clear(), throwsUnsupportedError);
      expect(() => c.friends.clear(), throwsUnsupportedError);
      expect(() => c.switchProfile('unknown'), throwsStateError);
    },
  );

  test('friend requests require recipient approval and reject duplicates', () {
    expect(() => c.requestFriend('hammad'), throwsStateError);
    expect(() => c.requestFriend('unknown'), throwsStateError);
    c.requestFriend('ayesha');
    final id = c.pendingOutgoing.single.id;
    expect(c.friends, isEmpty);
    expect(() => c.respondToFriendRequest(id, true), throwsStateError);
    expect(() => c.requestFriend('ayesha'), throwsStateError);
    c.switchProfile('ayesha');
    expect(() => c.cancelFriendRequest(id), throwsStateError);
    expect(() => c.requestFriend('hammad'), throwsStateError);
    c.respondToFriendRequest(id, true);
    expect(c.friends.single.id, 'hammad');
    expect(c.areFriends('hammad', 'ayesha'), isTrue);
    expect(() => c.respondToFriendRequest(id, true), throwsStateError);
  });

  test('requests can be rejected and cancelled then requested again', () {
    c.requestFriend('sara');
    c.cancelFriendRequest(c.pendingOutgoing.single.id);
    c.requestFriend('sara');
    c.switchProfile('sara');
    c.respondToFriendRequest(c.pendingIncoming.single.id, false);
    expect(c.friends, isEmpty);
    expect(c.pendingIncoming, isEmpty);
  });

  test(
    'messages require friendship, validate content, and stay in conversation',
    () {
      expect(() => c.sendMessage('ayesha', 'hi'), throwsStateError);
      connect(c, 'hammad', 'ayesha');
      c.sendMessage('ayesha', ' hi ');
      expect(c.messagesWith('ayesha').single.text, 'hi');
      expect(() => c.messagesWith('ayesha').clear(), throwsUnsupportedError);
      expect(() => c.sendMessage('ayesha', '  '), throwsStateError);
      expect(() => c.sendMessage('ayesha', 'x' * 2001), throwsStateError);
      c.switchProfile('sara');
      expect(() => c.messagesWith('ayesha'), throwsStateError);
      c.switchProfile('ayesha');
      expect(c.messagesWith('hammad').single.senderId, 'hammad');
      c.sendMessage('hammad', 'hello');
      expect(c.messagesWith('hammad'), hasLength(2));
      c.removeFriend('hammad');
      expect(() => c.messagesWith('hammad'), throwsStateError);
    },
  );

  test('SOS requires favorite consent and routes only snapshot recipients', () {
    expect(() => c.createSos(), throwsStateError);
    connect(c, 'hammad', 'ayesha');
    connect(c, 'hammad', 'sara');
    c.favorite('ayesha');
    expect(c.isFavorite('ayesha'), isTrue);
    expect(c.isApprovedFavorite('ayesha'), isFalse);
    expect(() => c.createSos(), throwsStateError);
    c.switchProfile('ayesha');
    expect(c.incomingSosRequests.single.senderId, 'hammad');
    c.respondToSosRequest('hammad', true);
    expect(c.approvedSenders.single.id, 'hammad');
    c.switchProfile('hammad');
    final event = c.createSos();
    expect(c.createSos().id, event.id);
    expect(event.recipientIds, ['ayesha']);
    expect(() => event.recipientIds.clear(), throwsUnsupportedError);
    approve(c, 'hammad', 'sara');
    c.switchProfile('sara');
    expect(c.visibleEvents, isEmpty);
    expect(() => c.finishSos(event.id, cancelled: true), throwsStateError);
    c.switchProfile('ayesha');
    expect(c.visibleEvents.single.status, LocalSosStatus.active);
    c.switchProfile('hammad');
    c.finishSos(event.id, cancelled: false);
    c.switchProfile('ayesha');
    expect(c.visibleEvents.single.status, LocalSosStatus.resolved);
  });

  test(
    'revoke, unfavorite and remove friend immediately remove SOS access',
    () {
      connect(c, 'hammad', 'ayesha');
      approve(c, 'hammad', 'ayesha');
      c.createSos();
      c.switchProfile('ayesha');
      c.revokeSosPermission('hammad');
      expect(c.visibleEvents, isEmpty);
      c.switchProfile('hammad');
      expect(c.eligibleRecipients, isEmpty);
      c.unfavorite('ayesha');
      approve(c, 'hammad', 'ayesha');
      c.unfavorite('ayesha');
      c.switchProfile('ayesha');
      expect(c.visibleEvents, isEmpty);
      approve(c, 'hammad', 'ayesha');
      approve(c, 'ayesha', 'hammad');
      c.removeFriend('hammad');
      expect(c.isFavorite('hammad'), isFalse);
      expect(c.visibleEvents, isEmpty);
      c.switchProfile('hammad');
      expect(c.isFavorite('ayesha'), isFalse);
      expect(c.eligibleRecipients, isEmpty);
    },
  );

  test('SOS rejection can be retried and only recipient can grant consent', () {
    expect(() => c.favorite('ayesha'), throwsStateError);
    connect(c, 'hammad', 'ayesha');
    c.favorite('ayesha');
    expect(() => c.respondToSosRequest('ayesha', true), throwsStateError);
    c.switchProfile('ayesha');
    c.respondToSosRequest('hammad', false);
    expect(c.incomingSosRequests, isEmpty);
    c.switchProfile('hammad');
    expect(c.eligibleRecipients, isEmpty);
    approve(c, 'hammad', 'ayesha');
    final active = c.createSos();
    c.finishSos(active.id, cancelled: true);
    expect(active.status, LocalSosStatus.active);
    expect(c.visibleEvents.single.status, LocalSosStatus.cancelled);
    expect(() => c.finishSos(active.id, cancelled: false), throwsStateError);
    expect(c.createSos().id, isNot(active.id));
    expect(() => c.visibleEvents.clear(), throwsUnsupportedError);
  });

  test('switches and successful transitions notify listeners', () {
    var changes = 0;
    c.addListener(() => changes++);
    c.requestFriend('ayesha');
    c.switchProfile('ayesha');
    c.respondToFriendRequest(c.pendingIncoming.single.id, true);
    expect(changes, 3);
    c.switchProfile('ayesha');
    expect(changes, 3);
  });

  test(
    'pending SOS state distinguishes denial and revocation from retries',
    () {
      connect(c, 'hammad', 'ayesha');
      expect(c.hasPendingSosRequest('ayesha'), isFalse);
      c.favorite('ayesha');
      expect(c.hasPendingSosRequest('ayesha'), isTrue);
      c.switchProfile('ayesha');
      c.respondToSosRequest('hammad', false);
      c.switchProfile('hammad');
      expect(c.hasPendingSosRequest('ayesha'), isFalse);
      c.favorite('ayesha');
      expect(c.hasPendingSosRequest('ayesha'), isTrue);
      c.switchProfile('ayesha');
      c.respondToSosRequest('hammad', true);
      c.revokeSosPermission('hammad');
      c.switchProfile('hammad');
      expect(c.hasPendingSosRequest('ayesha'), isFalse);
      c.favorite('ayesha');
      expect(c.hasPendingSosRequest('ayesha'), isTrue);
    },
  );
}
