import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/chat_screen.dart';
import 'package:safeher/social_controller.dart';

void main() {
  late SocialController social;
  setUp(() {
    social = SocialController();
    social.requestFriend('ayesha');
    social.switchProfile('ayesha');
    social.respondToFriendRequest(social.pendingIncoming.single.id, true);
    social.switchProfile('hammad');
  });
  tearDown(() => social.dispose());

  testWidgets('safety banner stays accessible in chat and call preview', (
    tester,
  ) async {
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          social: social,
          friendId: 'ayesha',
          safetyBannerBuilder: (_) => TextButton(
            onPressed: () => cancelled = true,
            child: const Text('Cancel active SOS'),
          ),
        ),
      ),
    );
    expect(find.text('Cancel active SOS'), findsOneWidget);
    await tester.tap(find.byTooltip('Video call'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel active SOS'), findsOneWidget);
    await tester.tap(find.text('Cancel active SOS'));
    expect(cancelled, isTrue);
  });

  Future<void> openChat(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: ChatScreen(social: social, friendId: 'ayesha'),
    ),
  );

  testWidgets('composer sends trimmed messages and rejects blank input', (
    tester,
  ) async {
    await openChat(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    expect(social.messagesWith('ayesha'), isEmpty);
    await tester.enterText(find.byType(TextField), '  I am home  ');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(social.messagesWith('ayesha').single.text, 'I am home');
    expect(find.text('I am home'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  for (final label in ['Audio call', 'Video call']) {
    testWidgets('$label opens an honest preview and can end', (tester) async {
      await openChat(tester);
      await tester.tap(find.byTooltip(label));
      await tester.pumpAndSettle();
      expect(find.text('Call preview — no live connection'), findsOneWidget);
      expect(
        find.text(
          'Live calls will be connected in the Firebase/WebRTC phase. Camera and microphone are not active.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('End call preview'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });
  }

  testWidgets('identity change hides conversation and disables composer', (
    tester,
  ) async {
    await openChat(tester);
    social.sendMessage('ayesha', 'Private message');
    await tester.pumpAndSettle();
    social.switchProfile('sara');
    await tester.pumpAndSettle();
    expect(find.text('Private message'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Audio call',
            ),
          )
          .onPressed,
      isNull,
    );
  });
}
