import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// A single position fix.
class LocationFix {
  const LocationFix(this.latitude, this.longitude, this.time);
  final double latitude;
  final double longitude;
  final DateTime time;
}

/// Streams the device position for as long as an SOS is active.
///
/// This is continuous tracking, not a one-off snapshot: [start] subscribes to
/// the position stream and keeps delivering fixes until [stop]. On Android the
/// stream runs under a foreground service with a visible notification, so it
/// keeps going when the screen is locked or the app is in the background.
class LocationTracker {
  StreamSubscription<Position>? _sub;
  bool get running => _sub != null;

  /// Starts tracking. Returns false when location is switched off or the user
  /// declined permission; in that case nothing is tracked and nothing is shared.
  Future<bool> start(void Function(LocationFix fix) onFix) async {
    if (_sub != null) return true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
      // An immediate first fix so the contact is not waiting for movement.
      try {
        final first = await Geolocator.getCurrentPosition();
        onFix(_fix(first));
      } catch (_) {}
      _sub = Geolocator.getPositionStream(locationSettings: _settings()).listen(
        (p) => onFix(_fix(p)),
        onError: (_) {},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stops tracking and returns the last known position, so the point where
  /// the SOS ended can be recorded.
  Future<LocationFix?> stop() async {
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
    try {
      final last = await Geolocator.getLastKnownPosition();
      return last == null ? null : _fix(last);
    } catch (_) {
      return null;
    }
  }

  LocationFix _fix(Position p) =>
      LocationFix(p.latitude, p.longitude, p.timestamp);

  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'SafeHer SOS is sharing your location',
          notificationText: 'Your SOS buddies can see where you are.',
          enableWakeLock: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }
}
