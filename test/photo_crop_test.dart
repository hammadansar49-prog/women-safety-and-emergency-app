import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/photo_crop_screen.dart';

void main() {
  test('crop covers square and reaches both landscape edges', () {
    const image = Size(800, 400);
    expect(
      profileCropRect(image, 1, Offset.zero),
      const Rect.fromLTWH(200, 0, 400, 400),
    );
    expect(
      profileCropRect(image, 1, const Offset(0.5, 0)),
      const Rect.fromLTWH(0, 0, 400, 400),
    );
    expect(
      profileCropRect(image, 1, const Offset(-0.5, 0)),
      const Rect.fromLTWH(400, 0, 400, 400),
    );
  });
  test('portrait crop zoom and extreme drag stay inside source', () {
    const image = Size(400, 800);
    expect(
      profileCropRect(image, 2, Offset.zero),
      const Rect.fromLTWH(100, 300, 200, 200),
    );
    expect(
      profileCropRect(image, 2, const Offset(99, -99)),
      const Rect.fromLTWH(0, 600, 200, 200),
    );
  });
}
