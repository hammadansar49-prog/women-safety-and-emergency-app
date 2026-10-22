import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/security_screens.dart';
import 'package:safeher/social_controller.dart';

void main() {
  testWidgets('the lock screen header is centred and never overflows', (
    tester,
  ) async {
    final social = SocialController();
    addTearDown(social.dispose);
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: PinLockScreen(social: social, onUnlocked: () {})),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final middle = tester.getSize(find.byType(MaterialApp)).width / 2;
    final parts = {
      'the greeting': find.textContaining('Welcome back'),
      'the prompt': find.textContaining('Enter your PIN'),
      'the lock badge': find.byIcon(Icons.lock_outline_rounded),
    };
    for (final part in parts.entries) {
      expect(
        tester.getCenter(part.value).dx,
        closeTo(middle, 1),
        reason: '${part.key} is off centre',
      );
    }
  });

  testWidgets('a notch inset and a long name still fit the header', (
    tester,
  ) async {
    final social = SocialController();
    addTearDown(social.dispose);
    social.setName('Hammad Ansar Muhammad Abdullah Rehman');
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 54)),
          child: PinLockScreen(social: social, onUnlocked: () {}),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Enter your PIN'), findsOne);
  });
}
