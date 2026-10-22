import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:safeher/chat_photo.dart';

void main() {
  test('small PNG becomes a real JPEG without upscaling', () {
    final source = img.Image(width: 12, height: 8);
    img.fill(source, color: img.ColorRgb8(210, 40, 60));
    final bytes = prepareChatPhoto(img.encodePng(source));
    expect(bytes.take(2), [0xff, 0xd8]);
    final result = img.decodeJpg(bytes)!;
    expect(result.width, 12);
    expect(result.height, 8);
    expect(result.getPixel(4, 4).r, closeTo(210, 10));
  });

  test('camera orientation is baked before EXIF and GPS are removed', () {
    final source = img.Image(width: 30, height: 10);
    source.exif.imageIfd
      ..orientation = 6
      ..make = 'Private camera';
    source.exif.gpsIfd
      ..gpsLatitude = 24.8
      ..gpsLatitudeRef = 'N'
      ..gpsLongitude = 67.0
      ..gpsLongitudeRef = 'E';
    final input = img.encodeJpg(source);
    expect(img.decodeJpg(input)!.exif.gpsIfd.gpsLatitude, isNotNull);
    final result = img.decodeJpg(prepareChatPhoto(input))!;
    expect(result.width, 10);
    expect(result.height, 30);
    expect(result.exif.isEmpty, isTrue);
  });

  test('large noisy photo is independently bounded in pixels and bytes', () {
    final random = Random(17);
    final source = img.Image(width: 1600, height: 1000);
    for (final pixel in source) {
      pixel.setRgb(
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
      );
    }
    final input = img.encodeJpg(source, quality: 100);
    expect(input.length, greaterThan(400000));
    final bytes = prepareChatPhoto(input);
    final result = img.decodeJpg(bytes)!;
    expect(bytes.length, lessThanOrEqualTo(400000));
    expect(max(result.width, result.height), lessThanOrEqualTo(1280));
    expect(result.width / result.height, closeTo(1.6, 0.01));
  });

  test('invalid image bytes fail explicitly', () {
    expect(() => prepareChatPhoto(Uint8List(0)), throwsFormatException);
    expect(
      () => prepareChatPhoto(Uint8List.fromList([1, 2, 3, 4])),
      throwsFormatException,
    );
  });
}
