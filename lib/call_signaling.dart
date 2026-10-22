import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum CallKind { audio, video, sos }

enum CallStatus { ringing, active, declined, ended }

@immutable
class CallDoc {
  const CallDoc({
    required this.id,
    required this.caller,
    required this.callee,
    required this.kind,
    required this.status,
    this.offer,
    this.answer,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String caller;
  final String callee;
  final CallKind kind;
  final CallStatus status;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  /// Ringing is temporary. Delayed/offline snapshots must not ring minutes
  /// after the caller has left. SOS streams have their own event lifetime.
  bool isFreshAt(DateTime now) =>
      kind == CallKind.sos ||
      (expiresAt != null
          ? now.isBefore(expiresAt!)
          : createdAt == null ||
                now.difference(createdAt!) < const Duration(seconds: 90));

  /// Session descriptions as {sdp, type}.
  final Map<String, String>? offer;
  final Map<String, String>? answer;

  String peerOf(String me) => me == caller ? callee : caller;

  static Map<String, String>? _sdp(Object? raw) {
    if (raw is! Map) return null;
    return {'sdp': raw['sdp'] as String, 'type': raw['type'] as String};
  }

  factory CallDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return CallDoc(
      id: d.id,
      caller: m['caller'] as String,
      callee: m['callee'] as String,
      kind: CallKind.values.firstWhere(
        (k) => k.name == m['kind'],
        orElse: () => CallKind.audio,
      ),
      status: CallStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => CallStatus.ringing,
      ),
      offer: _sdp(m['offer']),
      answer: _sdp(m['answer']),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (m['expiresAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Firestore side of a call: who is calling whom, the offer and answer, and
/// the network candidates each side finds. Media never goes through here.
class CallSignaling {
  CallSignaling([FirebaseFirestore? db]) : _given = db;
  final FirebaseFirestore? _given;

  /// Resolved on first use, not in the constructor: the app builds a call
  /// controller before it knows whether Firebase is configured, and asking
  /// for the instance too early throws.
  FirebaseFirestore get _db => _given ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String id) =>
      _db.collection('calls').doc(id);

  Future<void> create({
    required String id,
    required String caller,
    required String callee,
    required CallKind kind,
    required Map<String, String> offer,
  }) {
    // Establish the deadline before submitting the write. A queued write's
    // serverTimestamp resolves when connectivity returns, potentially minutes
    // after cancellation, and must never give that old ring a new lifetime.
    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(seconds: 90)),
    );
    return _ref(id).set({
      'caller': caller,
      'callee': callee,
      'kind': kind.name,
      'status': 'ringing',
      'offer': offer,
      'createdAt': FieldValue.serverTimestamp(),
      if (kind != CallKind.sos) 'expiresAt': expiresAt,
    });
  }

  Stream<CallDoc?> watch(String id) =>
      _ref(id).snapshots().map((d) => d.exists ? CallDoc.fromDoc(d) : null);

  Future<CallDoc?> get(String id) async {
    final d = await _ref(id).get();
    return d.exists ? CallDoc.fromDoc(d) : null;
  }

  /// Calls (and SOS live views) currently ringing for [me].
  Stream<List<CallDoc>> ringingFor(String me) => _db
      .collection('calls')
      .where('callee', isEqualTo: me)
      .where('status', isEqualTo: 'ringing')
      .snapshots()
      .map((s) => [for (final d in s.docs) CallDoc.fromDoc(d)]);

  Future<void> answer(String id, Map<String, String> answer) =>
      _ref(id).update({'answer': answer, 'status': 'active'});

  Future<void> setStatus(String id, CallStatus status) => _ref(id).update({
    'status': status.name,
    if (status == CallStatus.ended || status == CallStatus.declined)
      'endedAt': DateTime.now().toIso8601String(),
  });

  Future<void> addCandidate(String id, String from, Map<String, dynamic> c) =>
      _ref(id).collection('candidates').add({'from': from, 'c': jsonEncode(c)});

  /// New candidates from the other side, as they appear.
  Stream<Map<String, dynamic>> candidatesFrom(String id, String other) =>
      _ref(id).collection('candidates').snapshots().expand((s) sync* {
        for (final change in s.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data();
          if (data == null || data['from'] != other) continue;
          yield jsonDecode(data['c'] as String) as Map<String, dynamic>;
        }
      });
}
