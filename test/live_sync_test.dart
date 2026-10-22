import 'dart:async';
// fake_async is provided by flutter_test; no platform/network clocks are used.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/cloud_social.dart';
import 'package:safeher/e2ee.dart';
import 'package:safeher/social_controller.dart';

import 'fake_presence.dart';

class LiveDb extends Fake implements FirebaseFirestore {
  final publish = Completer<void>();
  final profile = Completer<DocumentSnapshot<Map<String, dynamic>>>();
  final streams =
      <String, StreamController<QuerySnapshot<Map<String, dynamic>>>>{};
  final profileStreams =
      <String, StreamController<DocumentSnapshot<Map<String, dynamic>>>>{};
  final reads =
      <String, List<Completer<QuerySnapshot<Map<String, dynamic>>>>>{};
  final updates = <({String path, Map<Object, Object?> data})>[];
  Completer<void>? offlinePresence;
  final presence = <Map<String, dynamic>>[];
  final writes = <({String path, Map<String, dynamic> data})>[];
  final wroteMessage = Completer<void>();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      LiveCollection(this, path);
  Stream<QuerySnapshot<Map<String, dynamic>>> watch(String key) =>
      (streams[key] ??= StreamController.broadcast()).stream;
  void emit(String key, List<Map<String, dynamic>> rows) =>
      streams[key]!.add(LiveSnapshot(rows, db: this, path: key));
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile(String path) =>
      (profileStreams[path] ??= StreamController.broadcast()).stream;
  void emitProfile(String path, Map<String, dynamic> data) =>
      profileStreams[path]!.add(LiveRow(data, db: this, path: path));
  Future<void> close() async {
    for (final s in streams.values) {
      await s.close();
    }
    for (final s in profileStreams.values) {
      await s.close();
    }
  }
}

// ignore: subtype_of_sealed_class
class LiveCollection extends LiveQuery
    implements CollectionReference<Map<String, dynamic>> {
  LiveCollection(super.db, super.path);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      LiveDocument(db, '${this.path}/${path ?? 'generated'}');
}

// ignore: subtype_of_sealed_class
class LiveQuery extends Fake implements Query<Map<String, dynamic>> {
  LiveQuery(this.db, this.path);
  final LiveDb db;
  final String path;
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
  }) => LiveQuery(db, '$path/$field');
  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;
  @override
  Query<Map<String, dynamic>> limit(int limit) => this;
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    final pending = Completer<QuerySnapshot<Map<String, dynamic>>>();
    (db.reads[path] ??= []).add(pending);
    return pending.future;
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => db.watch(path);
}

// ignore: subtype_of_sealed_class
class LiveDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  LiveDocument(this.db, this.path);
  final LiveDb db;
  @override
  final String path;
  @override
  Future<void> update(Map<Object, Object?> data) {
    db.updates.add((path: path, data: data));
    return db.publish.future;
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (path.startsWith('presence/')) db.presence.add(data);
    db.writes.add((path: path, data: data));
    if (path.contains('messages') && !db.wroteMessage.isCompleted) {
      db.wroteMessage.complete();
    }
    if (path.startsWith('presence/') && data['online'] == false) {
      await db.offlinePresence?.future;
    }
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      LiveCollection(db, '$path/$collectionPath');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      db.profile.future;
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => db.watchProfile(path);
}

// ignore: subtype_of_sealed_class
class LiveSnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  LiveSnapshot(List<Map<String, dynamic>> rows, {LiveDb? db, String path = ''})
    : docs = [
        for (var i = 0; i < rows.length; i++)
          LiveRow(rows[i], db: db, path: '$path/message-$i'),
      ];
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

// ignore: subtype_of_sealed_class
class LiveRow extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  LiveRow(this.row, {this.db, this.path = 'message'});
  final Map<String, dynamic> row;
  final LiveDb? db;
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  DocumentReference<Map<String, dynamic>> get reference =>
      LiveDocument(db!, path);
  @override
  SnapshotMetadata get metadata => LiveMetadata();
  @override
  Map<String, dynamic> data() => row;
}

class LiveMetadata extends Fake implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;
  @override
  bool get isFromCache => false;
}

