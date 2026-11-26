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

bool usableSosFix(LocationFix fix, DateTime now) {
  final age = now.difference(fix.time);
  return fix.latitude.isFinite &&
      fix.longitude.isFinite &&
      fix.latitude.abs() <= 90 &&
      fix.longitude.abs() <= 180 &&
      age >= Duration.zero &&
      age <= const Duration(minutes: 2);
}

Future<LocationFix?> cachedSosFix() async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return null;
    }
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return null;
    final fix = LocationFix(
      position.latitude,
      position.longitude,
      position.timestamp,
    );
    return usableSosFix(fix, DateTime.now()) ? fix : null;
  } catch (_) {
    return null;
  }
}

/// Streams the device position for as long as an SOS is active.
///
/// This is continuous tracking, not a one-off snapshot: [start] subscribes to
/// the position stream and keeps delivering fixes until [stop]. On Android the
/// stream runs under a foreground service with a visible notification, so it
/// keeps going when the screen is locked or the app is in the background.
class LocationTracker {
  StreamSubscription<Position>? _sub;
  int _generation = 0;
  bool get running => _sub != null;

  /// Starts tracking. Returns false when location is switched off or the user
  /// declined permission; in that case nothing is tracked and nothing is shared.
  Future<bool> start(void Function(LocationFix fix) onFix) async {
    if (_sub != null) return true;
    final generation = ++_generation;
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
        final first = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 3),
            accuracy: LocationAccuracy.high,
          ),
        );
        if (generation == _generation) onFix(_fix(first));
      } catch (_) {}
      if (generation != _generation) return false;
      _sub = Geolocator.getPositionStream(
        locationSettings: _settings(),
      ).listen((p) => onFix(_fix(p)), onError: (_) {});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// One fix, for sharing where you are right now in a chat. Unlike [start]
  /// this subscribes to nothing and leaves no foreground service behind.
  /// Returns null when location is off or permission was declined.
  static Future<LocationFix?> currentFix() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationFix(p.latitude, p.longitude, p.timestamp);
    } catch (_) {
      // A timeout still leaves a usable recent fix on most phones.
      try {
        final last = await Geolocator.getLastKnownPosition();
        return last == null
            ? null
            : LocationFix(last.latitude, last.longitude, last.timestamp);
      } catch (_) {
        return null;
      }
    }
  }

  /// Stops tracking and returns the last known position, so the point where
  /// the SOS ended can be recorded.
  Future<LocationFix?> stop() async {
    _generation++;
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
        // The sender only publishes fixes that say something new, so a
        // tighter stream than this would cost battery for nothing.
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'SafeHer SOS is sharing your location',
          notificationText: 'Your SOS buddies can see where you are.',
          enableWakeLock: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }
}
