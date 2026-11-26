import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/emergency_dialer.dart';

void main() {
  testWidgets('opens only on tap and targets the emergency dialer', (
    tester,
  ) async {
    Uri? requested;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmergencyDialer(
            openDialer: (uri) async {
              requested = uri;
              return true;
            },
          ),
        ),
      ),
    );
    expect(requested, isNull);
    await tester.tap(find.text('Open dialer: 15'));
    await tester.pump();
    expect(requested.toString(), 'tel:15');
  });

  for (final throws in [false, true]) {
    testWidgets(
      'offers manual fallback on ${throws ? 'exception' : 'failure'}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmergencyDialer(
                openDialer: (_) async {
                  if (throws) throw StateError('Unavailable');
                  return false;
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open dialer: 15'));
        await tester.pump();
        expect(
          find.textContaining('Use your phone to dial 15 manually.'),
          findsOneWidget,
        );
      },
    );
  }
}
