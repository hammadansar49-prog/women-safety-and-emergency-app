import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/contacts_screen.dart';

void main() {
  testWidgets('favorite action requires the full 1.5 second hold', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FriendContactTile(
            name: 'Ayesha',
            subtitle: '@ayesha',
            favorite: false,
            onOpenChat: () {},
            onOptions: () => opened++,
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Ayesha')),
    );
    await tester.pump(const Duration(milliseconds: 1499));
    expect(opened, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(opened, 1);
    await gesture.up();
  });

  testWidgets('releasing early opens chat without favorite action', (
    tester,
  ) async {
    var opened = 0;
    var chats = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FriendContactTile(
            name: 'Ayesha',
            subtitle: '@ayesha',
            favorite: false,
            onOpenChat: () => chats++,
            onOptions: () => opened++,
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Ayesha')),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    expect(opened, 0);
    expect(chats, 1);
  });
}
