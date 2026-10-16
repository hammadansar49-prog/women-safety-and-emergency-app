import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Materialize browser-backed images as pixels. Lazy WebGL textures render
/// blank when CanvasKit falls back to software rendering.
Future<ui.Image> decodeProfileImage(Uint8List bytes, {int? targetWidth}) async {
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: targetWidth,
    allowUpscaling: false,
  );
  try {
    final image = (await codec.getNextFrame()).image;
    if (!kIsWeb) return image;
    try {
      final pixels = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (pixels == null) throw StateError('Could not read photo pixels.');
      final result = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        Uint8List.fromList(
          pixels.buffer.asUint8List(pixels.offsetInBytes, pixels.lengthInBytes),
        ),
        image.width,
        image.height,
        ui.PixelFormat.rgba8888,
        result.complete,
      );
      return await result.future;
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

class ProfileMemoryImage extends ImageProvider<ProfileMemoryImage> {
  const ProfileMemoryImage(this.bytes);
  final Uint8List bytes;
  @override
  Future<ProfileMemoryImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    ProfileMemoryImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    decodeProfileImage(bytes).then((image) => ImageInfo(image: image)),
  );
  @override
  bool operator ==(Object other) =>
      other is ProfileMemoryImage && listEquals(bytes, other.bytes);
  @override
  int get hashCode => Object.hashAll(bytes);
}
