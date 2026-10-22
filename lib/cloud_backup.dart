import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';

class BackupFailure implements Exception {
  const BackupFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Where the encrypted backup document lives. Firestore in the app, a map in
/// tests.
abstract class BackupStore {
  Future<Map<String, dynamic>?> read(String uid);
  Future<void> create(String uid, Map<String, dynamic> doc);
  Future<void> updateData(String uid, String data);
  Future<void> delete(String uid);
}

class FirestoreBackupStore implements BackupStore {
  FirestoreBackupStore([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _db.collection('backups').doc(uid);

  @override
  Future<Map<String, dynamic>?> read(String uid) async =>
      (await _ref(uid).get()).data();

  @override
  Future<void> create(String uid, Map<String, dynamic> doc) =>
      _ref(uid).set({...doc, 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> delete(String uid) => _ref(uid).delete();

  @override
  Future<void> updateData(String uid, String data) => _ref(
    uid,
  ).update({'data': data, 'updatedAt': FieldValue.serverTimestamp()});
}

/// The result of turning backup on: the code the person must keep, and the
/// key this device keeps so later saves need no code.
class BackupEnabled {
  const BackupEnabled(this.recoveryCode, this.keyB64);
  final String recoveryCode;
  final String keyB64;
}

/// Encrypted account backup. The snapshot is sealed on the device with a
/// random 256-bit key (AES-GCM). That key is itself sealed with a key derived
/// from a recovery code (PBKDF2), and only the sealed forms are uploaded, so
/// the server holds ciphertext it cannot read.
class CloudBackup {
  CloudBackup(this._store, {this.iterations = 120000});

  final BackupStore _store;
  final int iterations;

  static final _aes = AesGcm.with256bits();
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Future<bool> exists(String uid) async => await _store.read(uid) != null;

  static String newRecoveryCode() {
    final r = Random.secure();
    final raw = List.generate(20, (_) => _alphabet[r.nextInt(_alphabet.length)]);
    return [
      for (var i = 0; i < 20; i += 4) raw.sublist(i, i + 4).join(),
    ].join('-');
  }

  static String _clean(String code) =>
      code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Future<SecretKey> _wrapKey(String code, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  ).deriveKeyFromPassword(password: _clean(code), nonce: salt);

  Future<String> _seal(SecretKey key, List<int> plain) async {
    final box = await _aes.encrypt(plain, secretKey: key);
    return base64Encode(box.concatenation());
  }

  Future<List<int>> _open(SecretKey key, String sealed) async {
    final box = SecretBox.fromConcatenation(
      base64Decode(sealed),
      nonceLength: 12,
      macLength: 16,
    );
    return _aes.decrypt(box, secretKey: key);
  }

  /// Turns backup on for [uid] with a fresh key and recovery code.
  Future<BackupEnabled> enable(String uid, String snapshot) async {
    final code = newRecoveryCode();
    final key = await _aes.newSecretKey();
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final keyBytes = await key.extractBytes();
    await _store.create(uid, {
      'v': 1,
      'salt': base64Encode(salt),
      'wrapped': await _seal(await _wrapKey(code, salt), keyBytes),
      'data': await _seal(key, utf8.encode(snapshot)),
    });
    return BackupEnabled(code, base64Encode(keyBytes));
  }

  /// Drops the old backup and starts a new one (for a lost recovery code).
  Future<BackupEnabled> reset(String uid, [String snapshot = '{}']) async {
    await _store.delete(uid);
    return enable(uid, snapshot);
  }

  /// Saves a newer snapshot with the key this device already holds.
  Future<void> save(String uid, String keyB64, String snapshot) async {
    final key = SecretKey(base64Decode(keyB64));
    await _store.updateData(uid, await _seal(key, utf8.encode(snapshot)));
  }

  /// Opens the backup with the recovery code. Throws [BackupFailure] on a
  /// wrong code; nothing else about the backup is revealed.
  Future<({String snapshot, String keyB64})> restore(
    String uid,
    String code,
  ) async {
    final doc = await _store.read(uid);
    if (doc == null) throw const BackupFailure('No backup found.');
    try {
      final keyBytes = await _open(
        await _wrapKey(code, base64Decode(doc['salt'] as String)),
        doc['wrapped'] as String,
      );
      final plain = await _open(SecretKey(keyBytes), doc['data'] as String);
      return (snapshot: utf8.decode(plain), keyB64: base64Encode(keyBytes));
    } on SecretBoxAuthenticationError {
      throw const BackupFailure('That recovery code is not right.');
    }
  }
}
