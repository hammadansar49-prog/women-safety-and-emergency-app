import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

@immutable
class DemoPerson {
  const DemoPerson({
    required this.id,
    required this.name,
    required this.username,
  });
  final String id;
  final String name;
  final String username;
}

@immutable
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromId,
    required this.toId,
  });
  final String id;
  final String fromId;
  final String toId;
}

@immutable
class SosContactRequest {
  const SosContactRequest({required this.senderId, required this.recipientId});
  final String senderId;
  final String recipientId;
}

/// What a row in a conversation is. Calls leave a trace in the chat the same
/// way they do in a phone's call log, so a missed one is not silent.
enum MessageKind { text, voice, missedVoiceCall, missedVideoCall, photo }

/// How far one of your own messages has travelled.
enum MessageStatus { sent, delivered, read }

/// Whether someone has SafeHer open, when they last did, and which
/// conversation they are reading. Never carries message content.
@immutable
class Presence {
  const Presence({
    this.online = false,
    this.lastSeen,
    this.openWith,
    this.typing = false,
  });
  final bool online;
  final DateTime? lastSeen;

  /// The username whose chat they have open, when they are in one.
  final String? openWith;
  final bool typing;

  bool readingWith(String id) => online && openWith == id;

  /// "online", "last seen today at 9:04 PM", or nothing when never seen.
  String get label {
    if (online) return 'online';
    final at = lastSeen?.toLocal();
    if (at == null) return '';
    final now = DateTime.now();
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final clock =
        '$hour:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'AM' : 'PM'}';
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    if (sameDay) return 'last seen today at $clock';
    final y = now.subtract(const Duration(days: 1));
    if (at.year == y.year && at.month == y.month && at.day == y.day) {
      return 'last seen yesterday at $clock';
    }
    return 'last seen ${at.day}/${at.month} at $clock';
  }
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.createdAt,
    this.kind = MessageKind.text,
    this.audio,
    this.photo,
    this.seconds = 0,
  });
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  final DateTime createdAt;
  final MessageKind kind;

  /// The decoded voice note, held only in memory.
  final Uint8List? audio;
  final Uint8List? photo;
  final int seconds;

  bool get isVoice => kind == MessageKind.voice;
  bool get isCall =>
      kind == MessageKind.missedVoiceCall ||
      kind == MessageKind.missedVideoCall;
}

enum LocalSosStatus { active, cancelled, resolved }

@immutable
class LocalSosEvent {
  LocalSosEvent({
    required this.id,
    required this.senderId,
    required List<String> recipientIds,
    required this.status,
    required this.createdAt,
    this.lastLat,
    this.lastLng,
    this.lastLocationAt,
    this.endedAt,
  }) : recipientIds = List.unmodifiable(recipientIds);
  final String id;
  final String senderId;
  final List<String> recipientIds;
  final LocalSosStatus status;
  final DateTime createdAt;

  /// The most recent live position while the SOS runs; once it ends this is
  /// the "ended here" point.
  final double? lastLat;
  final double? lastLng;
  final DateTime? lastLocationAt;

  /// When the SOS stopped (null while active).
  final DateTime? endedAt;

  LocalSosEvent copyWith({
    LocalSosStatus? status,
    double? lastLat,
    double? lastLng,
    DateTime? lastLocationAt,
    DateTime? endedAt,
  }) => LocalSosEvent(
    id: id,
    senderId: senderId,
    recipientIds: recipientIds,
    status: status ?? this.status,
    createdAt: createdAt,
    lastLat: lastLat ?? this.lastLat,
    lastLng: lastLng ?? this.lastLng,
    lastLocationAt: lastLocationAt ?? this.lastLocationAt,
    endedAt: endedAt ?? this.endedAt,
  );
}

/// Something the account did that other devices must hear about. Fired after
/// the local change; the cloud layer turns it into a write.
@immutable
class CloudOp {
  const CloudOp(
    this.kind,
    this.peer, {
    this.id,
    this.text,
    this.audio,
    this.photo,
    this.seconds = 0,
  });

  /// request, unfriend, accept, link (my SOS ask to peer), unlink (my ask),
  /// approve (peer's ask to me), revoke (delete peer's ask to me), message,
  /// voice.
  final String kind;
  final String peer;
  final String? id;
  final String? text;

  /// Set for a voice note, alongside its length.
  final Uint8List? audio;
  final Uint8List? photo;
  final int seconds;
}

/// Local account state. Persistence is injected; the cloud layer (if any)
/// listens through [onCloudOp] and feeds remote changes back with the
/// `applyCloud...` methods.
class SocialController extends ChangeNotifier {
  SocialController({bool newAccount = false}) {
    if (newAccount) {
      _profiles[0] = const DemoPerson(
        id: 'hammad',
        name: 'Hammad',
        username: '',
      );
    }
  }
  SocialController.authenticated({required String uid, required String name}) {
    _profiles.clear();
    _profiles.add(
      DemoPerson(
        id: uid,
        name: name.isEmpty ? 'SafeHer user' : name,
        username: '',
      ),
    );
    _currentUserId = uid;
    signedIn = true;
    _lockedIdentity = true;
  }
  bool _lockedIdentity = false;

