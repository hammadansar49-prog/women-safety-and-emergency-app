import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/call_signaling.dart';

// Firestore platform types are faked only to hold a pending network write.
// ignore: subtype_of_sealed_class
class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.record);
  final Map<String, dynamic> record;
  @override
  String get id => 'queued-call';
  @override
  Map<String, dynamic> data() => record;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Db implements FirebaseFirestore {
  final ref = _CallRef();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Calls(ref);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _Calls implements CollectionReference<Map<String, dynamic>> {
  _Calls(this.ref);
  final _CallRef ref;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => ref;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class, must_be_immutable
class _CallRef implements DocumentReference<Map<String, dynamic>> {
  final pending = Completer<void>();
  Map<String, dynamic>? record;
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) {
    record = data;
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CallDoc _call(DateTime createdAt, {DateTime? expiresAt}) => CallDoc.fromDoc(
  _Snapshot({
    'caller': 'amy',
    'callee': 'bob',
    'kind': 'audio',
    'status': 'ringing',
    'createdAt': Timestamp.fromDate(createdAt),
    if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
  }),
);

void main() {
  final now = DateTime.utc(2026, 10, 22, 12);

  test(
    'creation fixes ring expiry before the backend write completes',
    () async {
      final db = _Db();
      final before = DateTime.now();
      final write = CallSignaling(db).create(
        id: 'queued-call',
        caller: 'amy',
        callee: 'bob',
        kind: CallKind.audio,
        offer: {'sdp': 'offer', 'type': 'offer'},
      );
      final after = DateTime.now();
      expect(db.ref.record?['expiresAt'], isA<Timestamp>());
      final expiry = (db.ref.record!['expiresAt'] as Timestamp).toDate();
      expect(expiry.isBefore(before.add(const Duration(seconds: 90))), isFalse);
      expect(expiry.isAfter(after.add(const Duration(seconds: 90))), isFalse);
      db.ref.pending.complete();
      await write;
    },
  );

  test('queued expired call is stale despite a fresh server timestamp', () {
    final call = _call(
      now,
      expiresAt: now.subtract(const Duration(minutes: 4)),
    );
    expect(call.isFreshAt(now), isFalse);
  });

  test('fresh call with a future expiry can ring', () {
    final call = _call(now, expiresAt: now.add(const Duration(seconds: 90)));
    expect(call.isFreshAt(now), isTrue);
  });

  test('a call expires at the expiry boundary', () {
    final call = _call(now, expiresAt: now);
    expect(call.isFreshAt(now), isFalse);
  });

  test('legacy calls without expiresAt retain createdAt freshness', () {
    expect(_call(now).isFreshAt(now), isTrue);
    expect(
      _call(now.subtract(const Duration(minutes: 5))).isFreshAt(now),
      isFalse,
    );
  });
}
