import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/social_controller.dart';

void main() {
  test(
    'photo emits a binary cloud operation and survives own account snapshot',
    () {
      final social = SocialController();
      addTearDown(social.dispose);
      social.seedDemoFriend('ayesha');
      final sent = <CloudOp>[];
      social.onCloudOp = sent.add;
      final bytes = Uint8List.fromList([255, 216, 255, 217]);
      social.sendPhoto('ayesha', bytes);
      final photo = social.messagesWith('ayesha').last;
      expect(photo.kind, MessageKind.photo);
      expect(photo.photo, bytes);
      expect(sent.single.kind, 'photo');
      expect(sent.single.photo, bytes);
      final restored = SocialController.fromSnapshot(social.snapshot());
      addTearDown(restored.dispose);
      expect(restored.messagesWith('ayesha').last.photo, bytes);
    },
  );
  test('oversized photo is rejected before posting a cloud operation', () {
    final social = SocialController();
    addTearDown(social.dispose);
    social.seedDemoFriend('ayesha');
    expect(
      () => social.sendPhoto('ayesha', Uint8List(400001)),
      throwsStateError,
    );
  });
  test(
    'an attachment omitted from the local cache can hydrate from the cloud',
    () {
      final social = SocialController();
      addTearDown(social.dispose);
      social.seedDemoFriend('ayesha');
      final bytes = Uint8List(300000);
      social.sendPhoto('ayesha', bytes);
      final first = social.messagesWith('ayesha').last;
      social.sendPhoto('ayesha', bytes);
      final restored = SocialController.fromSnapshot(social.snapshot());
      addTearDown(restored.dispose);
      expect(
        restored
            .messagesWith('ayesha')
            .where((m) => m.id == first.id)
            .single
            .photo,
        isNull,
      );
      restored.applyCloudMessages([first]);
      expect(
        restored
            .messagesWith('ayesha')
            .where((m) => m.id == first.id)
            .single
            .photo,
        bytes,
      );
    },
  );
}
