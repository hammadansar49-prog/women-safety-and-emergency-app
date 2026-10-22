import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/chat_screen.dart';
import 'package:safeher/social_controller.dart';

/// The chat header's orbs drift for ever, so a settle would never finish.
Future<void> settle(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 600));

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

  Future<void> openChat(WidgetTester tester, {WidgetBuilder? banner}) =>
      tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            social: social,
            friendId: 'ayesha',
            safetyBannerBuilder: banner,
          ),
        ),
      );

  testWidgets('every conversation says it is end-to-end encrypted', (
    tester,
  ) async {
    // Connected to the relay, where the encryption claim is the true one.
    social.onCloudOp = (_) {};
    await openChat(tester);
    expect(social.messagesWith('ayesha'), isEmpty);
    expect(
      find.textContaining('End-to-end encrypted'),
      findsOneWidget,
      reason: 'the promise must be on screen before the first message',
    );
  });

  testWidgets('with no relay the chat says so instead of claiming crypto', (
    tester,
  ) async {
    await openChat(tester);
    expect(find.textContaining('Not connected'), findsOneWidget);
  });

  testWidgets('safety banner stays on screen in the chat', (tester) async {
    var cancelled = false;
    await openChat(
      tester,
      banner: (_) => TextButton(
        onPressed: () => cancelled = true,
        child: const Text('Cancel active SOS'),
      ),
    );
    expect(find.text('Cancel active SOS'), findsOneWidget);
    await tester.tap(find.text('Cancel active SOS'));
    expect(cancelled, isTrue);
  });

  testWidgets('a call can be started from the header', (tester) async {
    await openChat(tester);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
    // With no cloud behind it, the chat says so rather than pretending.
    await tester.tap(find.byIcon(Icons.videocam_rounded));
    for (var i = 0; i < 6; i++) {
      await settle(tester);
    }
    expect(find.text('Unable to connect'), findsOneWidget);
  });

  testWidgets('composer sends trimmed messages and rejects blank input', (
    tester,
  ) async {
    await openChat(tester);
    // Nothing typed: hold-to-talk is offered, not a send button that would
    // post an empty message.
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsNothing);

    await tester.enterText(find.byType(TextField), '   ');
    await settle(tester);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    expect(social.messagesWith('ayesha'), isEmpty);

    await tester.enterText(find.byType(TextField), '  I am home  ');
    await settle(tester);
    // Typing swaps hold-to-talk for the send button.
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await settle(tester);
    expect(social.messagesWith('ayesha').single.text, 'I am home');
    expect(find.text('I am home'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('a call nobody answered is left in the conversation', (
    tester,
  ) async {
    social.noteMissedCall('ayesha', video: false, outgoing: false);
    await openChat(tester);
    expect(find.text('Missed voice call'), findsOneWidget);
    expect(social.messagesWith('ayesha').single.isCall, isTrue);
  });

  testWidgets('identity change hides conversation and disables composer', (
    tester,
  ) async {
    await openChat(tester);
    social.sendMessage('ayesha', 'Private message');
    await settle(tester);
    expect(find.text('Private message'), findsOneWidget);

    social.switchProfile('sara');
    await settle(tester);
    expect(find.text('Private message'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });
}
