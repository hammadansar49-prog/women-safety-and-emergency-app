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

abstract class AuthService {
  /// Creates the account and reserves the username. Returns the username.
  Future<String> register({
    required String email,
    required String username,
    required String password,
  });

  /// Signs in an existing account by username. Returns the username.
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

  Future<void> _reserve(User user, String username) => _db.runTransaction((
    tx,
  ) async {
    final taken = await tx.get(_name(username));
    if (taken.exists) throw const AuthFailure('That username is already taken.');
    tx.set(_name(username), {
      'uid': user.uid,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    tx.set(_db.collection('users').doc(user.uid), {'username': username});
  });

  @override
  Future<String> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final name = normalizeUsername(username);
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
      final doc = await _name(name).get();
      final email = doc.data()?['email'] as String?;
      // A never-registered username has no document: same message as a bad
      // password.
      if (email == null) throw const AuthFailure(wrongCredentials);
      await _auth.signInWithEmailAndPassword(email: email, password: password);
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
  final Map<String, _Account> _byName = {};
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
  }) async {
    final name = normalizeUsername(username);
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
    return name;
  }

  @override
  Future<String> login({
    required String username,
    required String password,
  }) async {
    final name = normalizeUsername(username);
    final account = _byName[name];
    if (account == null || account.hash != _hash(account.salt, password)) {
      throw const AuthFailure(wrongCredentials);
    }
    return name;
  }

  @override
  Future<String> google() async => '';

  @override
  Future<void> reserveUsername(String username) async {
    final name = normalizeUsername(username);
    if (_everTaken.contains(name)) {
      throw const AuthFailure('That username is already taken.');
    }
    _everTaken.add(name);
  }

  @override
  Future<void> signOut() async {}
}

class _Account {
  const _Account(this.salt, this.hash);
  final String salt;
  final String hash;
}
