import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// Persists which account and flow opened Android's shared image picker.
class ImagePickerIntent {
  const ImagePickerIntent({
    required this.token,
    required this.purpose,
    required this.owner,
  });

  final String token;
  final String purpose;
  final String owner;
  static int _sequence = 0;
  static const _intentKey = 'image_picker_intent_v1';
  static const _recoveredKey = 'image_picker_recovered_v1';
  static Box<String>? get _box => Hive.isBoxOpen('safeher_account_v2')
      ? Hive.box<String>('safeher_account_v2')
      : null;

  static ImagePickerIntent? get current {
    final raw = _box?.get(_intentKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return ImagePickerIntent(
        token: data['token'] as String,
        purpose: data['purpose'] as String,
        owner: data['owner'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<ImagePickerIntent?> begin(
    String purpose, {
    String? owner,
  }) async {
    final box = _box;
    final account = owner ?? box?.get('session');
    if (box == null || account == null || account.isEmpty) return null;
    final intent = ImagePickerIntent(
      token: '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      purpose: purpose,
      owner: account,
    );
    await box.put(_intentKey, jsonEncode(intent._data));
    await box.flush();
    return intent;
  }

  Map<String, String> get _data => {
    'token': token,
    'purpose': purpose,
    'owner': owner,
  };

  Future<void> clear() async {
    final box = _box;
    if (box == null || current?.token != token) return;
    await box.delete(_intentKey);
    await box.flush();
  }

  /// Keep references to recovered files without moving/deleting or sending
  /// them. A future explicit selection can decide what to do with the photo.
  static Future<void> preserveRecovered(
    ImagePickerIntent? intent,
    List<String> paths,
  ) async {
    final box = _box;
    if (box == null) return;
    await box.put(
      _recoveredKey,
      jsonEncode({...?intent?._data, 'paths': paths}),
    );
    await box.flush();
  }
}
