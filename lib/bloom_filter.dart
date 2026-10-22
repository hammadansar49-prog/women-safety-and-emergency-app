import 'dart:convert';
import 'dart:typed_data';

/// A Bloom filter of taken usernames, built on the server (see
/// functions/index.js, which uses the exact same hashing).
///
/// It answers one question fast and offline: "is this name definitely free as
/// of the last update?" A name it has never seen is shown as available at once;
/// a name it may contain is checked with the database. It is only a hint:
/// the database transaction at sign-up is what makes a name unique.
class BloomFilter {
  BloomFilter(this.bits, this.hashes) : size = bits.length * 8;

  factory BloomFilter.fromJson(Map<String, dynamic> json) => BloomFilter(
    Uint8List.fromList(base64Decode(json['bits'] as String)),
    json['k'] as int,
  );

  final Uint8List bits;
  final int hashes;
  final int size;

  /// FNV-1a over UTF-8, 32 bit. [seed] picks one of the two base hashes.
  static int _fnv(List<int> bytes, int seed) {
    var h = seed;
    for (final b in bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  Iterable<int> _positions(String name) sync* {
    final bytes = utf8.encode(name);
    final h1 = _fnv(bytes, 0x811c9dc5);
    final h2 = _fnv(bytes, 0x9747b28c) | 1;
    for (var i = 0; i < hashes; i++) {
      yield (h1 + i * h2) % size;
    }
  }

  void add(String name) {
    for (final p in _positions(name)) {
      bits[p >> 3] |= 1 << (p & 7);
    }
  }

  /// False means the name was never added: it was free when this was built.
  bool mightContain(String name) {
    for (final p in _positions(name)) {
      if (bits[p >> 3] & (1 << (p & 7)) == 0) return false;
    }
    return true;
  }
}
