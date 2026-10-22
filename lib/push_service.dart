import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Registers this phone to be woken by an SOS push even when SafeHer is
/// closed. The token is stored under the account's username; the server
/// function that sends the push reads it, nobody else can.
class PushService {
  PushService(this._db);
  final FirebaseFirestore _db;

  StreamSubscription<String>? _refresh;
  String? _me;
  String? _token;

  DocumentReference<Map<String, dynamic>> _ref(String me) =>
      _db.collection('pushTokens').doc(me);

  Future<void> register(String me) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _me = me;
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    // getToken/onTokenRefresh are deprecated in favour of installation-id
    // sending, but the server function below sends to classic tokens.
    // ignore: deprecated_member_use
    final token = await messaging.getToken();
    if (token != null) await _save(token);
    // ignore: deprecated_member_use
    _refresh = messaging.onTokenRefresh.listen(_save);
  }

  Future<void> _save(String token) async {
    final me = _me;
    if (me == null) return;
    _token = token;
    await _ref(me).set({
      'token': token,
      'platform': 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stops this phone receiving the account's alerts (sign out).
  Future<void> unregister() async {
    await _refresh?.cancel();
    _refresh = null;
    final me = _me;
    _me = null;
    if (me != null && _token != null) {
      try {
        await _ref(me).delete();
      } catch (_) {}
    }
    _token = null;
  }
}
