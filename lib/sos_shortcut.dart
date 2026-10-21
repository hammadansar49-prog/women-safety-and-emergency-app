import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SosShortcut extends ChangeNotifier {
  SosShortcut({
    required this.onSos,
    required this.selectedKey,
    this.backgroundPresses = 3,
    this.backgroundWindowMs = 2000,
  }) {
    if (supported) {
      _channel.setMethodCallHandler(_receive);
      // A trigger may have arrived via the background service while the app
      // was killed; drain it once the handler is wired.
      _drainPendingTrigger();
    }
  }
  final VoidCallback onSos;
  final _channel = const MethodChannel('safeher/shortcut');
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  String selectedKey;

  /// How many rapid presses of [selectedKey] fire the background trigger.
  /// A double press is easy to hit by accident while changing volume, so the
  /// background pattern needs more presses than the in-app test.
  final int backgroundPresses;
  final int backgroundWindowMs;

  bool testing = false;
  bool tested = false;
  bool enabled = false;
  String? error;
  bool _disposed = false;

  Future<void> _receive(MethodCall call) async {
    // Fired by the foreground-service detector while the app is backgrounded
    // or the phone is locked. The app decides start-vs-cancel from SOS state,
    // so the hidden cancel gesture is never surfaced here.
    if (call.method == 'backgroundSos') {
      if (enabled) onSos();
      return;
    }
    if (call.method != 'doublePress' || call.arguments != selectedKey) return;
    if (testing) {
      testing = false;
      tested = true;
      await _configure('off');
      if (!_disposed) notifyListeners();
    } else if (enabled) {
      onSos();
    }
  }

  Future<void> _drainPendingTrigger() async {
    try {
      final had = await _channel.invokeMethod<bool>('consumePendingTrigger');
      if (had == true && !_disposed) onSos();
    } catch (_) {
      // Older builds without the method: ignore.
    }
  }

  Future<void> _armBackground(bool on) async {
    if (!supported) return;
    try {
      if (on) {
        await _channel.invokeMethod('startBackgroundArm', {
          'key': selectedKey,
          'presses': backgroundPresses,
          'windowMs': backgroundWindowMs,
        });
      } else {
        await _channel.invokeMethod('stopBackgroundArm');
      }
    } catch (_) {
      // Surface through `error`; foreground detection still works.
      error = 'Background SOS service could not start on this device.';
    }
  }

  Future<void> _configure(String mode) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('configure', {
        'key': selectedKey,
        'mode': mode,
      });
      error = null;
    } catch (_) {
      enabled = false;
      testing = false;
      tested = false;
      error = 'Shortcut could not be configured on this device.';
    }
  }

  Future<void> select(String key) async {
    enabled = false;
    testing = false;
    tested = false;
    selectedKey = key;
    await _configure('off');
    await _armBackground(false);
    if (!_disposed) notifyListeners();
  }

  Future<void> test() async {
    enabled = false;
    tested = false;
    testing = true;
    await _configure('test');
    if (!_disposed) notifyListeners();
  }

  Future<void> enable(bool value) async {
    enabled = supported && tested && value;
    testing = false;
    await _configure(enabled ? 'armed' : 'off');
    // Mirror the state into the background service so the shortcut also works
    // while SafeHer is backgrounded or the phone is locked.
    await _armBackground(enabled);
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (supported) {
      _channel.setMethodCallHandler(null);
      _configure('off');
      _armBackground(false);
    }
    super.dispose();
  }
}

class ShortcutSettings extends StatelessWidget {
  const ShortcutSettings({
    super.key,
    required this.shortcut,
    required this.onSelect,
  });
  final SosShortcut shortcut;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: shortcut,
    builder: (context, _) => Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SOS button shortcut',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(shortcut.selectedKey),
              initialValue: shortcut.selectedKey,
              decoration: const InputDecoration(
                labelText: 'Double-press button',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'volumeUp', child: Text('Volume Up')),
                DropdownMenuItem(
                  value: 'volumeDown',
                  child: Text('Volume Down'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  shortcut.select(value);
                  onSelect(value);
                }
              },
            ),
            const SizedBox(height: 12),
            Text(
              'In the app: double-press ${shortcut.selectedKey == 'volumeUp' ? 'Volume Up' : 'Volume Down'} to start your SOS. '
              'When enabled, a background service also watches for ${shortcut.backgroundPresses} quick presses so SOS can start while the phone is locked or SafeHer is in your pocket. '
              'The same presses quietly stop an active SOS. Power-button combinations are not supported by Android.',
            ),
            if (!shortcut.supported)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Save your preference here. Test and enable it in the Android app.',
                ),
              ),
            if (shortcut.supported) ...[
              const SizedBox(height: 12),
              Text(
                shortcut.testing
                    ? 'Press the selected volume button twice quickly. This test will not send SOS.'
                    : shortcut.tested
                    ? 'Button test passed while app is open.'
                    : 'Test the button before enabling. Repeat the test after restarting the app.',
              ),
              TextButton(
                onPressed: shortcut.testing
                    ? () => shortcut.enable(false)
                    : shortcut.test,
                child: Text(shortcut.testing ? 'Cancel test' : 'Test shortcut'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable shortcut'),
                value: shortcut.enabled,
                onChanged: shortcut.tested ? shortcut.enable : null,
              ),
              const Text(
                'While enabled, the selected volume button is used for SOS instead of adjusting volume in this app.',
              ),
            ],
            if (shortcut.error != null)
              Text(
                shortcut.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
  );
}
