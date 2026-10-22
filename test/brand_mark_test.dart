import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/ui/brand_mark.dart';

void main() {
  testWidgets('the mark keeps its proportions and announces itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: BrandMark(size: 80)))),
    );
    final size = tester.getSize(find.byType(BrandMark));
    expect(size.height, 80);
    // Narrower than it is tall: the drawing is a head and shoulders, and a
    // square box would letterbox it.
    expect(size.width, closeTo(67.2, 0.5));
  });

  testWidgets('it paints at a size small enough for a notification', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: BrandMark(size: 20)))),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BrandMark)).height, 20);
  });
}
