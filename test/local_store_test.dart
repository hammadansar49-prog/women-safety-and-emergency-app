import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safeher/profile_photo.dart';
import 'package:safeher/social_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'database survives close and reopen without erasing signed-out account',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'safeher-storage-',
      );
      Hive.init(directory.path);
      try {
        var box = await Hive.openBox<String>('account');
        final c = SocialController(newAccount: true);
        c.persist = (value) async {
          await box.put('state', value);
          await box.flush();
        };
        c.claimUsername('persistent_user');
        c.setAppearance('dark');
        c.setCountdown(10);
        c.setSignedIn(false);
        await c.flush();
        await box.close();
        box = await Hive.openBox<String>('account');
        final restored = SocialController.fromSnapshot(box.get('state')!);
        expect(restored.currentUser.username, 'persistent_user');
        expect(restored.appearance, 'dark');
        expect(restored.countdown, 10);
        expect(restored.signedIn, isFalse);
        c.dispose();
        restored.dispose();
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'photo becomes a stored thumbnail and invalid images are rejected',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawColor(const ui.Color(0xFF6552A3), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(800, 400);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      final photo = await prepareProfilePhoto(XFile.fromData(bytes));
      final codec = await ui.instantiateImageCodec(base64Decode(photo));
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 384);
      expect(frame.image.height, 192);
      frame.image.dispose();
      codec.dispose();
      image.dispose();
      picture.dispose();
      await expectLater(
        prepareProfilePhoto(XFile.fromData(Uint8List.fromList([1, 2, 3]))),
        throwsA(anything),
      );
    },
  );
}