void main() {
  late SocialController social;
  late LiveDb db;
  late CloudSocial cloud;
  late FakePresence presence;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    social = SocialController(newAccount: true)
      ..enterAccount('alice', null, name: 'Alice', username: 'alice');
    social.setIdentity('private', 'public');
    db = LiveDb();
    presence = FakePresence();
    cloud = CloudSocial(social, db: db, presence: presence);
  });
  tearDown(() async {
    if (!db.publish.isCompleted) db.publish.complete();
    await cloud.stop();
    await db.close();
    social.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
  test('request listeners start without waiting for identity upload', () async {
    final starting = cloud.start('alice', 'alice-uid');
    await Future<void>.delayed(Duration.zero);
    expect(db.streams.keys, contains('friendReqs/to'));
    db.publish.complete();
    await starting;
  });
  test(
    'restarting listeners is bounded when offline presence never resolves',
    () async {
      db.publish.complete();
      await cloud.start('alice', 'alice-uid');
      final requests = db.streams['friendReqs/to']!;
      expect(requests.hasListener, isTrue);
      presence.holdOffline = Completer<void>();
      social.enterAccount('bob', null, username: 'bob', name: 'Bob');
      social.setIdentity('private', 'public');
      final restarting = cloud.start('bob', 'bob-uid');
      expect(requests.hasListener, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      expect(requests.hasListener, isTrue);
      presence.holdOffline!.complete();
      await restarting;
    },
  );
  test(
    'incoming request does not wait for SOS queries or profile lookup',
    () async {
      db.publish.complete();
      await cloud.start('alice', 'alice-uid');
      db.emit('friendReqs/from', []);
      db.emit('friendReqs/to', [
        (<String, dynamic>{'from': 'bob', 'to': 'alice', 'status': 'pending'}),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(social.pendingIncoming.map((r) => r.fromId), contains('bob'));
    },
  );
  test('receipt cannot regress from read when an older snapshot arrives', () {
    final now = DateTime.now();
    social.applyReceipt('m', delivered: now, read: now);
    social.applyReceipt('m');
    expect(social.statusOf('m'), MessageStatus.read);
  });
  for (final background in [true, false]) {
    test(
      'pending read query does not stamp after ${background ? 'backgrounding' : 'closing the chat'}',
      () async {
        db.publish.complete();
        await cloud.start('alice', 'alice-uid');
        cloud.setOpenChat('bob');
        final path = 'chats/${pairId('alice', 'bob')}/messages';
        final pending = db.reads['$path/to']!.single;
        if (background) {
          await cloud.goAway();
        } else {
          cloud.setOpenChat(null);
        }
        pending.complete(
          LiveSnapshot(
            [
              {
                'from': 'bob',
                'to': 'alice',
                'deliveredAt': Timestamp.fromDate(DateTime(2026)),
              },
            ],
            db: db,
            path: path,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          db.updates.where((write) => write.path.contains('/messages/')),
          isEmpty,
        );
      },
    );
  }
  test(
    'peer public key publication replays a previously unreadable snapshot',
    () async {
      const encryption = E2ee();
      final alice = await encryption.newIdentity();
      final bob = await encryption.newIdentity();
      social.setIdentity(alice.priv, alice.pub);
      final ciphertext = await encryption.encrypt(
        myPriv: bob.priv,
        theirPub: alice.pub,
        pair: pairId('alice', 'bob'),
        text: 'I arrived safely',
      );
      db.publish.complete();
      db.profile.complete(LiveRow({'name': 'Bob', 'pub': ''}));
      await cloud.start('alice', 'alice-uid');
      db.emit('friendReqs/from', [
        {'from': 'alice', 'to': 'bob', 'status': 'accepted'},
      ]);
      db.emit('friendReqs/to', []);
      await Future<void>.delayed(Duration.zero);
      final path = 'chats/${pairId('alice', 'bob')}/messages';
      expect(db.streams.keys, contains(path));
      db.emit(path, [
        {'from': 'bob', 'to': 'alice', 'ct': ciphertext},
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(social.messagesWith('bob'), isEmpty);

      final received = Completer<void>();
      void onChange() {
        if (social.messagesWith('bob').isNotEmpty && !received.isCompleted) {
          received.complete();
        }
      }

      social.addListener(onChange);
      db.emitProfile('profiles/bob', {'name': 'Bob', 'pub': bob.pub});
      try {
        await received.future.timeout(const Duration(seconds: 2));
        expect(social.messagesWith('bob').single.text, 'I arrived safely');
      } finally {
        social.removeListener(onChange);
      }
    },
  );
  test(
    'photo cloud write contains ciphertext decryptable only for this pair',
    () async {
      const encryption = E2ee();
      final alice = await encryption.newIdentity();
      final bob = await encryption.newIdentity();
      social.setIdentity(alice.priv, alice.pub);
      social.seedDemoFriend('bob');
      db.publish.complete();
      db.profile.complete(LiveRow({'name': 'Bob', 'pub': bob.pub}));
      await cloud.start('alice', 'alice-uid');
      final photo = Uint8List.fromList([255, 216, 255, 217]);
      social.sendPhoto('bob', photo);
      await db.wroteMessage.future.timeout(const Duration(seconds: 2));
      final sealed = db.writes.last.data['photo'] as String;
      expect(db.writes.last.data.containsKey('voice'), false);
      final decoded = await encryption.decryptBytes(
        myPriv: bob.priv,
        theirPub: alice.pub,
        pair: pairId('alice', 'bob'),
        sealed: sealed,
      );
      expect(decoded, photo);
    },
  );
  test(
    'backgrounding publishes nothing further and resume retains open chat',
    () {
      fakeAsync((clock) {
        db.publish.complete();
        cloud.start('alice', 'alice-uid');
        clock.flushMicrotasks();
        cloud.setOpenChat('bob');
        cloud.goAway();
        clock.flushMicrotasks();
        final writes = presence.published.length;
        // There is no heartbeat to republish "online" from the background:
        // the store marks a dropped device offline by itself.
        clock.elapse(const Duration(seconds: 120));
        expect(presence.published.length, writes);
        cloud.resume();
        expect(presence.published.last.online, isTrue);
        expect(presence.published.last.openWith, 'bob');
        cloud.stop();
        clock.flushMicrotasks();
      });
    },
  );
}