  /// Set when this account is connected to the cloud.
  void Function(CloudOp op)? onCloudOp;
  void _emit(CloudOp op) => onCloudOp?.call(op);

  // --- Chat identity (X25519). The private half stays in the snapshot, which
  // is only ever stored on the device or sealed in the encrypted backup.
  String? identityPriv;
  String? identityPub;
  void setIdentity(String priv, String pub) {
    identityPriv = priv;
    identityPub = pub;
    notifyListeners();
  }

  bool get cloudConnected => onCloudOp != null;
  String? get email => null;
  Future<LocalSosEvent> activateSos() async => createSos();
  Future<void> lookupUsername(String value) async {}
  factory SocialController.fromSnapshot(String value) {
    final c = SocialController();
    c._apply(value);
    return c;
  }

  void _apply(String value) {
    final m = jsonDecode(value) as Map<String, dynamic>;
    if (m['version'] != 1) {
      throw const FormatException('Unsupported saved data');
    }
    _wipe();
    _profiles.clear();
    for (final p in m['profiles']) {
      _profiles.add(
        DemoPerson(id: p['id'], name: p['name'], username: p['username']),
      );
    }
    _currentUserId = m['current'];
    person(_currentUserId);
    _sequence = m['sequence'];
    signedIn = m['signedIn'];
    appearanceChosen = m['appearanceChosen'] == true;
    // The baby pink light design is the default until the user picks otherwise.
    appearance = appearanceChosen ? (m['appearance'] ?? 'light') : 'light';
    countdown = m['countdown'] ?? 5;
    shortcutKey = m['shortcutKey'] == 'volumeDown' ? 'volumeDown' : 'volumeUp';
    identityPriv = m['idPriv'] as String?;
    identityPub = m['idPub'] as String?;
    _pinSalt = m['pinSalt'] as String?;
    _pinHash = m['pinHash'] as String?;
    guideSeen = m['guideSeen'] == true;
    _photos.addAll(Map<String, String>.from(m['photos']));
    _friendships.addAll(List<String>.from(m['friends']));
    _favorites.addAll(List<String>.from(m['favorites']));
    _approved.addAll(List<String>.from(m['approved']));
    _pendingConsent.addAll(List<String>.from(m['pending']));
    for (final r in m['requests']) {
      _requests.add(
        FriendRequest(id: r['id'], fromId: r['from'], toId: r['to']),
      );
    }
    for (final r in m['messages']) {
      final audio = r['audio'] as String?;
      final photo = r['photo'] as String?;
      _messages.add(
        ChatMessage(
          id: r['id'],
          senderId: r['from'],
          recipientId: r['to'],
          text: r['text'],
          createdAt: DateTime.parse(r['time']),
          kind: MessageKind.values.firstWhere(
            (k) => k.name == r['kind'],
            orElse: () => MessageKind.text,
          ),
          audio: audio == null ? null : base64Decode(audio),
          photo: photo == null ? null : base64Decode(photo),
          seconds: (r['secs'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    for (final r in m['events']) {
      _events.add(
        LocalSosEvent(
          id: r['id'],
          senderId: r['from'],
          recipientIds: List<String>.from(r['to']),
          status: LocalSosStatus.values.byName(r['status']),
          createdAt: DateTime.parse(r['time']),
          lastLat: (r['lat'] as num?)?.toDouble(),
          lastLng: (r['lng'] as num?)?.toDouble(),
          lastLocationAt: r['locAt'] == null
              ? null
              : DateTime.parse(r['locAt']),
          endedAt: r['endedAt'] == null ? null : DateTime.parse(r['endedAt']),
        ),
      );
    }
  }

  // --- PIN lock (per account; only a salted hash is kept) ------------------
  String? _pinSalt;
  String? _pinHash;
  bool guideSeen = false;

  bool get hasPin => _pinHash != null;

  static String _pinDigest(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  void setPin(String pin) {
    final r = Random.secure();
    _pinSalt = base64Url.encode(List.generate(16, (_) => r.nextInt(256)));
    _pinHash = _pinDigest(_pinSalt!, pin);
    notifyListeners();
  }

  void clearPin() {
    _pinSalt = null;
    _pinHash = null;
    notifyListeners();
  }

  bool checkPin(String pin) =>
      _pinHash != null && _pinDigest(_pinSalt!, pin) == _pinHash;

  void markGuideSeen() {
    guideSeen = true;
    notifyListeners();
  }

  /// Forgets everything held in memory, back to a blank, signed-out device.
  /// Appearance is a device preference and survives.
  void _wipe() {
    onCloudOp = null;
    onChatOpen = null;
    onTyping = null;
    openChat = null;
    syncError = null;
    _profiles
      ..clear()
      ..add(const DemoPerson(id: 'hammad', name: 'Hammad', username: ''));
    _currentUserId = 'hammad';
    _sequence = 0;
    signedIn = false;
    countdown = 5;
    shortcutKey = 'volumeUp';
    _pinSalt = null;
    _pinHash = null;
    identityPriv = null;
    identityPub = null;
    guideSeen = false;
    _photos.clear();
    _friendships.clear();
    _favorites.clear();
    _approved.clear();
    _pendingConsent.clear();
    _requests.clear();
    _messages.clear();
    _events.clear();
  }

  /// The key this account's data is stored under on this device. Null while
  /// nobody is signed in (or a brand new Google account has no username yet),
  /// in which case nothing account-specific is written anywhere.
  String? accountKey;

  /// Per-account writer: (key, snapshot). Always called with the key the
  /// snapshot belongs to, so an account switch can never cross the streams.
  Future<void> Function(String key, String data)? persistAccount;

  /// Switches to [key]'s own data ([snapshot], or a blank account). Whatever
  /// the previous account had is dropped from memory first.
  void enterAccount(
    String key,
    String? snapshot, {
    required String name,
    String username = '',
  }) {
    if (snapshot != null) {
      final saved = SocialController.fromSnapshot(snapshot);
      final expected = username.isEmpty ? key : username;
      final matches = saved.currentUser.username == expected;
      saved.dispose();
      if (!matches) {
        throw const FormatException('Saved data belongs to another account.');
      }
    }
    accountKey = null;
    _wipe();
    if (snapshot != null) {
      _apply(snapshot);
    } else {
      _profiles[0] = DemoPerson(
        id: 'hammad',
        name: name.isEmpty
            ? (username.isEmpty ? 'SafeHer user' : username)
            : name,
        username: username,
      );
    }
    accountKey = key;
    notifyListeners();
  }

  /// Starts a signed-in account that has no username yet (new Google user).
  void enterUnnamedAccount({required String name}) {
    accountKey = null;
    _wipe();
    if (name.isNotEmpty) {
      _profiles[0] = DemoPerson(id: 'hammad', name: name, username: '');
    }
    signedIn = true;
    notifyListeners();
  }

  /// Attaches the freshly claimed username as the storage key.
  void bindAccountKey(String key) {
    accountKey = key;
    notifyListeners();
  }

  /// Leaves the account: its data stays on disk under its own key, but nothing
  /// of it remains in memory for the next person to see.
  void leaveAccount() {
    accountKey = null;
    _wipe();
    notifyListeners();
  }

  void setName(String value) {
    final name = value.trim();
    if (name.isEmpty) return;
    final index = _profiles.indexWhere((p) => p.id == currentUserId);
    if (index == -1) return;
    final old = _profiles[index];
    _profiles[index] = DemoPerson(
      id: old.id,
      name: name,
      username: old.username,
    );
    notifyListeners();
  }

  String snapshot() {
    final keepAudio = _audioToKeep();
    return jsonEncode({
      'version': 1,
      'current': currentUserId,
      'sequence': _sequence,
      'signedIn': signedIn,
      'appearance': appearance,
      'appearanceChosen': appearanceChosen,
      'countdown': countdown,
      'shortcutKey': shortcutKey,
      'idPriv': identityPriv,
      'idPub': identityPub,
      'pinSalt': _pinSalt,
      'pinHash': _pinHash,
      'guideSeen': guideSeen,
      'photos': _photos,
      'profiles': [
        for (final p in profiles)
          {'id': p.id, 'name': p.name, 'username': p.username},
      ],
      'friends': _friendships.toList(),
      'favorites': _favorites.toList(),
      'approved': _approved.toList(),
      'pending': _pendingConsent.toList(),
      'requests': [
        for (final r in _requests) {'id': r.id, 'from': r.fromId, 'to': r.toId},
      ],
      'messages': [
        for (final r in _messages)
          {
            'id': r.id,
            'from': r.senderId,
            'to': r.recipientId,
            'text': r.text,
            'time': r.createdAt.toIso8601String(),
            if (r.kind != MessageKind.text) 'kind': r.kind.name,
            // Only the newest voice notes keep their audio on this device, so a
            // long conversation cannot grow the vault without limit. Older ones
            // come back from the relay, still sealed, when it is reachable.
            if (r.audio != null && keepAudio.contains(r.id))
              'audio': base64Encode(r.audio!),
            if (r.photo != null && keepAudio.contains(r.id))
              'photo': base64Encode(r.photo!),
            if (r.seconds > 0) 'secs': r.seconds,
          },
      ],
      'events': [
        for (final r in _events)
          {
            'id': r.id,
            'from': r.senderId,
            'to': r.recipientIds,
            'status': r.status.name,
            'time': r.createdAt.toIso8601String(),
            'lat': r.lastLat,
            'lng': r.lastLng,
            'locAt': r.lastLocationAt?.toIso8601String(),
            'endedAt': r.endedAt?.toIso8601String(),
          },
      ],
    });
  }

  Future<void> Function(String)? persist;
  Future<void> _pendingSave = Future.value();
  String? saveError;
  bool saving = false;
  bool _disposed = false;
  int _saveRevision = 0;
  bool signedIn = false;
  String appearance = 'light';
  bool appearanceChosen = false;
  int countdown = 5;
  String shortcutKey = 'volumeUp';
  void setShortcutKey(String value) {
    if (!['volumeUp', 'volumeDown'].contains(value)) return;
    shortcutKey = value;
    notifyListeners();
  }

  final Map<String, String> _photos = {};
  String? photoFor(String id) => _photos[id];
  void setPhoto(String? value) {
    if (value == null) {
      _photos.remove(currentUserId);
    } else {
      _photos[currentUserId] = value;
    }
    notifyListeners();
  }

  void setSignedIn(bool value) {
    signedIn = value;
    notifyListeners();
  }

  /// Sign out and release this device's identity so the next sign-in starts
  /// clean: the username is cleared (so it can be claimed again), and the
  /// account is signed out. Without this, logging out and back in would silently
  /// reuse the previous username instead of showing the login screen.
  void signOut() => leaveAccount();

  void setAppearance(String value) {
    appearance = value;
    appearanceChosen = true;
    notifyListeners();
  }

  void setCountdown(int value) {
    countdown = value;
    notifyListeners();
  }

  void retrySave() => notifyListeners();
  Future<void> flush() async {
    await _pendingSave;
    if (saveError != null) throw StateError(saveError!);
  }

  @override
  void notifyListeners() {
    ++_durableRevision;
    final write = persist;
    final keyed = persistAccount;
    final key = accountKey;
    if (write != null || (keyed != null && key != null)) {
      final data = snapshot();
      final revision = ++_saveRevision;
      saving = true;
      _pendingSave = _pendingSave.then((_) async {
        try {
          if (write != null) await write(data);
          if (keyed != null && key != null) await keyed(key, data);
          if (revision == _saveRevision) saveError = null;
        } catch (_) {
          if (revision == _saveRevision) {
            saveError =
                'Could not save on this device. Retry before closing the app.';
          }
        } finally {
          if (revision == _saveRevision) {
            saving = false;
            if (!_disposed) super.notifyListeners();
          }
        }
      });
    }
    super.notifyListeners();
  }

  int _durableRevision = 0;

  /// Increases only for account/device changes, not ephemeral live hints.
  int get durableRevision => _durableRevision;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  final List<DemoPerson> _profiles = [
    DemoPerson(id: 'hammad', name: 'Hammad', username: 'hammad'),
    DemoPerson(id: 'ayesha', name: 'Ayesha', username: 'ayesha'),
    DemoPerson(id: 'sara', name: 'Sara', username: 'sara'),
  ];
  List<DemoPerson> get profiles => List.unmodifiable(_profiles);

  String? usernameError(String input) {
    final username = input.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
      return 'Use 3–20 letters, numbers or underscores.';
    }
    if (_profiles.any((p) => p.username.toLowerCase() == username)) {
      return 'This username is already taken. Try another.';
    }
    return null;
  }

  void claimUsername(String input) {
    if (currentUser.username.isNotEmpty) {
      throw StateError('Your username is already set.');
    }
    final error = usernameError(input);
    if (error != null) throw StateError(error);
    final index = _profiles.indexWhere((p) => p.id == currentUserId);
    _profiles[index] = DemoPerson(
      id: currentUserId,
      name: currentUser.name,
      username: input.trim().toLowerCase(),
    );
    accountKey ??= input.trim().toLowerCase();
    notifyListeners();
  }

  String _currentUserId = 'hammad';
  String get currentUserId => _currentUserId;
  DemoPerson get currentUser => person(currentUserId);
  int _sequence = 0;
  String _id() => '${++_sequence}';

  /// Message ids are shared with the cloud copy, so they must not repeat
  /// across devices.
  String _messageId() {
    final r = Random.secure();
    final tail = List.generate(
      6,
      (_) => r.nextInt(36).toRadixString(36),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$tail';
  }

  final List<FriendRequest> _requests = [];
  final Set<String> _friendships = {};
  final Set<String> _favorites = {};
  final Set<String> _approved = {};
  final Set<String> _pendingConsent = {};
  final List<ChatMessage> _messages = [];
  final List<LocalSosEvent> _events = [];

  String _directed(String a, String b) => '$a>$b';
  String _pair(String a, String b) => a.compareTo(b) < 0 ? '$a:$b' : '$b:$a';
  DemoPerson person(String id) => profiles.firstWhere(
    (p) => p.id == id,
    orElse: () => throw StateError('Unknown account.'),
  );
  void switchProfile(String id) {
    if (_lockedIdentity) throw StateError('Sign out to change accounts.');
    person(id);
    if (id == _currentUserId) return;
    _currentUserId = id;
    notifyListeners();
  }

  List<DemoPerson> get friends => List.unmodifiable(
    profiles.where(
      (p) => p.id != currentUserId && areFriends(currentUserId, p.id),
    ),
  );

  /// Adds an account found through cloud search so it can be requested,
  /// reusing the existing entry when it is already known.
  DemoPerson adoptRemote(String id, String username) {
    final existing = _profiles.indexWhere((p) => p.id == id);
    if (existing != -1) return _profiles[existing];
    final person = DemoPerson(id: id, name: username, username: username);
    _profiles.add(person);
    notifyListeners();
    return person;
  }

  List<DemoPerson> search(String query) {
    final term = query.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
    return List.unmodifiable(
      term.isEmpty
          ? <DemoPerson>[]
          : profiles.where(
              (p) =>
                  p.id != currentUserId &&
                  p.username.toLowerCase().startsWith(term),
            ),
    );
  }

  bool areFriends(String a, String b) => _friendships.contains(_pair(a, b));
  List<FriendRequest> get pendingIncoming =>
      List.unmodifiable(_requests.where((r) => r.toId == currentUserId));
  List<FriendRequest> get pendingOutgoing =>
      List.unmodifiable(_requests.where((r) => r.fromId == currentUserId));
  void requestFriend(String toId) {
    person(toId);
    if (toId == currentUserId ||
        areFriends(currentUserId, toId) ||
        _requests.any(
          (r) => _pair(r.fromId, r.toId) == _pair(currentUserId, toId),
        )) {
      throw StateError(
        'Friendship or request already exists, or invalid recipient.',
      );
    }
    _requests.add(FriendRequest(id: _id(), fromId: currentUserId, toId: toId));
    _emit(CloudOp('request', toId));
    notifyListeners();
  }

  FriendRequest _request(String id) => _requests.firstWhere(
    (r) => r.id == id,
    orElse: () => throw StateError('Request no longer exists.'),
  );
  void respondToFriendRequest(String requestId, bool accept) {
    final request = _request(requestId);
    if (request.toId != currentUserId) {
      throw StateError('Only the recipient can respond.');
    }
    _requests.remove(request);
    if (accept) _friendships.add(_pair(request.fromId, request.toId));
    _emit(CloudOp(accept ? 'accept' : 'unfriend', request.fromId));
    notifyListeners();
  }

  void cancelFriendRequest(String id) {
    final request = _request(id);
    if (request.fromId != currentUserId) {
      throw StateError('Only the sender can cancel.');
    }
    _requests.remove(request);
    _emit(CloudOp('unfriend', request.toId));
    notifyListeners();
  }

  void _requireFriend(String id) {
    person(id);
    if (!areFriends(currentUserId, id)) {
      throw StateError('An accepted friendship is required.');
    }
  }

  void removeFriend(String friendId) {
    _requireFriend(friendId);
    _friendships.remove(_pair(currentUserId, friendId));
    for (final key in [
      _directed(currentUserId, friendId),
      _directed(friendId, currentUserId),
    ]) {
      _favorites.remove(key);
      _approved.remove(key);
      _pendingConsent.remove(key);
    }
    _emit(CloudOp('unlink', friendId));
    _emit(CloudOp('revoke', friendId));
    _emit(CloudOp('unfriend', friendId));
    notifyListeners();
  }

  bool isFavorite(String friendId) =>
      _favorites.contains(_directed(currentUserId, friendId));
  bool hasPendingSosRequest(String friendId) =>
      _pendingConsent.contains(_directed(currentUserId, friendId));
  bool isApprovedFavorite(String friendId) =>
      _eligible(currentUserId, friendId);
  bool _eligible(String sender, String recipient) =>
      areFriends(sender, recipient) &&
      _favorites.contains(_directed(sender, recipient)) &&
      _approved.contains(_directed(sender, recipient));

  // --- Remote state (from the cloud layer) -------------------------------

  /// Replaces friends, requests and SOS permissions with what the cloud says.
  /// [mine] is this account's username; everyone else is identified by theirs.
  void applyCloudGraph({
    required String mine,
    required List<({String from, String to, String status})> reqs,
    required List<({String from, String to, String status})>? links,
    required Map<String, String> names,
  }) {
    // A cancelled listener may finish its profile lookup after account switch.
    // Never map the old account's username onto the new account's local id.
    if (mine != currentUser.username) return;
    String id(String u) => u == mine ? currentUserId : u;
    void know(String u) {
      if (u == mine || _profiles.any((p) => p.id == u)) return;
      _profiles.add(DemoPerson(id: u, name: names[u] ?? u, username: u));
    }

    for (final r in reqs) {
      know(r.from);
      know(r.to);
    }
    for (final l in links ?? <({String from, String to, String status})>[]) {
      know(l.from);
      know(l.to);
    }
    for (var i = 0; i < _profiles.length; i++) {
      final p = _profiles[i];
      final name = names[p.id];
      if (p.id != currentUserId &&
          name != null &&
          name.isNotEmpty &&
          name != p.name) {
        _profiles[i] = DemoPerson(id: p.id, name: name, username: p.username);
      }
    }
    _requests.clear();
    _friendships.clear();
    if (links != null) {
      _favorites.clear();
      _approved.clear();
      _pendingConsent.clear();
    }
    for (final r in reqs) {
      if (r.status == 'accepted') {
        _friendships.add(_pair(id(r.from), id(r.to)));
      } else {
        _requests.add(
          FriendRequest(
            id: '${r.from}>${r.to}',
            fromId: id(r.from),
            toId: id(r.to),
          ),
        );
      }
    }
    for (final l in links ?? <({String from, String to, String status})>[]) {
      final key = _directed(id(l.from), id(l.to));
      _favorites.add(key);
      if (l.status == 'approved') {
        _approved.add(key);
      } else {
        _pendingConsent.add(key);
      }
    }
    notifyListeners();
  }

  /// Ids of the messages held on this device.
  Set<String> get messageIds => {for (final m in _messages) m.id};

  Set<String> get loadedMessageIds => {
    for (final m in _messages)
      if (!(m.isVoice && m.audio == null) &&
          !(m.kind == MessageKind.photo && m.photo == null))
        m.id,
  };

  /// A problem with the cloud connection worth showing, or null.
  String? syncError;
  void setSyncError(String? message) {
    if (message == syncError) return;
    syncError = message;
    super.notifyListeners();
  }

  /// Replaces the SOS alerts other people sent to this account.
  void applyCloudAlerts(
    List<
      ({
        String id,
        String sender,
        String status,
        DateTime createdAt,
        double? lat,
        double? lng,
        DateTime? locAt,
        DateTime? endedAt,
      })
    >
    alerts,
  ) {
    final ids = alerts.map((a) => a.id).toSet();
    _events.removeWhere(
      (e) => e.senderId != currentUserId && !ids.contains(e.id),
    );
    for (final a in alerts) {
      if (!_profiles.any((p) => p.id == a.sender)) {
        _profiles.add(
          DemoPerson(id: a.sender, name: a.sender, username: a.sender),
        );
      }
      final next = LocalSosEvent(
        id: a.id,
        senderId: a.sender,
        recipientIds: [currentUserId],
        status: LocalSosStatus.values.firstWhere(
          (s) => s.name == a.status,
          orElse: () => LocalSosStatus.active,
        ),
        createdAt: a.createdAt,
        lastLat: a.lat,
        lastLng: a.lng,
        lastLocationAt: a.locAt,
        endedAt: a.endedAt,
      );
      final i = _events.indexWhere((e) => e.id == a.id);
      if (i == -1) {
        _events.add(next);
      } else {
        _events[i] = next;
      }
    }
    notifyListeners();
  }

  /// Adds messages the cloud delivered that this device has not seen.
  void applyCloudMessages(List<ChatMessage> incoming) {
    final indices = {
      for (var i = 0; i < _messages.length; i++) _messages[i].id: i,
    };
    var changed = false;
    for (final m in incoming) {
      final index = indices[m.id];
      if (index == null) {
        indices[m.id] = _messages.length;
        _messages.add(m);
        changed = true;
      } else {
        final old = _messages[index];
        if ((old.isVoice && old.audio == null && m.audio != null) ||
            (old.kind == MessageKind.photo &&
                old.photo == null &&
                m.photo != null)) {
          _messages[index] = m;
          changed = true;
        }
      }
    }
    if (changed) notifyListeners();
  }

  /// Preview helper for local mode: makes [friendId] a buddy with a first
  /// message so the chat screen has something to show. Never used with cloud
  /// accounts.
  void seedDemoFriend(String friendId) {
    if (friendId == currentUserId) return;
    if (!_profiles.any((p) => p.id == friendId)) {
      _profiles.add(
        DemoPerson(
          id: friendId,
          name: friendId[0].toUpperCase() + friendId.substring(1),
          username: friendId,
        ),
      );
    }
    if (areFriends(currentUserId, friendId)) return;
    _requests.removeWhere(
      (r) =>
          (r.fromId == currentUserId && r.toId == friendId) ||
          (r.fromId == friendId && r.toId == currentUserId),
    );
    _friendships.add(_pair(currentUserId, friendId));
    _messages.add(
      ChatMessage(
        id: _id(),
        senderId: friendId,
        recipientId: currentUserId,
        text: 'Hi! Welcome to SafeHer 👋',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// Preview only: makes [friendId] an approved SOS buddy so the SOS flow can
  /// be exercised without a second device.
  void seedDemoSosBuddy(String friendId) {
    if (!areFriends(currentUserId, friendId)) return;
    final key = _directed(currentUserId, friendId);
    _favorites.add(key);
    _approved.add(key);
    notifyListeners();
  }

  /// How many buddies can receive one SOS at the same time.
  static const maxSosBuddies = 5;

  int get sosBuddyCount => profiles.where((p) => isFavorite(p.id)).length;

  void favorite(String friendId) {
    _requireFriend(friendId);
    final key = _directed(currentUserId, friendId);
    if (!_favorites.contains(key) && sosBuddyCount >= maxSosBuddies) {
      throw StateError('You can connect up to $maxSosBuddies SOS buddies.');
    }
    _favorites.add(key);
    if (!_approved.contains(key)) _pendingConsent.add(key);
    _emit(CloudOp('link', friendId));
    notifyListeners();
  }

  void unfavorite(String friendId) {
    _requireFriend(friendId);
    final key = _directed(currentUserId, friendId);
    _favorites.remove(key);
    _approved.remove(key);
    _pendingConsent.remove(key);
    _emit(CloudOp('unlink', friendId));
    notifyListeners();
  }

  List<SosContactRequest> get incomingSosRequests => List.unmodifiable(
    profiles
        .where((p) => _pendingConsent.contains(_directed(p.id, currentUserId)))
        .map(
          (p) => SosContactRequest(senderId: p.id, recipientId: currentUserId),
        ),
  );
  void respondToSosRequest(String senderId, bool accept) {
    _requireFriend(senderId);
    final key = _directed(senderId, currentUserId);
    if (!_pendingConsent.remove(key)) {
      throw StateError('No pending SOS permission request.');
    }
    if (accept) _approved.add(key);
    _emit(CloudOp(accept ? 'approve' : 'revoke', senderId));
    notifyListeners();
  }

  void revokeSosPermission(String senderId) {
    _requireFriend(senderId);
    final key = _directed(senderId, currentUserId);
    if (!_approved.remove(key)) throw StateError('No approved SOS permission.');
    _pendingConsent.remove(key);
    _emit(CloudOp('revoke', senderId));
    notifyListeners();
  }

  List<DemoPerson> get approvedSenders =>
      List.unmodifiable(profiles.where((p) => _eligible(p.id, currentUserId)));
  List<DemoPerson> get eligibleRecipients =>
      List.unmodifiable(profiles.where((p) => _eligible(currentUserId, p.id)));
  void sendMessage(String friendId, String text) {
    _requireFriend(friendId);
    final cleaned = text.trim();
    if (cleaned.isEmpty || cleaned.length > 2000) {
      throw StateError('Use 1 to 2000 characters.');
    }
    final id = _messageId();
    _messages.add(
      ChatMessage(
        id: id,
        senderId: currentUserId,
        recipientId: friendId,
        text: cleaned,
        createdAt: DateTime.now(),
      ),
    );
    _emit(CloudOp('message', friendId, id: id, text: cleaned));
    notifyListeners();
  }

  // --- Who is around --------------------------------------------------------

  final _presence = <String, Presence>{};

  /// How far a sent message has got. One tick means it is on its way, two
  /// that their device has it, two in blue that they have read it.
  final _receipts = <String, ({DateTime? delivered, DateTime? read})>{};

  MessageStatus statusOf(String messageId) {
    final r = _receipts[messageId];
    if (r == null) return MessageStatus.sent;
    if (r.read != null) return MessageStatus.read;
    if (r.delivered != null) return MessageStatus.delivered;
    return MessageStatus.sent;
  }

  void applyReceipt(String messageId, {DateTime? delivered, DateTime? read}) {
    final old = _receipts[messageId];
    delivered ??= old?.delivered;
    read ??= old?.read;
    if (old?.delivered == delivered && old?.read == read) return;
    _receipts[messageId] = (delivered: delivered, read: read);
    super.notifyListeners();
  }

  /// Told which conversation is open, so the cloud layer can publish it.
  void Function(String? peer)? onChatOpen;
  void Function(bool typing)? onTyping;
  String? openChat;

  void enterChat(String id) {
    openChat = id;
    onChatOpen?.call(id);
  }

  void leaveChat() {
    onTyping?.call(false);
    openChat = null;
    onChatOpen?.call(null);
  }

  Presence presenceOf(String id) => _presence[id] ?? const Presence();

  /// Fed by the cloud layer as buddies open and close the app.
  void applyPresence(String id, Presence p) {
    _presence[id] = p;
    super.notifyListeners();
  }

  /// Server disconnects have no callback in Firestore. Expire stale hints
  /// locally too, even when the last presence snapshot never changes again.
  void expirePresence(DateTime now) {
    var changed = false;
    for (final entry in _presence.entries.toList()) {
      final p = entry.value;
      final at = p.lastSeen;
      if (at == null) continue;
      final age = now.difference(at);
      final online = p.online && age < const Duration(seconds: 70);
      final typing = p.typing && online && age < const Duration(seconds: 5);
      if (online == p.online && typing == p.typing) continue;
      _presence[entry.key] = Presence(
        online: online,
        typing: typing,
        lastSeen: at,
        openWith: online ? p.openWith : null,
      );
      changed = true;
    }
    if (changed) super.notifyListeners();
  }

  /// Records a call nobody picked up. Each device writes its own line — the
  /// caller's and the callee's — so nothing has to travel for the chat to show
  /// it, and it works with no signal.
  void noteMissedCall(
    String friendId, {
    required bool video,
    required bool outgoing,
  }) {
    if (!areFriends(currentUserId, friendId)) return;
    _messages.add(
      ChatMessage(
        id: _messageId(),
        senderId: outgoing ? currentUserId : friendId,
        recipientId: outgoing ? friendId : currentUserId,
        text: '',
        createdAt: DateTime.now(),
        kind: video ? MessageKind.missedVideoCall : MessageKind.missedVoiceCall,
      ),
    );
    notifyListeners();
  }

  /// The ids of the most recent voice notes, whose audio is worth keeping on
  /// this device.
  static const _audioKept = 20;

  /// Recomputed once per save, not once per message.
  Set<String> _audioToKeep() {
    final kept = <String>{};
    // Voice and photos get separate budgets. Sharing one would let a single
    // large photo evict every voice note, and the two together must stay well
    // inside the backup document limit once base64 and sealing are applied.
    var voiceBytes = 0;
    var photoBytes = 0;
    for (final m in _messages.reversed) {
      if (kept.length >= _audioKept) break;
      final voice = m.audio?.length ?? 0;
      final photo = m.photo?.length ?? 0;
      if (voice > 0) {
        if (voiceBytes + voice > _voiceBudget) continue;
        voiceBytes += voice;
      } else if (photo > 0) {
        if (photoBytes + photo > _photoBudget) continue;
        photoBytes += photo;
      } else {
        continue;
      }
      kept.add(m.id);
    }
    return kept;
  }

  static const _voiceBudget = 240000;
  static const _photoBudget = 160000;

  void sendPhoto(String friendId, Uint8List photo) {
    _requireFriend(friendId);
    if (photo.isEmpty) return;
    if (photo.length > 400000) throw StateError('Choose a smaller photo.');
    final id = _messageId();
    final bytes = Uint8List.fromList(photo);
    _messages.add(
      ChatMessage(
        id: id,
        senderId: currentUserId,
        recipientId: friendId,
        text: '',
        createdAt: DateTime.now(),
        kind: MessageKind.photo,
        photo: bytes,
      ),
    );
    _emit(CloudOp('photo', friendId, id: id, photo: bytes));
    notifyListeners();
  }

  /// Sends a recorded voice note. The bytes go out sealed, exactly like text.
  void sendVoice(String friendId, Uint8List audio, int seconds) {
    _requireFriend(friendId);
    if (audio.isEmpty || seconds < 1) return;
    final id = _messageId();
    _messages.add(
      ChatMessage(
        id: id,
        senderId: currentUserId,
        recipientId: friendId,
        text: '',
        createdAt: DateTime.now(),
        kind: MessageKind.voice,
        audio: audio,
        seconds: seconds,
      ),
    );
    _emit(CloudOp('voice', friendId, id: id, audio: audio, seconds: seconds));
    notifyListeners();
  }

  List<ChatMessage> messagesWith(String friendId) {
    _requireFriend(friendId);
    return List.unmodifiable(
      _messages.where(
        (m) =>
            _pair(m.senderId, m.recipientId) == _pair(currentUserId, friendId),
      ),
    );
  }

  LocalSosEvent createSos() {
    for (final event in _events) {
      if (event.senderId == currentUserId &&
          event.status == LocalSosStatus.active) {
        return event;
      }
    }
    final recipients = eligibleRecipients.map((p) => p.id).toList();
    if (recipients.isEmpty) {
      throw StateError(
        'Choose a favorite SOS contact and get their approval first.',
      );
    }
    final event = LocalSosEvent(
      id: _messageId(),
      senderId: currentUserId,
      recipientIds: recipients,
      status: LocalSosStatus.active,
      createdAt: DateTime.now(),
    );
    _events.add(event);
    _emit(CloudOp('sosStart', '', id: event.id, text: recipients.join(',')));
    notifyListeners();
    return event;
  }

  void finishSos(String eventId, {required bool cancelled}) {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index < 0) throw StateError('Unknown SOS event.');
    final event = _events[index];
    if (event.senderId != currentUserId) {
      throw StateError('Only the sender can stop this SOS.');
    }
    if (event.status != LocalSosStatus.active) {
      throw StateError('SOS has already ended.');
    }
    _events[index] = event.copyWith(
      status: cancelled ? LocalSosStatus.cancelled : LocalSosStatus.resolved,
      endedAt: DateTime.now(),
    );
    _emit(
      CloudOp(
        'sosEnd',
        '',
        id: eventId,
        text: cancelled ? 'cancelled' : 'resolved',
      ),
    );
    notifyListeners();
  }

  /// Records the latest live position on an active SOS. Called for every fix
  /// while the SOS runs, and once more with the final fix when it ends.
  void updateSosLocation(String eventId, double lat, double lng, DateTime at) {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index < 0 || _events[index].senderId != currentUserId) return;
    _events[index] = _events[index].copyWith(
      lastLat: lat,
      lastLng: lng,
      lastLocationAt: at,
    );
    _emit(
      CloudOp(
        'sosLoc',
        '',
        id: eventId,
        text: '$lat,$lng,${at.toIso8601String()}',
      ),
    );
    notifyListeners();
  }

  List<LocalSosEvent> get visibleEvents => List.unmodifiable(
    _events.where(
      (e) =>
          e.senderId == currentUserId ||
          (e.recipientIds.contains(currentUserId) &&
              _eligible(e.senderId, currentUserId)),
    ),
  );
}
