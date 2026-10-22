import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/bloom_filter.dart';

void main() {
  test('never misses a name that was added, rarely claims a free one', () {
    final f = BloomFilter(Uint8List(2000), 7); // 16000 bits
    for (var i = 0; i < 1000; i++) {
      f.add('user_$i');
    }
    for (var i = 0; i < 1000; i++) {
      expect(f.mightContain('user_$i'), isTrue);
    }
    var falsePositives = 0;
    for (var i = 0; i < 1000; i++) {
      if (f.mightContain('free_name_$i')) falsePositives++;
    }
    expect(falsePositives, lessThan(60)); // ~16 bits per name -> well under 6%
  });

  test('matches the server hashing on a fixed vector', () {
    // Positions for "amy" with m = 2^20, k = 7, as computed by
    // functions/index.js.
    final f = BloomFilter(Uint8List(1 << 17), 7);
    f.add('amy');
    final set = <int>[
      for (var p = 0; p < f.size; p++)
        if (f.bits[p >> 3] & (1 << (p & 7)) != 0) p,
    ];
    expect(set, [501022, 574323, 647624, 720925, 794226, 867527, 940828]);
  });
}
