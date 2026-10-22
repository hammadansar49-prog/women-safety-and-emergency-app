import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/main.dart';

void main() {
  testWidgets('normal startup never offers local signup without Firebase', (
    tester,
  ) async {
    await tester.pumpWidget(const SafeHerApp());
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Cannot connect to SafeHer'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
