import 'dart:convert';
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

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.createdAt,
  });
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  final DateTime createdAt;
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
  }) : recipientIds = List.unmodifiable(recipientIds);
  final String id;
  final String senderId;
  final List<String> recipientIds;
  final LocalSosStatus status;
  final DateTime createdAt;
}

/// Local account state. Persistence is injected; networking is not connected.
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
  factory SocialController.fromSnapshot(String value) {
    final m = jsonDecode(value) as Map<String, dynamic>;
    if (m['version'] != 1) {
      throw const FormatException('Unsupported saved data');
    }
    final c = SocialController();
    c._profiles.clear();
    for (final p in m['profiles']) {
      c._profiles.add(
        DemoPerson(id: p['id'], name: p['name'], username: p['username']),
      );
    }
    c._currentUserId = m['current'];
    c.person(c._currentUserId);
    c._sequence = m['sequence'];
    c.signedIn = m['signedIn'];
    c.appearance = m['appearance'] ?? 'system';
    c.countdown = m['countdown'] ?? 5;
    c.shortcutKey = m['shortcutKey'] == 'volumeDown'
        ? 'volumeDown'
        : 'volumeUp';
    c._photos.addAll(Map<String, String>.from(m['photos']));
    c._friendships.addAll(List<String>.from(m['friends']));
    c._favorites.addAll(List<String>.from(m['favorites']));
    c._approved.addAll(List<String>.from(m['approved']));
    c._pendingConsent.addAll(List<String>.from(m['pending']));
    for (final r in m['requests']) {
      c._requests.add(
        FriendRequest(id: r['id'], fromId: r['from'], toId: r['to']),
      );
    }
    for (final r in m['messages']) {
      c._messages.add(
        ChatMessage(
          id: r['id'],
          senderId: r['from'],
          recipientId: r['to'],
          text: r['text'],
          createdAt: DateTime.parse(r['time']),
        ),
      );
    }
    for (final r in m['events']) {
      c._events.add(
        LocalSosEvent(
          id: r['id'],
          senderId: r['from'],
          recipientIds: List<String>.from(r['to']),
          status: LocalSosStatus.values.byName(r['status']),
          createdAt: DateTime.parse(r['time']),
        ),
      );
    }
    return c;
  }

  String snapshot() => jsonEncode({
    'version': 1,
    'current': currentUserId,
    'sequence': _sequence,
    'signedIn': signedIn,
    'appearance': appearance,
    'countdown': countdown,
    'shortcutKey': shortcutKey,
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
        },
    ],
  });

  Future<void> Function(String)? persist;
  Future<void> _pendingSave = Future.value();
  String? saveError;
  bool saving = false;
  bool _disposed = false;
  int _saveRevision = 0;
  bool signedIn = false;
  String appearance = 'system';
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

  void setAppearance(String value) {
    appearance = value;
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
    final write = persist;
    if (write != null) {
      final data = snapshot();
      final revision = ++_saveRevision;
      saving = true;
      _pendingSave = _pendingSave.then((_) async {
        try {
          await write(data);
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
    notifyListeners();
  }

  String _currentUserId = 'hammad';
  String get currentUserId => _currentUserId;
  DemoPerson get currentUser => person(currentUserId);
  int _sequence = 0;
  String _id() => '${++_sequence}';
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
    notifyListeners();
  }

  void cancelFriendRequest(String id) {
    final request = _request(id);
    if (request.fromId != currentUserId) {
      throw StateError('Only the sender can cancel.');
    }
    _requests.remove(request);
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
  void favorite(String friendId) {
    _requireFriend(friendId);
    final key = _directed(currentUserId, friendId);
    _favorites.add(key);
    if (!_approved.contains(key)) _pendingConsent.add(key);
    notifyListeners();
  }

  void unfavorite(String friendId) {
    _requireFriend(friendId);
    final key = _directed(currentUserId, friendId);
    _favorites.remove(key);
    _approved.remove(key);
    _pendingConsent.remove(key);
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
    notifyListeners();
  }

  void revokeSosPermission(String senderId) {
    _requireFriend(senderId);
    final key = _directed(senderId, currentUserId);
    if (!_approved.remove(key)) throw StateError('No approved SOS permission.');
    _pendingConsent.remove(key);
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
    _messages.add(
      ChatMessage(
        id: _id(),
        senderId: currentUserId,
        recipientId: friendId,
        text: cleaned,
        createdAt: DateTime.now(),
      ),
    );
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
      id: _id(),
      senderId: currentUserId,
      recipientIds: recipients,
      status: LocalSosStatus.active,
      createdAt: DateTime.now(),
    );
    _events.add(event);
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
    _events[index] = LocalSosEvent(
      id: event.id,
      senderId: event.senderId,
      recipientIds: event.recipientIds,
      createdAt: event.createdAt,
      status: cancelled ? LocalSosStatus.cancelled : LocalSosStatus.resolved,
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
