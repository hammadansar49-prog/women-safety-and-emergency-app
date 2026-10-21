import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/social_controller.dart';
void main() {
 test('authenticated account starts with only its UID and no demo records', () {
  final a = SocialController.authenticated(uid: 'alice', name: 'Alice');
  final b = SocialController.authenticated(uid: 'bob', name: 'Bob');
  expect(a.currentUserId, 'alice');
  expect(a.profiles.map((p) => p.id), ['alice']);
  expect(a.friends, isEmpty);
  expect(a.visibleEvents, isEmpty);
  expect(b.search('alice'), isEmpty);
  expect(() => a.switchProfile('bob'), throwsStateError);
 });
}
