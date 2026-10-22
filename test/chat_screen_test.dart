import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  testWidgets(
    'camera opens picker and cancellation sends no placeholder message',
    (tester) async {
      ImageSource? source;
      final before = social.messagesWith('ayesha').length;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            social: social,
            friendId: 'ayesha',
            photoPicker: (requested) async {
              source = requested;
              return null;
            },
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.photo_camera_rounded));
      await tester.pump();
      expect(source, ImageSource.camera);
      expect(social.messagesWith('ayesha').length, before);
      expect(find.textContaining('not ready yet'), findsNothing);
    },
  );

  testWidgets('late camera result cannot send under the next account', (
    tester,
  ) async {
    final photo = Completer<Uint8List?>();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          social: social,
          friendId: 'ayesha',
          photoPicker: (_) => photo.future,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.photo_camera_rounded));
    social.enterAccount(
      'other_user',
      null,
      name: 'Other',
      username: 'other_user',
    );
    social.seedDemoFriend('ayesha');
    photo.complete(Uint8List.fromList([255, 216, 255, 217]));
    await tester.pump();
    expect(
      social.messagesWith('ayesha').where((m) => m.kind == MessageKind.photo),
      isEmpty,
    );
  });

  testWidgets('typing is sent from composer and cleared after sending', (
    tester,
  ) async {
    final events = <bool>[];
    social.onTyping = events.add;
    await openChat(tester);
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    expect(events, contains(true));
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(events.last, false);
  });

  testWidgets('peer typing is visible only in this conversation', (
    tester,
  ) async {
    social.applyPresence(
      'ayesha',
      const Presence(online: true, openWith: 'hammad', typing: true),
    );
    await openChat(tester);
    expect(find.text('typing…'), findsOneWidget);
    social.applyPresence(
      'ayesha',
      const Presence(online: true, openWith: 'someone_else', typing: true),
    );
    await tester.pump();
    expect(find.text('typing…'), findsNothing);
  });

  testWidgets(
    'cloud presence compares username rather than device-local profile id',
    (tester) async {
      social.enterAccount(
        'phone_user',
        null,
        name: 'Phone',
        username: 'phone_user',
      );
      social.seedDemoFriend('ayesha');
      social.applyPresence(
        'ayesha',
        const Presence(online: true, openWith: 'phone_user', typing: true),
      );
      await openChat(tester);
      expect(find.text('typing…'), findsOneWidget);
    },
  );

  testWidgets(
    'switching real accounts with same local profile id hides old chat',
    (tester) async {
      await openChat(tester);
      social.enterAccount(
        'other_user',
        null,
        name: 'Other',
        username: 'other_user',
      );
      social.seedDemoFriend('ayesha');
      await tester.pump();
      final composer = tester.widget<TextField>(find.byType(TextField));
      expect(composer.enabled, false);
    },
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
