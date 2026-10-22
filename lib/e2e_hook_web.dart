import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Exposes `window.safeherCall(name, argsJson)` so a test script can drive the
/// real app against the real backend. Installed only when the app is built
/// with `--dart-define=SAFEHER_E2E=true`.
void installE2eHook(
  Future<Object?> Function(String name, List<dynamic> args) handler,
) {
  globalContext['safeherCall'] = ((JSString name, JSString argsJson) {
    return handler(
      name.toDart,
      jsonDecode(argsJson.toDart) as List<dynamic>,
    ).then((v) => jsonEncode(v).toJS).toJS;
  }).toJS;
}
