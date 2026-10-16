import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:safeher/main.dart';

void main() {
  testWidgets('onboarding clearly labels demo and opens home', (tester) async {
    await tester.pumpWidget(const SafeHerApp());
    expect(find.text('Explore demo'), findsOneWidget);
    await tester.ensureVisible(find.text('Explore demo'));
    await tester.tap(find.text('Explore demo'));
    await tester.pumpAndSettle();
    expect(find.text('Demo mode'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Firebase not connected'), findsOneWidget);
  });
}
