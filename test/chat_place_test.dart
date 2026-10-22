import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/chat_screen.dart';
import 'package:safeher/location_service.dart';
import 'package:safeher/social_controller.dart';

/// The chat header's orbs drift for ever, so a settle would never finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late SocialController social;
  setUp(() {
    social = SocialController();
    social.requestFriend('ayesha');
    social.switchProfile('ayesha');
    social.respondToFriendRequest(social.pendingIncoming.single.id, true);
    social.switchProfile('hammad');
  });
  tearDown(() => social.dispose());

  Future<void> open(
    WidgetTester tester,
    Future<LocationFix?> Function() locator,
  ) async {
    // The sheet plus the chat needs more height than the default test surface.
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(social: social, friendId: 'ayesha', locator: locator),
      ),
    );
  }

  testWidgets('sharing a place posts a card that opens the maps app', (
    tester,
  ) async {
    await open(
      tester,
      () async => LocationFix(30.2489104, 71.4718808, DateTime.now()),
    );
    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);
    await tester.tap(find.text('My location'));
    await settle(tester);
    await settle(tester);

    expect(social.messagesWith('ayesha').last.isPlace, isTrue);
    expect(find.text('You shared your location'), findsOne);
    expect(find.text('30.24891, 71.47188'), findsOne);
    // The raw payload must never be shown as if it were typed text.
    expect(find.textContaining('safeher:place'), findsNothing);
  });

  testWidgets('a refused position says so and sends nothing', (tester) async {
    final before = social.messagesWith('ayesha').length;
    await open(tester, () async => null);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);
    await tester.tap(find.text('My location'));
    await settle(tester);
    await settle(tester);

    expect(social.messagesWith('ayesha').length, before);
    expect(find.textContaining('Could not find where you are'), findsOne);
  });
}
