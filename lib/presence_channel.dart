import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

/// What one account is doing right now, as the presence store holds it.
class PresenceState {
  const PresenceState({
    required this.online,
    this.lastSeen,
    this.openWith,
    this.typing = false,
  });

  final bool online;
  final DateTime? lastSeen;
  final String? openWith;
  final bool typing;
}

/// Where "who is online" lives.
///
/// This is deliberately separate from the rest of the backend. Presence is
/// the chattiest thing the app does and the least important: losing it costs
/// a green dot, while losing a message or an SOS costs far more. Keeping it
/// in its own store means a presence outage can never take chat or SOS with
/// it, and its traffic can never eat the quota they depend on.
abstract class PresenceChannel {
  /// Begins publishing for [uid] and arranges for the store to mark it
  /// offline by itself if this device disappears without saying goodbye.
  Future<void> start(String uid);

  Future<void> publish({
    required bool online,
    String? openWith,
    required bool typing,
  });

  void watch(String uid, void Function(PresenceState) onState);
  void unwatch(String uid);
  Future<void> stop();
}

/// Presence on the Firebase Realtime Database.
///
/// The Realtime Database is used rather than Firestore for one reason:
/// `onDisconnect`. The server itself writes the "offline" record when the
/// socket drops, so there is no heartbeat to send. That removes thousands of
/// writes a day per device, and it is also more accurate than a heartbeat,
/// which can only ever say "online as of some seconds ago".
class RtdbPresence implements PresenceChannel {
  RtdbPresence([FirebaseDatabase? db]) : _given = db;
  final FirebaseDatabase? _given;

  /// Resolved on first use: the app builds its backend before it knows
  /// whether Firebase is configured, and asking too early throws.
  FirebaseDatabase get _db => _given ?? FirebaseDatabase.instance;

  DatabaseReference? _mine;
  StreamSubscription<DatabaseEvent>? _connection;
  final _watchers = <String, StreamSubscription<DatabaseEvent>>{};

  bool _online = false;
  bool _typing = false;
  String? _openWith;

  @override
  Future<void> start(String uid) async {
    await stop();
    final mine = _db.ref('presence/$uid');
    _mine = mine;
    _online = true;
    // Re-arm on every reconnection: an onDisconnect registration belongs to
    // one socket, so it is spent once it fires and must be set up again.
    _connection = _db.ref('.info/connected').onValue.listen((event) async {
      if (event.snapshot.value != true || !identical(_mine, mine)) return;
      try {
        await mine.onDisconnect().set({
          'online': false,
          'at': ServerValue.timestamp,
        });
        await mine.set(_payload());
      } catch (_) {
        // Presence is a nicety; it must never interrupt anything.
      }
    }, onError: (Object _) {});
  }

  Map<String, Object?> _payload() => {
    'online': _online,
    'at': ServerValue.timestamp,
    'typing': _online && _typing,
    if (_online && _openWith != null) 'openWith': _openWith,
  };

  @override
  Future<void> publish({
    required bool online,
    String? openWith,
    required bool typing,
  }) async {
    _online = online;
    _openWith = openWith;
    _typing = typing;
    final mine = _mine;
    if (mine == null) return;
    try {
      await mine.set(_payload());
    } catch (_) {
      // See start(): a presence write is never worth surfacing.
    }
  }

  @override
  void watch(String uid, void Function(PresenceState) onState) {
    if (_watchers.containsKey(uid)) return;
    try {
      _watchers[uid] = _db
          .ref('presence/$uid')
          .onValue
          .listen(
            (event) => onState(readSnapshot(event.snapshot.value)),
            // A store that cannot be read shows nothing at all. Saying
            // "last seen 3 hours ago" when that is merely the last thing
            // this device managed to read would be worse than silence.
            onError: (Object _) =>
                onState(const PresenceState(online: false)),
          );
    } catch (_) {
      onState(const PresenceState(online: false));
    }
  }

  /// Exposed for tests: turns one stored record into presence.
  static PresenceState readSnapshot(Object? value) {
    if (value is! Map) return const PresenceState(online: false);
    final at = value['at'];
    return PresenceState(
      online: value['online'] == true,
      lastSeen: at is int
          ? DateTime.fromMillisecondsSinceEpoch(at)
          : null,
      openWith: value['openWith'] as String?,
      typing: value['online'] == true && value['typing'] == true,
    );
  }

  @override
  void unwatch(String uid) {
    unawaited(_watchers.remove(uid)?.cancel());
  }

  @override
  Future<void> stop() async {
    final mine = _mine;
    _mine = null;
    final connection = _connection;
    _connection = null;
    final watchers = _watchers.values.toList();
    _watchers.clear();
    await connection?.cancel();
    for (final w in watchers) {
      await w.cancel();
    }
    if (mine == null) return;
    try {
      // Signing out is a goodbye this device can say for itself, so cancel
      // the standing one before it can fire for a session that has ended.
      await mine.onDisconnect().cancel();
      await mine.set({'online': false, 'at': ServerValue.timestamp});
    } catch (_) {
      // Already offline, or unreachable; the server's own onDisconnect
      // covers the case where this never arrives.
    }
  }
}
