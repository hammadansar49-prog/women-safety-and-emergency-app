import 'dart:async';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/call_controller.dart';
import 'package:safeher/call_signaling.dart';
import 'package:safeher/cloud_social.dart';

/// Signalling that records what the controller asked for, with no Firestore.
class _FakeSignaling implements CallSignaling {
  final rings = StreamController<List<CallDoc>>.broadcast();
  final created = <String>[];
  final statuses = <String, CallStatus>{};
  int ringSubscriptions = 0;

  @override
  Future<void> create({
    required String id,
    required String caller,
    required String callee,
    required CallKind kind,
    required Map<String, String> offer,
  }) async => created.add('$caller>$callee:${kind.name}');

  @override
  Stream<List<CallDoc>> ringingFor(String me) {
    ringSubscriptions++;
    return rings.stream;
  }

  @override
  Future<void> setStatus(String id, CallStatus status) async =>
      statuses[id] = status;

  @override
  Future<void> answer(String id, Map<String, String> answer) async {}

  @override
  Future<CallDoc?> get(String id) async => null;

  @override
  Stream<CallDoc?> watch(String id) => const Stream.empty();

  @override
  Future<void> addCandidate(
    String id,
    String from,
    Map<String, dynamic> c,
  ) async {}

  @override
  Stream<Map<String, dynamic>> candidatesFrom(String id, String other) =>
      const Stream.empty();
}

class _CallSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _CallSnapshot(this.record);
  final Map<String, dynamic> record;
  @override
  String get id => 'old-call';
  @override
  Map<String, dynamic> data() => record;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'outgoing call is visible while native setup is still pending',
    () async {
      final pending = Completer<Object?>();
      const channel = MethodChannel('FlutterWebRTC.Method');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) => pending.future);
      final controller = CallController(signaling: _FakeSignaling());
      await controller.start('amy');
      final dialing = controller.call('bob', CallKind.audio);
      expect(controller.active, isNotNull);
      expect(controller.active?.peer, 'bob');
      await controller.endCall();
      pending.completeError(PlatformException(code: 'cancelled'));
      await dialing;
      expect(controller.active, isNull);
      expect(controller.error, isNull);
      await controller.stop();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );

  test('incoming listener errors are reported instead of hidden', () async {
    final signaling = _FakeSignaling();
    final controller = CallController(signaling: signaling);
    await controller.start('amy');
    signaling.rings.addError(StateError('permission-denied'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.error, isNotNull);
    await controller.stop();
    await signaling.rings.close();
  });

  test('incoming listener reconnects after an error', () async {
    final signaling = _FakeSignaling();
    final controller = CallController(signaling: signaling);
    await controller.start('amy');
    signaling.rings.addError(StateError('unavailable'));
    await Future<void>.delayed(const Duration(milliseconds: 3100));
    expect(signaling.ringSubscriptions, 2);
    await controller.stop();
    await signaling.rings.close();
  });

  test('setup failure clears the visible call and reports an error', () async {
    const channel = MethodChannel('FlutterWebRTC.Method');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'microphone-denied');
        });
    final controller = CallController(signaling: _FakeSignaling());
    await controller.start('amy');
    await controller.call('bob', CallKind.video);
    expect(controller.active, isNull);
    expect(controller.error, contains('permission'));
    await controller.stop();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('signing out invalidates an in-flight sign-in', () async {
    final controller = CallController(signaling: _FakeSignaling());
    final starting = controller.start('amy');
    await controller.stop();
    await starting;
    expect(controller.account, isNull);
  });

  test('a queued five minute old ring does not reopen incoming UI', () async {
    final signaling = _FakeSignaling();
    final controller = CallController(signaling: signaling);
    await controller.start('amy');
    signaling.rings.add([
      CallDoc.fromDoc(
        _CallSnapshot({
          'caller': 'bob',
          'callee': 'amy',
          'kind': 'audio',
          'status': 'ringing',
          'createdAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        }),
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.ringing, isEmpty);
    await controller.stop();
    await signaling.rings.close();
  });

  test(
    'signing in keeps the account after an earlier sign-out settles',
    () async {
      final controller = CallController(signaling: _FakeSignaling());

      // start() used to fire stop() without waiting, and that stop then cleared
      // the account it had just been given, so every later call failed silently.
      controller.start('first_user');
      await controller.start('second_user');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(controller.account, 'second_user');

      await controller.stop();
      expect(controller.account, isNull);
    },
  );

  test('pairId is the same from either side', () {
    expect(pairId('amy', 'bob'), pairId('bob', 'amy'));
    expect(pairId('amy', 'bob'), 'amy__bob');
  });
}
