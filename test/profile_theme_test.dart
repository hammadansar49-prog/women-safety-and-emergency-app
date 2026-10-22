import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/main.dart';
import 'package:safeher/social_controller.dart';

import 'widget_test.dart' show settle, signUp;

/// Signs up and opens Settings.
Future<SocialController> openSettings(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final social = SocialController();
  addTearDown(social.dispose);
  await tester.pumpWidget(SafeHerApp(social: social, localPreview: true));
  await settle(tester);
  await signUp(tester, username: 'hammadq');
  await tester.tap(find.text('Settings').last);
  await settle(tester, 4);
  return social;
}

void main() {
  testWidgets('appearance can be chosen, and the choice takes effect', (
    tester,
  ) async {
    await openSettings(tester);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await settle(tester, 2);
    expect(
      Theme.of(tester.element(find.text('APPEARANCE'))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.text('Light'));
    await settle(tester, 2);
    expect(
      Theme.of(tester.element(find.text('APPEARANCE'))).brightness,
      Brightness.light,
    );
  });

  testWidgets('signing out asks first, and staying keeps the account', (
    tester,
  ) async {
    final social = await openSettings(tester);
    expect(social.signedIn, isTrue);

    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await settle(tester, 2);

    // Signing out cannot be undone on this device, so it is never one tap.
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await settle(tester, 2);
    expect(social.signedIn, isTrue);
    expect(find.text('Sign out?'), findsNothing);
  });

  testWidgets('settings no longer claims calling is unavailable', (
    tester,
  ) async {
    await openSettings(tester);
    expect(find.textContaining('not available yet'), findsNothing);
    expect(find.textContaining('video calls'), findsOneWidget);
  });
}
