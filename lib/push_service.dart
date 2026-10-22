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
  int _generation = 0;

  DocumentReference<Map<String, dynamic>> _ref(String me) =>
      _db.collection('pushTokens').doc(me);

  Future<void> register(String me) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final generation = ++_generation;
    _me = me;
    _token = null;
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (_me != me || _generation != generation) return;
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    // getToken/onTokenRefresh are deprecated in favour of installation-id
    // sending, but the server function below sends to classic tokens.
    // ignore: deprecated_member_use
    final token = await messaging.getToken();
    if (_me != me || _generation != generation) return;
    if (token != null) await _save(token, me, generation);
    if (_me != me || _generation != generation) return;
    // ignore: deprecated_member_use
    _refresh = messaging.onTokenRefresh.listen((token) {
      unawaited(_save(token, me, generation).catchError((Object _) {}));
    });
  }

  Future<void> _save(String token, String me, int generation) async {
    if (_me != me || _generation != generation) return;
    _token = token;
    await _ref(me).set({
      'token': token,
      'platform': 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stops this phone receiving the account's alerts (sign out).
  Future<void> unregister() async {
    ++_generation;
    final refresh = _refresh;
    final me = _me;
    final token = _token;
    _refresh = null;
    _me = null;
    _token = null;
    await refresh?.cancel();
    if (me != null && token != null && _me != me) {
      try {
        await _ref(me).delete();
      } catch (_) {}
    }
  }
}
