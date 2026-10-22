import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/contacts_screen.dart';
import 'package:safeher/social_controller.dart';

void main() {
  testWidgets(
    'Requests opens empty and receives a live request that can be accepted',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final social = SocialController();
      addTearDown(social.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ContactsScreen(social: social)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Requests'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('No new requests'), findsOneWidget);
      social.applyCloudGraph(
        mine: social.currentUser.username,
        reqs: [
          (
            from: 'zz_eve_1',
            to: social.currentUser.username,
            status: 'pending',
          ),
        ],
        links: [],
        names: {'zz_eve_1': 'EVE Testing Agent'},
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('@zz_eve_1'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(social.pendingIncoming, isEmpty);
      expect(social.friends.single.username, 'zz_eve_1');
      expect(find.text('No new requests'), findsOneWidget);
    },
  );

  testWidgets('Requests count updates and declining removes only the request', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final social = SocialController();
    addTearDown(social.dispose);
    social.applyCloudGraph(
      mine: social.currentUser.username,
      reqs: [
        (from: 'zz_eve_1', to: social.currentUser.username, status: 'pending'),
      ],
      links: [],
      names: {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ContactsScreen(social: social)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Requests (1)'), findsOneWidget);
    expect(find.text('@zz_eve_1'), findsNothing);
    await tester.tap(find.text('Requests (1)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Decline'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(social.pendingIncoming, isEmpty);
    expect(social.friends, isEmpty);
    expect(find.text('No new requests'), findsOneWidget);
  });
}
