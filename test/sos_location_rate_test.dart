import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/cloud_social.dart';

void main() {
  // Every published fix costs one write per SOS buddy, so what this decides
  // is the difference between an SOS that runs all evening and one that
  // exhausts the day's allowance in an hour.
  ({DateTime at, double lat, double lng}) at(
    double seconds, {
    double lat = 30.2489,
    double lng = 71.4718,
  }) => (
    at: DateTime(2026, 1, 1).add(
      Duration(milliseconds: (seconds * 1000).round()),
    ),
    lat: lat,
    lng: lng,
  );

  bool send(
    ({DateTime at, double lat, double lng}) last,
    double seconds, {
    double lat = 30.2489,
    double lng = 71.4718,
  }) => sosFixIsWorthSending(
    last,
    DateTime(2026, 1, 1).add(Duration(milliseconds: (seconds * 1000).round())),
    lat,
    lng,
  );

  test('a burst of fixes from a standing phone is held to the floor', () {
    final last = at(0);
    for (final t in [0.5, 1.0, 3.0, 5.0, 7.9]) {
      expect(send(last, t), isFalse, reason: '$t s after the last write');
    }
  });

  test('someone who has not moved is still reported regularly', () {
    // "She is still at the same corner" is information a buddy needs to go
    // on seeing, so standing still must never mean silence.
    expect(send(at(0), 20.0), isTrue);
  });

  test('real movement is reported as soon as the floor allows', () {
    // Roughly 110 m north: being driven away.
    expect(send(at(0), 9.0, lat: 30.2499), isTrue);
  });

  test('GPS jitter on a stationary phone does not trigger a write', () {
    // A few metres of drift is the receiver wobbling, not the person moving.
    expect(send(at(0), 9.0, lat: 30.248915), isFalse);
  });

  test('an hour of standing still stays well inside the daily allowance', () {
    var last = at(0);
    var writes = 0;
    for (var tenth = 1; tenth <= 36000; tenth++) {
      final t = tenth / 10;
      if (!send(last, t)) continue;
      writes++;
      last = at(t);
    }
    // Three buddies, so three writes each time; the old three-second rule
    // cost 3,600 writes an hour on its own.
    expect(writes * 3, lessThan(600));
  });
}
