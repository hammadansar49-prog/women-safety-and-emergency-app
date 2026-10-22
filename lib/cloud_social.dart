import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'e2ee.dart';
import 'presence_channel.dart';
import 'push_service.dart';
import 'receipt_writer.dart';
import 'social_controller.dart';

typedef _Row = ({String from, String to, String status});

String pairId(String a, String b) =>
    a.compareTo(b) < 0 ? '${a}__$b' : '${b}__$a';

/// Connects a signed-in account to the cloud: friend requests, friendships,
/// SOS permissions and end-to-end encrypted chat. The controller stays the
/// single source the screens read; this class feeds it remote changes and
/// turns the account's own actions ([CloudOp]) into writes.
class CloudSocial {
  CloudSocial(
    this.social, {
    FirebaseFirestore? db,
    PresenceChannel? presence,
    this.e2ee = const E2ee(),
    this.onError,
  }) : _db = db ?? FirebaseFirestore.instance,
       _presence = presence ?? RtdbPresence();

  final SocialController social;
  final FirebaseFirestore _db;

  /// Presence lives in its own store, away from chat and SOS. See
  /// [PresenceChannel] for why.
  final PresenceChannel _presence;
  final E2ee e2ee;
  late final PushService _push = PushService(_db);

  /// Told about problems worth showing, or null once things recover.
  final void Function(String? message)? onError;

  String? _me;
  int _sessionGeneration = 0;

  bool _isCurrent(String me, int generation) =>
      _me == me &&
      _sessionGeneration == generation &&
      social.currentUser.username == me;
  final _subs = <void Function()>[];
  final _chatSubs = <String, void Function()>{};
  final _profileSubs = <String, void Function()>{};
  final _chatSnapshots = <String, QuerySnapshot<Map<String, dynamic>>>{};
  int _graphGen = 0;
  final _peers = <String, ({String name, String pub, String uid})>{};

  /// Profile fetches already running, so a second caller waits for the same
  /// answer instead of being told the key is missing.
  final _inFlight = <String, Future<void>>{};
  final _receipts = ReceiptWriter();

  List<_Row>? _reqFrom, _reqTo, _linkFrom, _linkTo;

  /// SOS events this device sent: id -> recipients. Kept briefly after the
  /// SOS ends so the final "ended here" fix still reaches them.
  final _sosOut = <String, List<String>>{};
  final _sosLastLoc = <String, ({DateTime at, double lat, double lng})>{};

  bool get running => _me != null;

