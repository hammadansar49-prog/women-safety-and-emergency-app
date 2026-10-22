import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/cloud_social.dart';
import 'package:safeher/social_controller.dart';

class _Db extends Fake implements FirebaseFirestore {
  final publishing = Completer<void>();
  final started = Completer<void>();
  final lookupStarted = Completer<void>();
  final lookup = Completer<DocumentSnapshot<Map<String, dynamic>>>();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
}

// Firestore's sealed platform types are faked only to hold a network await.
// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db, this.collectionPath);
  final _Db db;
  final String collectionPath;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(db, collectionPath);
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _Query();
}

// ignore: subtype_of_sealed_class
class _Query extends Fake implements Query<Map<String, dynamic>> {
  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;
  @override
  Query<Map<String, dynamic>> limit(int limit) => this;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => const Stream.empty();
}

// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  Map<String, dynamic> data() => {'name': 'Friend', 'pub': 'public'};
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.db, this.collectionPath);
  final _Db db;
  final String collectionPath;
  @override
  Future<void> update(Map<Object, Object?> data) {
    db.started.complete();
    return db.publishing.future;
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {}
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    db.lookupStarted.complete();
    return db.lookup.future;
  }
}

void main() {
  for (final kind in ['message', 'voice']) {
    test('pending $kind send cannot report into the next account', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final social = SocialController(newAccount: true);
      addTearDown(social.dispose);
      social.enterAccount('zz_eve_1', null, name: 'EVE', username: 'zz_eve_1');
      social.setIdentity('private', 'public');
      final db = _Db()..publishing.complete();
      final errors = <String>[];
      final cloud = CloudSocial(
        social,
        db: db,
        onError: (message) {
          if (message != null) errors.add(message);
        },
      );
      await cloud.start('zz_eve_1', 'eve-uid');
      social.onCloudOp!(
        CloudOp(kind, 'friend', id: 'message-1', text: 'hello'),
      );
      await db.lookupStarted.future;
      await cloud.stop();
      social.enterAccount(
        'zz_phone_1022',
        null,
        name: 'Phone',
        username: 'zz_phone_1022',
      );
      db.lookup.complete(_Snapshot());
      await Future<void>.delayed(Duration.zero);
      expect(errors, isEmpty);
    });
  }
  test(
    'sign out during identity publication cannot restart the old session',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final social = SocialController(newAccount: true);
      addTearDown(social.dispose);
      social.enterAccount('zz_eve_1', null, name: 'EVE', username: 'zz_eve_1');
      social.setIdentity('private', 'public');
      final db = _Db();
      final cloud = CloudSocial(social, db: db);
      final starting = cloud.start('zz_eve_1', 'eve-uid');
      await db.started.future;
      await cloud.stop();
      social.enterAccount(
        'zz_phone_1022',
        null,
        name: 'Phone',
        username: 'zz_phone_1022',
      );
      db.publishing.complete();
      await expectLater(starting, completes);
      expect(cloud.running, isFalse);
      expect(social.onCloudOp, isNull);
      expect(social.currentUser.username, 'zz_phone_1022');
    },
  );
}
