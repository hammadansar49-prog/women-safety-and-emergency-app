import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/social_controller.dart';

void main() {
  test('a shared place travels as sealed text and reads back as a place', () {
    final social = SocialController();
    addTearDown(social.dispose);
    social.seedDemoFriend('ayesha');
    final sent = <CloudOp>[];
    social.onCloudOp = sent.add;

    social.sendLocation('ayesha', 30.2489104, 71.4718808);

    final message = social.messagesWith('ayesha').last;
    expect(message.isPlace, isTrue);
    expect(message.place!.lat, closeTo(30.24891, 0.00001));
    expect(message.place!.lng, closeTo(71.47188, 0.00001));
    // It must ride the ordinary text path, so the server holds ciphertext of
    // the same shape and no new security rule is needed.
    expect(sent.single.kind, 'message');
    expect(sent.single.text, contains('30.248910'));

    final restored = SocialController.fromSnapshot(social.snapshot());
    addTearDown(restored.dispose);
    expect(restored.messagesWith('ayesha').last.isPlace, isTrue);
  });

  test('ordinary text and malformed payloads are never read as a place', () {
    expect(SharedPlace.parse('meet me at the gate'), isNull);
    expect(SharedPlace.parse('safeher:place '), isNull);
    expect(SharedPlace.parse('safeher:place 30.2'), isNull);
    expect(SharedPlace.parse('safeher:place abc,def'), isNull);
    // Out of range coordinates are a corrupt payload, not a place.
    expect(SharedPlace.parse('safeher:place 91.0,0.0'), isNull);
    expect(SharedPlace.parse('safeher:place 0.0,181.0'), isNull);
    expect(SharedPlace.parse('safeher:place -33.8688,151.2093'), isNotNull);
  });
}
