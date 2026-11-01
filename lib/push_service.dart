import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Registers this phone to be woken by an SOS push even when SafeHer is
/// closed. The token is stored under the account's username; the server
/// function that sends the push reads it, nobody else can.
class PushService {
  PushService(this._db);
  final FirebaseFirestore _db;

  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _opened;
  String? _me;
  String? _token;
  int _generation = 0;

  /// One document per phone, so every device signed in to the account is
  /// woken. The id is a hash of the token: stable, and reveals nothing.
  DocumentReference<Map<String, dynamic>> _ref(String me, String token) => _db
      .collection('pushTokens')
      .doc(me)
      .collection('devices')
      .doc(sha256.convert(utf8.encode(token)).toString().substring(0, 32));

  /// [onOpen] gets the sender's SOS event id when the user taps an SOS
  /// notification, whether the app was closed, in the background or open.
  Future<void> register(
    String me, {
    void Function(String eventId)? onOpen,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final generation = ++_generation;
    _me = me;
    _token = null;
    final messaging = FirebaseMessaging.instance;
    if (onOpen != null) {
      void handle(RemoteMessage? m) {
        final id = m?.data['eventId'];
        if (m?.data['type'] == 'sos' && id is String && _me == me) onOpen(id);
      }

      await _opened?.cancel();
      _opened = FirebaseMessaging.onMessageOpenedApp.listen(handle);
      handle(await messaging.getInitialMessage());
      if (_me != me || _generation != generation) return;
    }
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
    final old = _token;
    _token = token;
    if (old != null && old != token) {
      try {
        await _ref(me, old).delete();
      } catch (_) {}
    }
    await _ref(me, token).set({
      'token': token,
      'platform': 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stops this phone receiving the account's alerts (sign out).
  Future<void> unregister() async {
    ++_generation;
    await _opened?.cancel();
    _opened = null;
    final refresh = _refresh;
    final me = _me;
    final token = _token;
    _refresh = null;
    _me = null;
    _token = null;
    await refresh?.cancel();
    if (me != null && token != null && _me != me) {
      try {
        await _ref(me, token).delete();
      } catch (_) {}
    }
  }
}
