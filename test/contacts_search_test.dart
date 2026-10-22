import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/auth_service.dart';
import 'package:safeher/contacts_screen.dart';
import 'package:safeher/main.dart';
import 'package:safeher/social_controller.dart';

void main() {
  testWidgets(
    'app sync notifications preserve the active search and controller',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final social = SocialController(newAccount: true);
      addTearDown(social.dispose);
      social.enterAccount(
        'testing1',
        null,
        name: 'Testing',
        username: 'testing1',
      );
      social.setSignedIn(true);
      social.markGuideSeen();
      social.seedDemoFriend('ayesha');
      await tester.pumpWidget(SafeHerApp(social: social, localPreview: true));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Buddies').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final state = tester.state(find.byType(ContactsScreen));
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller;
      await tester.enterText(find.byType(TextField), 'zz_phone_1022');
      await tester.pump(const Duration(milliseconds: 300));
      social.applyCloudGraph(mine: 'testing1', reqs: [], links: [], names: {});
      social.setSyncError('Temporary connection error');
      await tester.pump(const Duration(milliseconds: 600));
      social.setSyncError(null);
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        identical(tester.state(find.byType(ContactsScreen)), state),
        isTrue,
      );
      expect(
        identical(
          tester.widget<TextField>(find.byType(TextField)).controller,
          controller,
        ),
        isTrue,
      );
      expect(controller!.text, 'zz_phone_1022');
    },
  );
  testWidgets('search spinner lasts until remote results arrive', (
    tester,
  ) async {
    final social = SocialController();
    addTearDown(social.dispose);
    final result = Completer<List<RemoteProfile>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContactsScreen(
            social: social,
            searchRemote: (_) => result.future,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'testing1');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No matching user.'), findsNothing);
    result.complete([
      const RemoteProfile(uid: 'testing-uid', username: 'testing1'),
    ]);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('@testing1'), findsOneWidget);
  });

  testWidgets(
    'failed search offers retry instead of claiming no matching user',
    (tester) async {
      final social = SocialController();
      addTearDown(social.dispose);
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactsScreen(
              social: social,
              searchRemote: (_) async {
                attempts++;
                if (attempts == 1) throw StateError('network unavailable');
                return [
                  const RemoteProfile(uid: 'testing-uid', username: 'testing1'),
                ];
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'testing1');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('No matching user.'), findsNothing);
      expect(find.text('Retry search'), findsOneWidget);
      await tester.tap(find.text('Retry search'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('@testing1'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('clearing search discards a late result and stops loading', (
    tester,
  ) async {
    final social = SocialController();
    addTearDown(social.dispose);
    final result = Completer<List<RemoteProfile>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContactsScreen(
            social: social,
            searchRemote: (_) => result.future,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'testing1');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    result.complete([
      const RemoteProfile(uid: 'testing-uid', username: 'testing1'),
    ]);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('@testing1'), findsNothing);
  });
}
