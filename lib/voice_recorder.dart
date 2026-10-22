import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records a short voice note and reports how loud it is, so the composer can
/// draw a waveform that moves with the voice instead of a canned animation.
///
/// Nothing is kept once the note is sent or thrown away: the recording goes
/// straight into memory, gets sealed by the chat's own encryption, and the
/// file on disk is deleted.
class VoiceRecorder extends ChangeNotifier {
  VoiceRecorder({AudioRecorder? recorder})
    : _rec = recorder ?? AudioRecorder();

  final AudioRecorder _rec;

  /// A voice note is capped so one message can never grow unbounded, and so
  /// the recipient is not handed a monologue in an emergency.
  static const maxLength = Duration(seconds: 60);

  bool get recording => _started != null;
  DateTime? _started;
  Duration elapsed = Duration.zero;
  String? _path;
  Timer? _tick;

  /// The last few loudness readings, newest last, each 0..1.
  final List<double> levels = [];

  /// True once the person has swiped up: they can let go and keep talking.
  bool locked = false;

  Future<bool> hasPermission() => _rec.hasPermission();

  /// Returns false when the microphone was refused, so the caller can say so
  /// rather than showing a recorder that records nothing.
  Future<bool> start() async {
    if (recording) return true;
    if (!await _rec.hasPermission()) return false;
    final dir = await _tempDir();
    _path = '$dir/safeher-voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        numChannels: 1,
        sampleRate: 32000,
      ),
      path: _path!,
    );
    _started = DateTime.now();
    locked = false;
    levels.clear();
    _tick = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      elapsed = DateTime.now().difference(_started!);
      try {
        final a = await _rec.getAmplitude();
        // dBFS, roughly -60 (silence) to 0 (loud).
        final norm = ((a.current + 50) / 50).clamp(0.05, 1.0);
        levels.add(norm.toDouble());
        if (levels.length > 48) levels.removeAt(0);
      } catch (_) {
        levels.add(0.2);
        if (levels.length > 48) levels.removeAt(0);
      }
      if (elapsed >= maxLength) {
        // At the cap it stops listening but keeps the recording, and hands
        // the decision to send or discard back to the person.
        lock();
        _tick?.cancel();
        _tick = null;
        try {
          await _rec.stop();
        } catch (_) {}
      }
      notifyListeners();
    });
    notifyListeners();
    return true;
  }

  void lock() {
    if (!recording || locked) return;
    locked = true;
    notifyListeners();
  }

  /// Ends the recording and hands back the bytes, or null when there is
  /// nothing worth sending.
  Future<({Uint8List bytes, int seconds})?> stopAndRead() async {
    if (!recording) return null;
    final seconds = elapsed.inSeconds;
    await _finish();
    final path = _path;
    _path = null;
    if (path == null || seconds < 1) {
      await _delete(path);
      return null;
    }
    final bytes = await _readFile(path);
    await _delete(path);
    if (bytes == null || bytes.isEmpty) return null;
    return (bytes: bytes, seconds: math.min(seconds, maxLength.inSeconds));
  }

  /// Throws the recording away without sending anything.
  Future<void> cancel() async {
    if (!recording) return;
    await _finish();
    await _delete(_path);
    _path = null;
    notifyListeners();
  }

  Future<void> _finish() async {
    _tick?.cancel();
    _tick = null;
    _started = null;
    locked = false;
    elapsed = Duration.zero;
    levels.clear();
    try {
      await _rec.stop();
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _rec.dispose();
    super.dispose();
  }
}

/// Where a recording is written and read back. On the web there is no
/// filesystem, and [record] hands back a blob URL instead; voice notes are a
/// phone feature, so the web simply does not offer one.
Future<String> _tempDir() async =>
    (await getTemporaryDirectory()).path;

Future<Uint8List?> _readFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> _delete(String? path) async {
  if (path == null) return;
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // A leftover temp file is not worth bothering anyone about.
  }
}
