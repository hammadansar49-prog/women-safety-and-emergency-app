import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// A sign-in/sign-up failure with a message that is safe to show the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

final _usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

String normalizeUsername(String input) => input.trim().toLowerCase();

/// Shown for every failed sign-in so the screen never reveals whether the
/// username or the password was the wrong half.
const wrongCredentials = 'Username or password is incorrect.';

/// A public, searchable account entry (never includes the email).
class RemoteProfile {
  const RemoteProfile({required this.uid, required this.username});
  final String uid;
  final String username;
}

abstract class AuthService {
  /// Finds registered accounts whose username starts with [prefix].
  Future<List<RemoteProfile>> searchUsers(String prefix);

  /// Creates the account and reserves the username. Returns the username.
  Future<String> register({
    required String email,
    required String username,
    required String password,
    String name = '',
  });

  /// The signed-in account's display name, if it has one.
  String? get displayName => null;

  /// Sends a password-reset email. Always succeeds from the outside so the
  /// screen never reveals which emails are registered.
  Future<void> sendPasswordReset(String email);

  /// Signs in by username or email. Returns the account's username.
  Future<String> login({required String username, required String password});

  /// Shows the Google account chooser. Returns the account's username, or an
  /// empty string when the account has not picked one yet.
  Future<String> google();

  /// Atomically reserves [username] for the signed-in account.
  Future<void> reserveUsername(String username);

  Future<void> signOut();
}

/// Firebase Auth + Firestore. Passwords are salted and hashed (scrypt) by
/// Firebase Auth itself, so the app never sees or stores them. Usernames are
/// reserved by creating `usernames/{name}`; rules allow create only, so a name
/// is unique and, once taken, can never be released or reused.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  bool _googleReady = false;

  DocumentReference<Map<String, dynamic>> _name(String u) =>
      _db.collection('usernames').doc(u);

  Future<void> _reserve(User user, String username) =>
      _db.runTransaction((tx) async {
        final taken = await tx.get(_name(username));
        if (taken.exists)
          throw const AuthFailure('That username is already taken.');
        tx.set(_name(username), {
          'uid': user.uid,
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(_db.collection('users').doc(user.uid), {'username': username});
        tx.set(_db.collection('profiles').doc(username), {
          'uid': user.uid,
          'username': username,
        });
      });

  /// Accounts made before the searchable directory existed get an entry the
  /// next time they sign in. Best effort: a failure must not block sign-in.
  Future<void> _ensureProfile(String uid, String username) async {
    if (username.isEmpty) return;
    try {
      final ref = _db.collection('profiles').doc(username);
      if (!(await ref.get()).exists) {
        await ref.set({'uid': uid, 'username': username});
      }
    } catch (_) {}
  }

  @override
  String? get displayName => _auth.currentUser?.displayName;

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        throw const AuthFailure('No connection. Check your internet.');
      }
      if (e.code == 'invalid-email') {
        throw const AuthFailure('Enter a valid email address.');
      }
      // Unknown email etc.: stay silent, same as success.
    }
  }

  @override
  Future<List<RemoteProfile>> searchUsers(String prefix) async {
    final term = normalizeUsername(prefix).replaceFirst('@', '');
    if (term.isEmpty || !RegExp(r'^[a-z0-9_]+$').hasMatch(term)) return [];
    final snap = await _db
        .collection('profiles')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: term)
        .where(FieldPath.documentId, isLessThan: '$term\uf8ff')
        .limit(10)
        .get();
    return [
      for (final d in snap.docs)
        RemoteProfile(
          uid: d.data()['uid'] as String,
          username: d.data()['username'] as String,
        ),
    ];
  }

  @override
  Future<String> register({
    required String email,
    required String username,
    required String password,
    String name = '',
  }) async {
    final fullName = name.trim();
    name = normalizeUsername(username);
    if (!_usernamePattern.hasMatch(name)) {
      throw const AuthFailure('Use 3–20 letters, numbers or underscores.');
    }
    try {
      if ((await _name(name).get()).exists) {
        throw const AuthFailure('That username is already taken.');
      }
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      try {
        await _reserve(cred.user!, name);
      } catch (_) {
        // Lost the race for the name: don't leave a half-made account behind.
        await cred.user!.delete();
        rethrow;
      }
      if (fullName.isNotEmpty) {
        try {
          await cred.user!.updateDisplayName(fullName);
        } catch (_) {}
      }
      return name;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(switch (e.code) {
        'email-already-in-use' => 'An account with this email already exists.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' => 'Choose a stronger password.',
        _ => 'Could not create the account. Try again.',
      });
    } on FirebaseException {
      throw const AuthFailure('That username is already taken.');
    }
  }

  @override
  Future<String> login({
    required String username,
    required String password,
  }) async {
    final name = normalizeUsername(username);
    try {
      if (name.contains('@')) {
        // Signed in by email: the username comes from the account's profile.
        final cred = await _auth.signInWithEmailAndPassword(
          email: name,
          password: password,
        );
        final profile = await _db.collection('users').doc(cred.user!.uid).get();
        final found = (profile.data()?['username'] as String?) ?? '';
        await _ensureProfile(cred.user!.uid, found);
        return found;
      }
      final doc = await _name(name).get();
      final email = doc.data()?['email'] as String?;
      // A never-registered username has no document: same message as a bad
      // password.
      if (email == null) throw const AuthFailure(wrongCredentials);
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _ensureProfile(cred.user!.uid, name);
      return name;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        throw const AuthFailure('No connection. Check your internet.');
      }
      throw const AuthFailure(wrongCredentials);
    }
  }

  @override
  Future<String> google() async {
    try {
      final gs = GoogleSignIn.instance;
      if (!_googleReady) {
        await gs.initialize();
        _googleReady = true;
      }
      // Forget the last pick so the account chooser appears every time.
      await gs.signOut();
      final account = await gs.authenticate();
      final idToken = account.authentication.idToken;
      final cred = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      final doc = await _db.collection('users').doc(cred.user!.uid).get();
      return (doc.data()?['username'] as String?) ?? '';
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFailure('');
      }
      throw const AuthFailure('Google sign-in failed. Try again.');
    } on FirebaseAuthException {
      throw const AuthFailure('Google sign-in failed. Try again.');
    }
  }

  @override
  Future<void> reserveUsername(String username) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('Please sign in again.');
    final name = normalizeUsername(username);
    if (!_usernamePattern.hasMatch(name)) {
      throw const AuthFailure('Use 3–20 letters, numbers or underscores.');
    }
    try {
      await _reserve(user, name);
    } on FirebaseException {
      throw const AuthFailure('That username is already taken.');
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}