  Future<void> start(String me, String uid) async {
    if (_me == me && social.currentUser.username == me) return;
    final generation = ++_sessionGeneration;
    await _stop();
    if (generation != _sessionGeneration || social.currentUser.username != me) {
      return;
    }
    _me = me;
    social.onCloudOp = (op) {
      if (_isCurrent(me, generation)) _onOp(op);
    };
    // Local key generation is fast; uploading it must never hold every
    // incoming request/message listener behind a network write.
    if (social.identityPriv == null) {
      final id = await e2ee.newIdentity();
      if (!_isCurrent(me, generation)) return;
      social.setIdentity(id.priv, id.pub);
    }
    _openWith = social.openChat;
    social.onChatOpen = setOpenChat;
    social.onTyping = setTyping;
    _listen();
    unawaited(_startPresence(uid));
    _push.register(me).catchError((Object _) {});
    try {
      await _publishIdentity(
        me,
        uid,
        generation,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      if (_isCurrent(me, generation)) {
        onError?.call(
          'Could not reach SafeHer. Chat will connect when you are online.',
        );
        // The write is still queued, so it lands by itself once the network
        // or the backend recovers. Without this the warning would stay up for
        // the rest of the session even though chat had started working again.
        unawaited(
          _publishIdentity(me, uid, generation).then((_) {
            if (_isCurrent(me, generation)) onError?.call(null);
          }).catchError((Object _) {}),
        );
      }
    }
    if (!_isCurrent(me, generation)) return;
  }

  // --- Who is around --------------------------------------------------------

  /// The conversation this account has open, so the other side can show the
  /// dot that says "they are reading this".
  String? _openWith;
  Timer? _presenceExpiry;
  Timer? _typingTimer;
  bool _foreground = true;
  bool _typing = false;
  DateTime? _typingPublished;
  /// Friend username -> the uid whose presence is being watched.
  final _presenceSubs = <String, String>{};

  Future<void> _startPresence(String uid) async {
    _foreground = true;
    // No heartbeat: the presence store marks this device offline by itself
    // if the connection drops, which is both cheaper and more truthful than
    // repeating "still here" every few seconds.
    await _presence.start(uid);
    await _writePresence(online: true);
    _presenceExpiry?.cancel();
    // Typing still goes stale on its own, so a half-finished message does
    // not leave "typing…" on the other screen for ever.
    _presenceExpiry = Timer.periodic(
      const Duration(seconds: 1),
      (_) => social.expireTyping(DateTime.now()),
    );
  }

  /// Called as a chat opens and closes.
  void setOpenChat(String? peer) {
    if (_openWith != peer) setTyping(false);
    _openWith = peer;
    _writePresence(online: _foreground);
    if (_foreground && peer != null) markRead(peer);
  }

  void setTyping(bool typing) {
    _typingTimer?.cancel();
    final next = typing && _foreground && _openWith != null;
    final now = DateTime.now();
    final publish =
        next != _typing ||
        (next &&
            (_typingPublished == null ||
                now.difference(_typingPublished!) >=
                    const Duration(seconds: 1)));
    _typing = next;
    if (publish) {
      _typingPublished = now;
      _writePresence(online: _foreground);
    }
    if (next) {
      _typingTimer = Timer(const Duration(seconds: 3), () => setTyping(false));
    }
  }

  void resume() {
    _foreground = true;
    // A deliberate reconnect can retry a failed receipt; repeated snapshots
    // during an outage must not become an unbounded write loop.
    _receipts.clear();
    _writePresence(online: true);
    if (_openWith != null) markRead(_openWith!);
  }

  /// Called when the app goes to the background or signs out.
  Future<void> goAway() {
    _foreground = false;
    _typing = false;
    _receipts.clear();
    _typingTimer?.cancel();
    return _writePresence(online: false);
  }

  Future<void> _writePresence({required bool online}) {
    if (_me == null) return Future.value();
    return _presence.publish(
      online: online,
      openWith: online ? _openWith : null,
      typing: online && _typing,
    );
  }

  /// One listener per buddy. A heartbeat older than a minute means the app is
  /// gone, whatever the flag says.
  void _watchPresence(Set<String> friends) {
    for (final gone in _presenceSubs.keys.toSet().difference(friends)) {
      final uid = _presenceSubs.remove(gone);
      if (uid != null) _presence.unwatch(uid);
    }
    for (final f in friends) {
      if (_presenceSubs.containsKey(f)) continue;
      // Presence is addressed by uid, so a friend whose profile has not been
      // read yet is simply not watched; _applyGraph runs again once it is.
      final uid = _peers[f]?.uid ?? '';
      if (uid.isEmpty) continue;
      _presenceSubs[f] = uid;
      _presence.watch(uid, (state) {
        social.applyPresence(
          f,
          Presence(
            online: state.online,
            lastSeen: state.lastSeen,
            openWith: state.openWith,
            typing: state.typing,
          ),
        );
      });
    }
  }

  Future<void> stop() async {
    ++_sessionGeneration;
    await _stop();
  }

  Future<void> _stop() async {
    // Cancel and invalidate synchronously, before any network await. A slow
    // presence write must not leave the previous account's listeners alive.
    final away = goAway();
    _me = null;
    social.onCloudOp = null;
    social.onChatOpen = null;
    social.onTyping = null;
    _typingTimer?.cancel();
    _typing = false;
    _presenceExpiry?.cancel();
    _presenceExpiry = null;
    _presenceSubs.clear();
    // Started, not awaited: closing the presence socket is a network round
    // trip, and nothing below it may wait on the network.
    final presenceStopped = _presence.stop();
    _openWith = null;
    for (final cancel in _subs) {
      cancel();
    }
    _subs.clear();
    for (final cancel in _chatSubs.values) {
      cancel();
    }
    _chatSubs.clear();
    for (final cancel in _profileSubs.values) {
      cancel();
    }
    _profileSubs.clear();
    _chatSnapshots.clear();
    _peers.clear();
    _sosOut.clear();
    _sosLastLoc.clear();
    _inFlight.clear();
    _reqFrom = _reqTo = _linkFrom = _linkTo = null;
    // Offline Firestore writes can wait indefinitely. Local cancellation
    // already completed above; do not hold the next account behind cleanup.
    await Future.wait<void>([
      away,
      presenceStopped,
      _push.unregister(),
    ]).timeout(const Duration(seconds: 2), onTimeout: () => <void>[]);
  }

  // --- Identity -------------------------------------------------------------

  Future<void> _publishIdentity(String me, String uid, int generation) async {
    if (social.identityPriv == null) {
      final id = await e2ee.newIdentity();
      if (!_isCurrent(me, generation)) return;
      social.setIdentity(id.priv, id.pub);
    }
    final pub =
        social.identityPub ??
        await e2ee.publicFromPrivate(social.identityPriv!);
    if (!_isCurrent(me, generation)) return;
    final ref = _db.collection('profiles').doc(me);
    final name = social.currentUser.name;
    try {
      await ref.update({'pub': pub, 'name': name});
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') rethrow;
      await ref.set({'uid': uid, 'username': me, 'name': name, 'pub': pub});
    }
  }

  // --- Listening ------------------------------------------------------------

  /// Listens to [make]'s stream and quietly re-subscribes a few seconds after
  /// an error (a rule that was not ready yet, a dropped connection), so one
  /// hiccup can never leave this account deaf. Returns the canceller.
  void Function() _listenRetrying<T>(
    Stream<T> Function() make,
    void Function(T) onData, {
    String? message,
    bool Function()? keep,
  }) {
    final me = _me;
    final generation = _sessionGeneration;
    StreamSubscription<T>? current;
    Timer? retry;
    var stopped = false;
    void subscribe() {
      current = make().listen(
        (data) {
          if (!stopped && me != null && _isCurrent(me, generation)) {
            onData(data);
          }
        },
        onError: (Object _) {
          if (stopped || me == null || !_isCurrent(me, generation)) return;
          if (message != null) onError?.call(message);
          current?.cancel();
          retry = Timer(const Duration(seconds: 3), () {
            if (!stopped &&
                _isCurrent(me, generation) &&
                (keep?.call() ?? true)) {
              subscribe();
            }
          });
        },
      );
    }

    subscribe();
    return () {
      stopped = true;
      retry?.cancel();
      current?.cancel();
    };
  }

  List<_Row> _rows(QuerySnapshot<Map<String, dynamic>> s) => [
    for (final d in s.docs)
      (
        from: d.data()['from'] as String,
        to: d.data()['to'] as String,
        status: (d.data()['status'] as String?) ?? 'pending',
      ),
  ];

  void _listen() {
    final me = _me!;
    void watch(String col, String field, void Function(List<_Row>) set) {
      _subs.add(
        _listenRetrying(
          () => _db.collection(col).where(field, isEqualTo: me).snapshots(),
          (s) {
            set(_rows(s));
            onError?.call(null);
            _applyGraph();
          },
          message: 'Could not sync with SafeHer. Check your connection.',
        ),
      );
    }

    watch('friendReqs', 'from', (r) => _reqFrom = r);
    watch('friendReqs', 'to', (r) => _reqTo = r);
    watch('sosLinks', 'from', (r) => _linkFrom = r);
    watch('sosLinks', 'to', (r) => _linkTo = r);
    _subs.add(
      _listenRetrying(
        () => _db
            .collection('sosAlerts')
            .where('recipient', isEqualTo: me)
            .orderBy('createdAt', descending: true)
            .limit(20)
            .snapshots(includeMetadataChanges: true),
        (s) => social.applyCloudAlerts([
          for (final d in s.docs)
            (
              id: d.id,
              sender: d.data()['sender'] as String,
              status: (d.data()['status'] as String?) ?? 'active',
              createdAt:
                  (d.data()['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              lat: (d.data()['lat'] as num?)?.toDouble(),
              lng: (d.data()['lng'] as num?)?.toDouble(),
              locAt: DateTime.tryParse((d.data()['locAt'] as String?) ?? ''),
              endedAt: DateTime.tryParse(
                (d.data()['endedAt'] as String?) ?? '',
              ),
            ),
        ]),
        message: 'Could not sync alerts. Check your connection.',
      ),
    );
  }

  Future<void> _applyGraph({bool fetchProfiles = true}) async {
    final me = _me;
    if (me == null) return;
    final generation = _sessionGeneration;
    final gen = ++_graphGen;
    // Make sure every person in the graph is known first, then apply the
    // newest lists (not the ones from before the await), and only if no newer
    // update has started in the meantime.
    final snapshotUsers = <String>{
      for (final r in [...?_reqFrom, ...?_reqTo]) ...[r.from, r.to],
      for (final l in [...?_linkFrom, ...?_linkTo]) ...[l.from, l.to],
    }..remove(me);
    if (_reqFrom == null || _reqTo == null) {
      return;
    }
    final reqs = [..._reqFrom!, ..._reqTo!];
    final links = _linkFrom != null && _linkTo != null
        ? [..._linkFrom!, ..._linkTo!]
        : null;
    social.applyCloudGraph(
      mine: me,
      reqs: reqs,
      links: links,
      names: {for (final e in _peers.entries) e.key: e.value.name},
    );
    final friends = [
      for (final r in reqs)
        if (r.status == 'accepted') r.from == me ? r.to : r.from,
    ];
    _watchChats(me, friends);
    _watchPresence(friends.toSet());
    if (fetchProfiles) {
      await Future.wait(
        snapshotUsers.where((u) => !_peers.containsKey(u)).map(_fetchPeer),
      );
      if (_isCurrent(me, generation) && gen == _graphGen) {
        _applyGraph(fetchProfiles: false);
      }
    }
  }

  Future<void> _fetchPeer(String username) {
    final generation = _sessionGeneration;
    final running = _inFlight[username];
    if (running != null) return running;
    final job = () async {
      try {
        final d = await _db.collection('profiles').doc(username).get();
        final data = d.data();
        if (data != null && generation == _sessionGeneration) {
          _peers[username] = (
            name: (data['name'] as String?) ?? username,
            pub: (data['pub'] as String?) ?? '',
            uid: (data['uid'] as String?) ?? '',
          );
        }
      } catch (_) {
        // Offline, or not readable yet; the caller says so in its own words.
      } finally {
        if (generation == _sessionGeneration) _inFlight.remove(username);
      }
    }();
    _inFlight[username] = job;
    return job;
  }

  void _watchChats(String me, List<String> friends) {
    for (final f in friends) {
      if (_chatSubs.containsKey(f)) continue;
      _profileSubs[f] = _listenRetrying(
        () => _db.collection('profiles').doc(f).snapshots(),
        (DocumentSnapshot<Map<String, dynamic>> doc) {
          final data = doc.data();
          if (data == null) return;
          final oldPub = _peers[f]?.pub;
          _peers[f] = (
            name: (data['name'] as String?) ?? f,
            pub: (data['pub'] as String?) ?? '',
            uid: (data['uid'] as String?) ?? '',
          );
          // A profile read for the first time is what makes this friend's
          // presence addressable, so pick it up now rather than next change.
          _watchPresence(_presenceSubs.keys.toSet().union({f}));
          final cached = _chatSnapshots[f];
          if (_peers[f]!.pub.isNotEmpty &&
              oldPub != _peers[f]!.pub &&
              cached != null) {
            _receive(me, f, cached);
          }
        },
      );
      _chatSubs[f] = _listenRetrying(
        () => _db
            .collection('chats')
            .doc(pairId(me, f))
            .collection('messages')
            .orderBy('createdAt')
            .snapshots(includeMetadataChanges: true),
        (s) {
          _chatSnapshots[f] = s;
          _receive(me, f, s);
        },
        // Retries only while they are still friends.
        keep: () => _chatSubs.containsKey(f),
      );
    }
    for (final gone
        in _chatSubs.keys.where((k) => !friends.contains(k)).toList()) {
      _chatSubs.remove(gone)?.call();
      _profileSubs.remove(gone)?.call();
      _chatSnapshots.remove(gone);
    }
  }

  Future<void> _receive(
    String me,
    String friend,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    final generation = _sessionGeneration;
    if (!_isCurrent(me, generation)) return;
    final priv = social.identityPriv;
    if (priv == null) return;
    if (!_peers.containsKey(friend)) await _fetchPeer(friend);
    if (!_isCurrent(me, generation)) return;
    final pub = _peers[friend]?.pub ?? '';
    if (pub.isEmpty) return;
    final known = social.loadedMessageIds;
    final incoming = <ChatMessage>[];
    for (final d in snap.docs) {
      if (!_isCurrent(me, generation)) return;
      final data = d.data();
      final from = data['from'] as String;
      if (from == me) {
        // My own message: carry back whatever they have stamped on it.
        social.applyReceipt(
          d.id,
          delivered: (data['deliveredAt'] as Timestamp?)?.toDate(),
          read: (data['readAt'] as Timestamp?)?.toDate(),
        );
      } else {
        if (known.contains(d.id) && !d.metadata.hasPendingWrites) {
          _stamp(
            d.reference,
            data,
            reading: _foreground && _openWith == friend,
          );
        }
      }
      if (known.contains(d.id)) continue;
      final mine = from == me;
      final at = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final sealedVoice = data['voice'] as String?;
      final sealedPhoto = data['photo'] as String?;

      if (sealedVoice != null || sealedPhoto != null) {
        Uint8List? audio;
        try {
          audio = await e2ee.decryptBytes(
            myPriv: priv,
            theirPub: pub,
            pair: pairId(me, friend),
            sealed: sealedVoice ?? sealedPhoto!,
          );
        } on DecryptFailure {
          audio = null;
        }
        if (!_isCurrent(me, generation)) return;
        if (!mine && audio != null) {
          _stamp(
            d.reference,
            data,
            reading: _foreground && _openWith == friend,
          );
        }
        incoming.add(
          ChatMessage(
            id: d.id,
            senderId: mine ? social.currentUserId : friend,
            recipientId: mine ? friend : social.currentUserId,
            text: audio == null
                ? 'This attachment could not be unlocked on this device.'
                : '',
            createdAt: at,
            kind: audio == null
                ? MessageKind.text
                : (sealedPhoto != null ? MessageKind.photo : MessageKind.voice),
            audio: sealedPhoto == null ? audio : null,
            photo: sealedPhoto == null ? null : audio,
            seconds: (data['secs'] as num?)?.toInt() ?? 0,
          ),
        );
        continue;
      }

      String text;
      var unlocked = true;
      try {
        text = await e2ee.decrypt(
          myPriv: priv,
          theirPub: pub,
          pair: pairId(me, friend),
          sealed: data['ct'] as String,
        );
      } on DecryptFailure {
        unlocked = false;
        text = 'This message could not be unlocked on this device.';
      }
      if (!_isCurrent(me, generation)) return;
      if (!mine && unlocked) {
        _stamp(d.reference, data, reading: _foreground && _openWith == friend);
      }
      incoming.add(
        ChatMessage(
          id: d.id,
          senderId: mine ? social.currentUserId : friend,
          recipientId: mine ? friend : social.currentUserId,
          text: text,
          createdAt: at,
        ),
      );
    }
    if (_isCurrent(me, generation)) social.applyCloudMessages(incoming);
  }

  /// Marks a message delivered as soon as this device has it, and read once
  /// its conversation is the one on screen. Receipts carry no message content.
  void _stamp(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data, {
    required bool reading,
  }) {
    _receipts.stamp(
      ref.path,
      delivered: data['deliveredAt'] != null,
      read: data['readAt'] != null,
      reading: reading,
      write: ({required bool delivered, required bool read}) => ref.update({
        if (delivered) 'deliveredAt': FieldValue.serverTimestamp(),
        if (read) 'readAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Re-stamps everything in the open conversation as read, for messages that
  /// arrived before it was opened.
  Future<void> markRead(String friend) async {
    final me = _me;
    if (me == null || !_foreground || _openWith != friend) return;
    final generation = _sessionGeneration;
    try {
      final snap = await _db
          .collection('chats')
          .doc(pairId(me, friend))
          .collection('messages')
          .where('to', isEqualTo: me)
          .get();
      if (!_isCurrent(me, generation) || !_foreground || _openWith != friend) {
        return;
      }
      final loaded = social.loadedMessageIds;
      for (final d in snap.docs) {
        if (loaded.contains(d.id) && !d.metadata.hasPendingWrites) {
          _stamp(d.reference, d.data(), reading: true);
        }
      }
    } catch (_) {}
  }

  // --- Writing --------------------------------------------------------------

  void _onOp(CloudOp op) {
    final me = _me;
    if (me == null) return;
    final generation = _sessionGeneration;
    _write(me, op).catchError((Object e) {
      if (!_isCurrent(me, generation)) return;
      onError?.call(
        e is FirebaseException && e.code == 'resource-exhausted'
            ? 'SafeHer has reached its service limit. Messages and alerts may be delayed.'
            : e is FirebaseException && e.code == 'permission-denied'
            ? 'That was not allowed.'
            : 'Could not reach SafeHer. Try again when you are online.',
      );
    });
  }

  Future<void> _write(String me, CloudOp op) async {
    final peer = op.peer;
    final pair = _db.collection('friendReqs').doc(pairId(me, peer));
    switch (op.kind) {
      case 'request':
        await pair.set({
          'from': me,
          'to': peer,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      case 'accept':
        await pair.update({'status': 'accepted'});
      case 'unfriend':
        await pair.delete();
      case 'link':
        await _db.collection('sosLinks').doc('${me}__$peer').set({
          'from': me,
          'to': peer,
          'status': 'pending',
        });
      case 'unlink':
        await _db.collection('sosLinks').doc('${me}__$peer').delete();
        // Withdraw anything already sent to a buddy who is no longer one.
        final sent = await _db
            .collection('sosAlerts')
            .where('sender', isEqualTo: me)
            .where('recipient', isEqualTo: peer)
            .get();
        for (final d in sent.docs) {
          await d.reference.delete();
        }
      case 'sosStart':
        await _sosStart(me, op);
      case 'sosLoc':
        await _sosLocation(op);
      case 'sosEnd':
        await _sosEnd(op);
      case 'approve':
        await _db.collection('sosLinks').doc('${peer}__$me').update({
          'status': 'approved',
        });
      case 'revoke':
        await _db.collection('sosLinks').doc('${peer}__$me').delete();
      case 'message':
        await _sendMessage(me, op);
      case 'voice':
        await _sendVoice(me, op);
      case 'photo':
        await _sendVoice(me, op);
    }
  }

  DocumentReference<Map<String, dynamic>> _alert(String event, String to) =>
      _db.collection('sosAlerts').doc('${event}_$to');

  Future<void> _sosStart(String me, CloudOp op) async {
    final event = op.id!;
    final to = op.text!.split(',').where((r) => r.isNotEmpty).toList();
    _sosOut[event] = to;
    await Future.wait([
      for (final r in to)
        _alert(event, r).set({
          'sender': me,
          'recipient': r,
          'eventId': event,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        }),
    ]);
  }

  Future<void> _sosLocation(CloudOp op) async {
    final event = op.id!;
    final to = _sosOut[event];
    if (to == null) return;
    final parts = op.text!.split(',');
    final lat = double.parse(parts[0]);
    final lng = double.parse(parts[1]);
    final last = _sosLastLoc[event];
    final now = DateTime.now();
    if (last != null && !_ended.contains(event) && !sosFixIsWorthSending(last, now, lat, lng)) {
      return;
    }
    _sosLastLoc[event] = (at: now, lat: lat, lng: lng);
    await Future.wait([
      for (final r in to)
        _alert(event, r).update({
          'lat': lat,
          'lng': lng,
          'locAt': parts[2],
        }),
    ]);
  }


  final _ended = <String>{};

  Future<void> _sosEnd(CloudOp op) async {
    final event = op.id!;
    final to = _sosOut[event];
    if (to == null) return;
    _ended.add(event);
    await Future.wait([
      for (final r in to)
        _alert(event, r).update({
          'status': op.text,
          'endedAt': DateTime.now().toIso8601String(),
        }),
    ]);
    // Leave a little time for the final "ended here" position to follow.
    Timer(const Duration(seconds: 60), () {
      _sosOut.remove(event);
      _sosLastLoc.remove(event);
      _ended.remove(event);
    });
  }

  Future<void> _sendMessage(String me, CloudOp op) async {
    final generation = _sessionGeneration;
    if (!_isCurrent(me, generation)) return;
    final priv = social.identityPriv;
    final peer = op.peer;
    if (!_peers.containsKey(peer) || _peers[peer]!.pub.isEmpty) {
      _peers.remove(peer);
      await _fetchPeer(peer);
    }
    if (!_isCurrent(me, generation)) return;
    final pub = _peers[peer]?.pub ?? '';
    if (pub.isEmpty || priv == null) {
      onError?.call(
        '@$peer has not turned on private chat yet. Ask them to open SafeHer.',
      );
      return;
    }
    final sealed = await e2ee.encrypt(
      myPriv: priv,
      theirPub: pub,
      pair: pairId(me, peer),
      text: op.text!,
    );
    if (!_isCurrent(me, generation)) return;
    await _db
        .collection('chats')
        .doc(pairId(me, peer))
        .collection('messages')
        .doc(op.id)
        .set({
          'from': me,
          'to': peer,
          'ct': sealed,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// A voice note travels the same way text does: sealed for this one
  /// conversation, so the relay only ever holds noise.
  Future<void> _sendVoice(String me, CloudOp op) async {
    final generation = _sessionGeneration;
    if (!_isCurrent(me, generation)) return;
    final priv = social.identityPriv;
    final peer = op.peer;
    if (!_peers.containsKey(peer) || _peers[peer]!.pub.isEmpty) {
      _peers.remove(peer);
      await _fetchPeer(peer);
    }
    if (!_isCurrent(me, generation)) return;
    final pub = _peers[peer]?.pub ?? '';
    if (pub.isEmpty || priv == null) {
      onError?.call(
        'Could not send the voice note: @$peer has not turned on private '
        'chat yet. Ask them to open SafeHer.',
      );
      return;
    }
    final sealed = await e2ee.encryptBytes(
      myPriv: priv,
      theirPub: pub,
      pair: pairId(me, peer),
      bytes: op.photo ?? op.audio!,
    );
    if (!_isCurrent(me, generation)) return;
    await _db
        .collection('chats')
        .doc(pairId(me, peer))
        .collection('messages')
        .doc(op.id)
        .set({
          'from': me,
          'to': peer,
          if (op.kind == 'photo') 'photo': sealed else 'voice': sealed,
          if (op.kind != 'photo') 'secs': op.seconds,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}

/// Which fixes from an SOS's live stream are worth a write.
///
/// Every published fix costs one write per SOS buddy, so an SOS left running
/// is by far the most expensive thing this app does. Movement comes first:
/// someone being driven away is updated as often as the floor allows, while
/// someone sitting still is still reported regularly, because "she has not
/// moved" is itself something a buddy needs to go on seeing.
bool sosFixIsWorthSending(
  ({DateTime at, double lat, double lng}) last,
  DateTime now,
  double lat,
  double lng,
) {
  final since = now.difference(last.at);
  if (since < const Duration(seconds: 8)) return false;
  if (since >= const Duration(seconds: 20)) return true;
  return metresBetween(last.lat, last.lng, lat, lng) >= 20;
}

/// Flat-earth distance. Over the few tens of metres this decides on it is
/// accurate to well under a metre, and needs no trigonometry per fix.
double metresBetween(double lat1, double lng1, double lat2, double lng2) {
  const perDegree = 111320.0;
  final dLat = (lat2 - lat1) * perDegree;
  final dLng = (lng2 - lng1) * perDegree * math.cos(lat1 * math.pi / 180);
  return math.sqrt(dLat * dLat + dLng * dLng);
}
