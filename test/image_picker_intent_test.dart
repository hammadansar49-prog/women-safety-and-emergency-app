import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:safeher/chat_photo.dart';
import 'package:safeher/image_picker_intent.dart';
import 'package:safeher/profile_photo.dart';
import 'package:safeher/social_controller.dart';

class _Picker extends ImagePickerPlatform {
  Future<LostDataResponse>? lost;
  ImagePickerIntent? intentAtPick;
  @override
  Future<LostDataResponse> getLostData() async =>
      await (lost ?? Future.value(LostDataResponse.empty()));
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    intentAtPick = ImagePickerIntent.current;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Box<String> box;
  late SocialController social;
  late _Picker picker;
  late ImagePickerPlatform previous;
  setUpAll(() async {
    final directory = await Directory.systemTemp.createTemp(
      'safeher-pick-test-',
    );
    Hive.init(directory.path);
    box = await Hive.openBox<String>('safeher_account_v2');
  });
  tearDownAll(() async => Hive.close());
  setUp(() async {
    await box.put('session', 'alice');
    await box.delete('image_picker_intent_v1');
    await box.delete('image_picker_recovered_v1');
    social = SocialController(newAccount: true)
      ..enterAccount('alice', null, name: 'Alice', username: 'alice');
    previous = ImagePickerPlatform.instance;
    picker = _Picker();
    ImagePickerPlatform.instance = picker;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    social.dispose();
    ImagePickerPlatform.instance = previous;
    debugDefaultTargetPlatformOverride = null;
  });

  test('old completion cannot clear a newer pick intent', () async {
    final old = await ImagePickerIntent.begin('profile', owner: 'alice');
    final current = await ImagePickerIntent.begin('chat', owner: 'bob');
    await old!.clear();
    expect(ImagePickerIntent.current!.token, current!.token);
    expect(ImagePickerIntent.current!.owner, 'bob');
  });

  test(
    'chat tags owner before opening camera and clears cancellation',
    () async {
      expect(await pickChatPhoto(ImageSource.camera), isNull);
      expect(picker.intentAtPick!.purpose, 'chat');
      expect(picker.intentAtPick!.owner, 'alice');
      expect(ImagePickerIntent.current, isNull);
    },
  );

  test(
    'matching profile purpose and account still recover the avatar',
    () async {
      await ImagePickerIntent.begin('profile', owner: 'alice');
      picker.lost = Future.value(
        LostDataResponse(
          files: [
            XFile.fromData(img.encodePng(img.Image(width: 8, height: 4))),
          ],
        ),
      );
      await recoverProfilePhoto(social);
      expect(social.photoFor(social.currentUserId), isNotNull);
      expect(ImagePickerIntent.current, isNull);
      expect(social.saveError, isNull);
    },
  );

  for (final purpose in ['chat', 'legacy', 'other-account-profile']) {
    test('$purpose recovery never reads or replaces profile photo', () async {
      if (purpose != 'legacy') {
        await ImagePickerIntent.begin(
          purpose == 'chat' ? 'chat' : 'profile',
          owner: purpose == 'other-account-profile' ? 'bob' : 'alice',
        );
      }
      picker.lost = Future.value(
        LostDataResponse(files: [XFile('untouched-interrupted-photo.jpg')]),
      );
      await recoverProfilePhoto(social);
      expect(social.photoFor(social.currentUserId), isNull);
      expect(social.saveError, contains('again'));
      final recovered = jsonDecode(box.get('image_picker_recovered_v1')!);
      expect(recovered['paths'], contains('untouched-interrupted-photo.jpg'));
    });
  }

  test(
    'account switch while lost-data lookup waits cannot apply old pick',
    () async {
      await ImagePickerIntent.begin('profile', owner: 'alice');
      final pending = Completer<LostDataResponse>();
      picker.lost = pending.future;
      final recovering = recoverProfilePhoto(social);
      social.enterAccount('bob', null, name: 'Bob', username: 'bob');
      // Both accounts deliberately have the same device-local profile id.
      expect(social.currentUserId, 'hammad');
      pending.complete(
        LostDataResponse(files: [XFile('old-account-photo.jpg')]),
      );
      await recovering;
      expect(social.photoFor(social.currentUserId), isNull);
      expect(social.saveError, isNull);
    },
  );
}
