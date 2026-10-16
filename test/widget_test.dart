import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:safeher/main.dart';
import 'package:safeher/social_controller.dart';

SocialController readyCircle() {
  final social = SocialController();
  social.requestFriend('ayesha');
  social.switchProfile('ayesha');
  social.respondToFriendRequest(social.pendingIncoming.single.id, true);
  social.switchProfile('hammad');
  social.favorite('ayesha');
  social.switchProfile('ayesha');
  social.respondToSosRequest('hammad', true);
  social.switchProfile('hammad');
  return social;
}

void main() {
  testWidgets('onboarding opens the product interface without demo branding', (
    tester,
  ) async {
    await tester.pumpWidget(const SafeHerApp());
    expect(find.text('Get started'), findsOneWidget);
    await tester.ensureVisible(find.text('Get started'));
    await tester.pump();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('SafeHer'), findsOneWidget);
    expect(find.text('Demo mode'), findsNothing);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Connection unavailable'), findsOneWidget);
  });

  testWidgets(
    'selected countdown activates automatically and resolves to history',
    (tester) async {
      final social = readyCircle();
      addTearDown(social.dispose);
      await tester.pumpWidget(SafeHerApp(social: social));
      await tester.ensureVisible(find.text('Get started'));
      await tester.pump();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 sec'));
      await tester.tap(find.byIcon(Icons.shield_outlined));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('START SOS'));
      await tester.pump();
      await tester.tap(find.text('START SOS'));
      await tester.pump();
      expect(find.text('SOS starts in 3 seconds'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('SOS ACTIVE'), findsOneWidget);
      await tester.ensureVisible(find.text('I am safe'));
      await tester.pump();
      await tester.tap(find.text('I am safe'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();
      expect(find.text('Hammad · resolved'), findsOneWidget);
    },
  );

  testWidgets('cancelled countdown stays idle after its original deadline', (
    tester,
  ) async {
    final social = readyCircle();
    addTearDown(social.dispose);
    await tester.pumpWidget(SafeHerApp(social: social));
    await tester.ensureVisible(find.text('Get started'));
    await tester.pump();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('START SOS'));
    await tester.pump();
    await tester.tap(find.text('START SOS'));
    await tester.pump();
    await tester.ensureVisible(find.text('Cancel countdown'));
    await tester.pump();
    await tester.tap(find.text('Cancel countdown'));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('SOS ACTIVE'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('START SOS'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(social.visibleEvents, isEmpty);
    expect(find.text('A fresh start'), findsOneWidget);
  });

  testWidgets('SOS appears only for favorite recipient and keeps its sender', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final social = readyCircle();
    addTearDown(social.dispose);
    await tester.pumpWidget(SafeHerApp(social: social));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START SOS'));
    await tester.pump(const Duration(seconds: 5));
    social.switchProfile('ayesha');
    await tester.pumpAndSettle();
    expect(find.text('SOS from Hammad'), findsOneWidget);
    expect(find.text('I am safe'), findsNothing);
    social.switchProfile('sara');
    await tester.pumpAndSettle();
    expect(find.text('SOS from Hammad'), findsNothing);
    social.switchProfile('hammad');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('I am safe'));
    await tester.pump();
    await tester.tap(find.text('I am safe'));
    await tester.pumpAndSettle();
    expect(social.visibleEvents.single.status, LocalSosStatus.resolved);
  });

  testWidgets('countdown can be cancelled inside a friend chat', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final social = readyCircle();
    addTearDown(social.dispose);
    await tester.pumpWidget(SafeHerApp(social: social));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START SOS'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.people_outline).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('friend-ayesha')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('friend-ayesha')));
    await tester.pumpAndSettle();
    expect(find.text('Write a message'), findsOneWidget);
    expect(find.text('Cancel SOS'), findsOneWidget);
    await tester.tap(find.text('Cancel SOS'));
    await tester.pump(const Duration(seconds: 6));
    expect(social.visibleEvents, isEmpty);
    expect(find.text('Cancel SOS'), findsNothing);
  });
}
