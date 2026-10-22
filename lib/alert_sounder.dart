import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'siren.dart';

/// Makes this phone loud and impossible to miss: a siren with a spoken line
/// ("Carol needs help, open SafeHer") for an incoming SOS, or a plain ring for
/// a call. Nothing here needs an audio file.
class AlertSounder {
  AlertSounder();

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  Timer? _speaker;
  bool _on = false;

  bool get isOn => _on;

  Future<void> _play(Uint8List wav, double volume, {required bool alarm}) async {
    await _player.setReleaseMode(ReleaseMode.loop);
    try {
      await _player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            usageType: alarm
                ? AndroidUsageType.alarm
                : AndroidUsageType.notificationRingtone,
            contentType: alarm
                ? AndroidContentType.sonification
                : AndroidContentType.music,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
        ),
      );
    } catch (_) {}
    await _player.play(BytesSource(wav), volume: volume);
  }

  /// Loud siren plus a spoken alert, repeated until [stop].
  Future<void> siren(String who) async {
    if (_on) return;
    _on = true;
    try {
      await _play(sirenWav(), 1.0, alarm: true);
      Future<void> speak() async {
        try {
          await _tts.setVolume(1.0);
          await _tts.setSpeechRate(0.45);
          await _tts.speak('$who needs help. Open SafeHer.');
        } catch (_) {}
      }

      unawaited(speak());
      _speaker = Timer.periodic(const Duration(seconds: 9), (_) => speak());
    } catch (_) {
      // No audio device: the notification and banner still show.
    }
  }

  Future<void> ring() async {
    if (_on) return;
    _on = true;
    try {
      await _play(ringWav(), 0.8, alarm: false);
    } catch (_) {}
  }

  Future<void> stop() async {
    _on = false;
    _speaker?.cancel();
    _speaker = null;
    try {
      await _tts.stop();
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
