import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/call_signaling.dart';

// Firestore platform types are faked only to count writes.
// ignore: subtype_of_sealed_class
class _Db implements FirebaseFirestore {
  final writes = <({String doc, List<Object?> added})>[];
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db);
  final _Db db;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Doc(db, path ?? '');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class, must_be_immutable
class _Doc implements DocumentReference<Map<String, dynamic>> {
  _Doc(this.db, this.name);
  final _Db db;
  final String name;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(db);
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    // arrayUnion is opaque, so record what the call was asked to append by
    // reading it back out of the sentinel's own string form.
    db.writes.add((doc: name, added: [data['c']]));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a burst of candidates becomes a single write', () async {
    final db = _Db();
    final signaling = CallSignaling(db);

    // WebRTC produces these in a rush as it probes the network.
    for (var i = 0; i < 30; i++) {
      unawaited(
        signaling.addCandidate('call-1', 'amy', {'candidate': 'c$i'}),
      );
    }
    expect(db.writes, isEmpty, reason: 'nothing should go out immediately');

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(
      db.writes.length,
      1,
      reason: '30 candidates cost one write, not thirty',
    );
    expect(db.writes.single.doc, 'amy');
  });

  test('candidates found later are appended in a further write', () async {
    final db = _Db();
    final signaling = CallSignaling(db);
    unawaited(signaling.addCandidate('call-1', 'amy', {'candidate': 'a'}));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    unawaited(signaling.addCandidate('call-1', 'amy', {'candidate': 'b'}));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(db.writes.length, 2);
  });

  test('a call that ended never flushes what it had buffered', () async {
    final db = _Db();
    final signaling = CallSignaling(db);
    unawaited(signaling.addCandidate('call-1', 'amy', {'candidate': 'a'}));
    signaling.forget('call-1');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(db.writes, isEmpty);
  });

  test('one call cannot grow its document without bound', () async {
    final db = _Db();
    final signaling = CallSignaling(db);
    for (var round = 0; round < 10; round++) {
      for (var i = 0; i < 20; i++) {
        unawaited(
          signaling.addCandidate('call-1', 'amy', {'candidate': 'c$i'}),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    // 200 candidates offered, but the document stops accepting at the cap,
    // so later rounds are dropped rather than written.
    expect(db.writes.length, lessThan(10));
  });
}
