import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import 'social_controller.dart';

/// On-device storage with one private slot per account. Nothing an account
/// owns (friends, chats, photo, settings) is ever read under another
/// account's key, and signing out removes it from memory.
class LocalVault {
  LocalVault(this._box);
  final Box<String> _box;

  String? account(String key) => _box.get('acct:$key');

  /// The account that was signed in when the app last ran.
  String? get session => _box.get('session');
  Future<void> setSession(String? key) async {
    if (key == null) {
      await _box.delete('session');
    } else {
      await _box.put('session', key);
    }
    await _box.flush();
  }

  /// The key that seals this device's cloud backup of [uid], kept so saves
  /// need no recovery code. Cleared when the account signs out here.
  String? backupKey(String uid) => _box.get('bkey:$uid');
  Future<void> setBackupKey(String uid, String? value) async {
    if (value == null) {
      await _box.delete('bkey:$uid');
    } else {
      await _box.put('bkey:$uid', value);
    }
    await _box.flush();
  }

  /// Registered accounts of the offline sign-in (salted hashes only).
  String? get authData => _box.get('auth');
  Future<void> saveAuthData(String value) async {
    await _box.put('auth', value);
    await _box.flush();
  }
}

Future<({SocialController social, LocalVault vault})> loadLocalAccount() async {
  await Hive.initFlutter();
  final box = await Hive.openBox<String>('safeher_account_v2');
  final vault = LocalVault(box);
  final social = SocialController(newAccount: true);
  // Device-wide preferences (light/dark) outlive any one account.
  final device = box.get('device');
  if (device != null) {
    final m = jsonDecode(device) as Map<String, dynamic>;
    social.appearanceChosen = m['appearanceChosen'] == true;
    social.appearance = social.appearanceChosen
        ? (m['appearance'] as String? ?? 'light')
        : 'light';
  }
  social.persist = (data) async {
    final m = jsonDecode(data) as Map<String, dynamic>;
    await box.put(
      'device',
      jsonEncode({
        'appearance': m['appearance'],
        'appearanceChosen': m['appearanceChosen'],
      }),
    );
    await box.flush();
  };
  social.persistAccount = (key, data) async {
    await box.put('acct:$key', data);
    await box.flush();
  };
  return (social: social, vault: vault);
}
