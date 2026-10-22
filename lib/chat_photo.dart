import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'image_picker_intent.dart';

/// Returns a compressed, metadata-free chat photo, or null on cancellation.
Future<Uint8List?> pickChatPhoto(ImageSource source) async {
  final intent = await ImagePickerIntent.begin('chat');
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return await compute(prepareChatPhoto, await file.readAsBytes());
  } finally {
    await intent?.clear();
  }
}

/// Normalizes actual pixels independently of picker quality/size hints.
/// The JPEG contains no EXIF/GPS and never exceeds 400,000 bytes or 1280 px.
Uint8List prepareChatPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('This photo could not be read.');
  }
  var image = img.bakeOrientation(decoded);
  final longest = math.max(image.width, image.height);
  if (longest > 1280) {
    final scale = 1280 / longest;
    image = img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      height: math.max(1, (image.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }
  // bakeOrientation preserves other EXIF, so explicitly discard metadata
  // after rotation. Reencoding also drops source container metadata.
  image
    ..exif = img.ExifData()
    ..iccProfile = null
    ..textData = null;

  for (final quality in [85, 70, 55, 40]) {
    final jpeg = img.encodeJpg(image, quality: quality);
    if (jpeg.length <= 400000) return jpeg;
  }
  // Very detailed pictures can exceed the budget even at lower quality.
  // Reduce dimensions until the encoded bytes themselves meet the limit.
  while (true) {
    image = img.copyResize(
      image,
      width: math.max(1, (image.width * 0.8).floor()),
      height: math.max(1, (image.height * 0.8).floor()),
      interpolation: img.Interpolation.average,
    );
    final jpeg = img.encodeJpg(image, quality: 70);
    if (jpeg.length <= 400000) return jpeg;
  }
}
