import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/location_service.dart';

void main() {
  final now = DateTime.utc(2026, 11, 26, 12);
  test('only recent valid coordinates qualify for initial SOS', () {
    expect(usableSosFix(LocationFix(30, 71, now), now), isTrue);
    expect(
      usableSosFix(
        LocationFix(30, 71, now.subtract(const Duration(minutes: 3))),
        now,
      ),
      isFalse,
    );
    expect(
      usableSosFix(
        LocationFix(30, 71, now.add(const Duration(seconds: 1))),
        now,
      ),
      isFalse,
    );
    expect(usableSosFix(LocationFix(91, 71, now), now), isFalse);
    expect(usableSosFix(LocationFix(double.nan, 71, now), now), isFalse);
  });
}
