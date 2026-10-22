import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/siren.dart';

void main() {
  test('siren is a well formed WAV with sound in it', () {
    final wav = sirenWav(seconds: 1, sampleRate: 8000);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(wav.length, 44 + 8000 * 2);
    final view = ByteData.sublistView(wav);
    expect(view.getUint32(4, Endian.little), wav.length - 8);
    var peak = 0;
    for (var i = 44; i < wav.length; i += 2) {
      peak = peak < view.getInt16(i, Endian.little).abs()
          ? view.getInt16(i, Endian.little).abs()
          : peak;
    }
    expect(peak, greaterThan(20000));
  });
}
