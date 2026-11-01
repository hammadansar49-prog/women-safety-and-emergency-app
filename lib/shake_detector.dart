import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Fires [onShake] after [shakes] hard shakes within [window]. A single bump
/// or a phone dropped on a table is one spike, so it never triggers alone.
class ShakeDetector {
  ShakeDetector({
    required this.onShake,
    this.threshold = 2.7,
    this.shakes = 3,
    this.window = const Duration(milliseconds: 1500),
  });

  final VoidCallback onShake;

  /// Acceleration, in g, that counts as one shake.
  final double threshold;
  final int shakes;
  final Duration window;

  StreamSubscription<AccelerometerEvent>? _sub;
  final List<DateTime> _hits = [];
  DateTime _lastHit = DateTime.fromMillisecondsSinceEpoch(0);

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get running => _sub != null;

  void start() {
    if (!supported || _sub != null) return;
    _sub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(sample, onError: (Object _) => stop());
  }

  /// One accelerometer reading in m/s². Public for tests.
  @visibleForTesting
  void sample(AccelerometerEvent e, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final g = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z) / 9.80665;
    if (g < threshold) return;
    // One physical shake spans several samples; count it once.
    if (now.difference(_lastHit) < const Duration(milliseconds: 250)) return;
    _lastHit = now;
    _hits
      ..add(now)
      ..removeWhere((t) => now.difference(t) > window);
    if (_hits.length >= shakes) {
      _hits.clear();
      onShake();
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _hits.clear();
  }
}
