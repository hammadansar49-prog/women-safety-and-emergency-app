import 'dart:math' as math;
import 'dart:typed_data';

/// A looping emergency siren as a 16-bit mono WAV, generated here so the app
/// needs no audio asset: a tone that sweeps between [low] and [high] Hz.
Uint8List sirenWav({
  int seconds = 2,
  int sampleRate = 22050,
  double low = 650,
  double high = 1250,
}) {
  final samples = seconds * sampleRate;
  final data = ByteData(44 + samples * 2);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);

  var phase = 0.0;
  for (var i = 0; i < samples; i++) {
    // One full sweep up and down per second, so the loop joins cleanly.
    final t = (i % sampleRate) / sampleRate;
    final sweep = 0.5 - 0.5 * math.cos(2 * math.pi * t);
    final freq = low + (high - low) * sweep;
    phase += 2 * math.pi * freq / sampleRate;
    data.setInt16(44 + i * 2, (math.sin(phase) * 0.8 * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// A soft two-beat phone ring: 0.4s tone, 0.2s gap, 0.4s tone, then a pause.
Uint8List ringWav({int sampleRate = 22050}) {
  const seconds = 3;
  final samples = seconds * sampleRate;
  final data = ByteData(44 + samples * 2);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    final t = i / sampleRate;
    final inBeat = (t < 0.4) || (t >= 0.6 && t < 1.0);
    var v = 0.0;
    if (inBeat) {
      final local = t < 0.5 ? t : t - 0.6;
      final fade = math.min(1.0, math.min(local / 0.02, (0.4 - local) / 0.02));
      v = (math.sin(2 * math.pi * 440 * t) + math.sin(2 * math.pi * 480 * t)) *
          0.35 *
          fade.clamp(0.0, 1.0);
    }
    data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}
