import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Turns Android's FLAG_SECURE on or off: no screenshots, no screen
/// recording and a blank recent-apps preview while it is on.
class SecureWindow {
  static const _channel = MethodChannel('safeher/secure');
  bool? _applied;

  void apply(bool secure) {
    if (_applied == secure ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _applied = secure;
    _channel.invokeMethod<void>('set', secure).catchError((Object _) {});
  }
}
