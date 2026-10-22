import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/main.dart';
import 'package:safeher/social_controller.dart';

/// The headers drift for ever, so a settle would never finish.
Future<void> settle(WidgetTester tester, [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 600));
  }
}

/// Signs a new account up the way a person would, then walks the one-time
/// guide, so the test ends on Home.
Future<void> signUp(WidgetTester tester, {required String username}) async {
  await tester.tap(find.text('Create account'));
  await settle(tester);
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Hammad Tester');
  await tester.enterText(fields.at(1), '$username@example.com');
  await tester.enterText(fields.at(2), username);
  await tester.enterText(fields.at(3), 'Secret-12345');
  await settle(tester);
  await tester.tap(find.text('Create account').last);
  await settle(tester, 6);
  // The guide: two Next steps, then it hands over.
  for (var i = 0; i < 2; i++) {
    await tester.tap(find.text('Next'));
    await settle(tester, 2);
  }
  await tester.tap(find.text('Get started'));
  await settle(tester, 3);
}

void main() {
  testWidgets('a fresh install opens on sign in, with a way to join', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const SafeHerApp(localPreview: true));
    await settle(tester);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Create account'), findsWidgets);
  });

  testWidgets('signing up reaches the SOS slider, which says it is not armed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final social = SocialController();
    addTearDown(social.dispose);

    await tester.pumpWidget(SafeHerApp(social: social, localPreview: true));
    await settle(tester);
    await signUp(tester, username: 'hammadq');

    expect(social.signedIn, isTrue);
    expect(social.eligibleRecipients, isEmpty);
    // Nobody has approved yet, so the slider must not look ready to fire.
    expect(find.text('Add an SOS buddy first'), findsOneWidget);
    expect(find.text('Slide to send alert'), findsNothing);
  });

}
