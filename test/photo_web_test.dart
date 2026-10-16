import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safeher/profile_photo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'large valid input is optimized without a file-size rejection',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawColor(const ui.Color(0xFF6552A3), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final source = await picture.toImage(800, 800);
      final data = await source.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      final padded = Uint8List(11 * 1024 * 1024)
        ..setRange(0, bytes.length, bytes);
      final result = base64Decode(
        await prepareProfilePhoto(XFile.fromData(padded)),
      );
      expect(result.length, lessThan(100 * 1024));
      source.dispose();
      picture.dispose();
    },
  );
  for (final dimensions in [(800, 400), (400, 800)]) {
    test(
      'browser-compatible thumbnail preserves aspect ratio $dimensions',
      () async {
        final recorder = ui.PictureRecorder();
        ui.Canvas(
          recorder,
        ).drawColor(const ui.Color(0xFF6552A3), ui.BlendMode.src);
        final picture = recorder.endRecording();
        final source = await picture.toImage(dimensions.$1, dimensions.$2);
        final bytes = await source.toByteData(format: ui.ImageByteFormat.png);
        final encoded = await prepareProfilePhoto(
          XFile.fromData(bytes!.buffer.asUint8List()),
        );
        final codec = await ui.instantiateImageCodec(base64Decode(encoded));
        final frame = await codec.getNextFrame();
        expect(frame.image.width, dimensions.$1 > dimensions.$2 ? 512 : 256);
        expect(frame.image.height, dimensions.$2 > dimensions.$1 ? 512 : 256);
        final pixels = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        expect(
          pixels!.getUint8(3),
          255,
          reason: 'Saved photo must not become transparent',
        );
        expect(pixels.getUint8(0), closeTo(0x65, 3));
        frame.image.dispose();
        codec.dispose();
        source.dispose();
        picture.dispose();
      },
    );
  }
}
