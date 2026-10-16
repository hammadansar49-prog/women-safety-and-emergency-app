import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/sos_shortcut.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('safeher/shortcut');
  const codec = StandardMethodCodec();
  test('test requires matching hardware event and never sends SOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    var starts = 0;
    final shortcut = SosShortcut(
      onSos: () => starts++,
      selectedKey: 'volumeUp',
    );
    Future<void> press(String key) async {
      final done = Completer<void>();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            codec.encodeMethodCall(MethodCall('doublePress', key)),
            (_) => done.complete(),
          );
      await done.future;
    }

    await shortcut.enable(true);
    expect(shortcut.enabled, isFalse);
    await shortcut.test();
    await press('volumeDown');
    expect(shortcut.tested, isFalse);
    await press('volumeUp');
    expect(shortcut.tested, isTrue);
    expect(starts, 0);
    await shortcut.enable(true);
    await press('volumeUp');
    expect(starts, 1);
    await shortcut.select('volumeDown');
    expect(shortcut.enabled, isFalse);
    expect(shortcut.tested, isFalse);
    await press('volumeDown');
    expect(starts, 1);
    await shortcut.enable(false);
    shortcut.dispose();
  });
}
