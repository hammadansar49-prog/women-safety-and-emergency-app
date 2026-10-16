import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:safeher/main.dart';

void main() {
  testWidgets('onboarding clearly labels demo and opens home', (tester) async {
    await tester.pumpWidget(const SafeHerApp());
    expect(find.text('Explore demo'), findsOneWidget);
    await tester.ensureVisible(find.text('Explore demo'));
    await tester.pump();
    await tester.tap(find.text('Explore demo'));
    await tester.pumpAndSettle();
    expect(find.text('Demo mode'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Firebase not connected'), findsOneWidget);
  });

  testWidgets(
    'selected countdown activates automatically and resolves to history',
    (tester) async {
      await tester.pumpWidget(const SafeHerApp());
      await tester.ensureVisible(find.text('Explore demo'));
      await tester.pump();
      await tester.tap(find.text('Explore demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 sec'));
      await tester.tap(find.byIcon(Icons.shield_outlined));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('START DEMO'));
      await tester.pump();
      await tester.tap(find.text('START DEMO'));
      await tester.pump();
      expect(find.text('Demo starts in 3 seconds'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('DEMO ACTIVE'), findsOneWidget);
      await tester.ensureVisible(find.text('Resolve demo'));
      await tester.pump();
      await tester.tap(find.text('Resolve demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();
      expect(find.text('Demo resolved'), findsOneWidget);
    },
  );

  testWidgets('cancelled countdown stays idle after its original deadline', (
    tester,
  ) async {
    await tester.pumpWidget(const SafeHerApp());
    await tester.ensureVisible(find.text('Explore demo'));
    await tester.pump();
    await tester.tap(find.text('Explore demo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('START DEMO'));
    await tester.pump();
    await tester.tap(find.text('START DEMO'));
    await tester.pump();
    await tester.ensureVisible(find.text('Cancel countdown'));
    await tester.pump();
    await tester.tap(find.text('Cancel countdown'));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('DEMO ACTIVE'), findsNothing);
    expect(find.text('START DEMO'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('Demo cancelled'), findsOneWidget);
  });
}