/// Offline stand-in for platforms where Firebase is not configured (web,
/// desktop, tests). Accounts live in memory only, but the rules match the
/// cloud ones: unique usernames, salted password hashes, generic login errors.
class LocalAuthService implements AuthService {
  LocalAuthService({String? saved, this.onChanged}) {
    if (saved == null) return;
    final m = jsonDecode(saved) as Map<String, dynamic>;
    for (final e in (m['accounts'] as Map<String, dynamic>).entries) {
      _byName[e.key] = _Account(e.value['salt'], e.value['hash']);
    }
    _nameByEmail.addAll(Map<String, String>.from(m['emails']));
    _emails.addAll(_nameByEmail.keys);
    _everTaken.addAll(List<String>.from(m['taken']));
  }

  /// Called with the serialized accounts after every change, so they survive
  /// a reload (salted hashes only, never passwords).
  final void Function(String data)? onChanged;

  void _changed() => onChanged?.call(
    jsonEncode({
      'accounts': {
        for (final e in _byName.entries)
          e.key: {'salt': e.value.salt, 'hash': e.value.hash},
      },
      'emails': _nameByEmail,
      'taken': _everTaken.toList(),
    }),
  );

  @override
  String? get displayName => null;

  @override
  Future<void> sendPasswordReset(String email) async {}

  final Map<String, _Account> _byName = {};
  final Map<String, String> _nameByEmail = {};
  final Set<String> _emails = {};
  final Set<String> _everTaken = {};

  static String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static String _newSalt() {
    final r = Random.secure();
    return base64Url.encode(List.generate(16, (_) => r.nextInt(256)));
  }

  @override
  Future<String> register({
    required String email,
    required String username,
    required String password,
    String name = '',
  }) async {
    name = normalizeUsername(username);
    final mail = email.trim().toLowerCase();
    if (!_usernamePattern.hasMatch(name)) {
      throw const AuthFailure('Use 3–20 letters, numbers or underscores.');
    }
    if (_everTaken.contains(name)) {
      throw const AuthFailure('That username is already taken.');
    }
    if (_emails.contains(mail)) {
      throw const AuthFailure('An account with this email already exists.');
    }
    final salt = _newSalt();
    _byName[name] = _Account(salt, _hash(salt, password));
    _everTaken.add(name);
    _emails.add(mail);
    _nameByEmail[mail] = name;
    _changed();
    return name;
  }

  @override
  Future<String> login({
    required String username,
    required String password,
  }) async {
    var name = normalizeUsername(username);
    if (name.contains('@')) name = _nameByEmail[name] ?? '';
    final account = _byName[name];
    if (account == null || account.hash != _hash(account.salt, password)) {
      throw const AuthFailure(wrongCredentials);
    }
    return name;
  }

  @override
  Future<List<RemoteProfile>> searchUsers(String prefix) async => [];

  @override
  Future<String> google() async => '';

  @override
  Future<void> reserveUsername(String username) async {
    final name = normalizeUsername(username);
    if (_everTaken.contains(name)) {
      throw const AuthFailure('That username is already taken.');
    }
    _everTaken.add(name);
    _changed();
  }

  @override
  Future<void> signOut() async {}
}

class _Account {
  const _Account(this.salt, this.hash);
  final String salt;
  final String hash;
}
