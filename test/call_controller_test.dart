import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/call_controller.dart';
import 'package:safeher/call_signaling.dart';
import 'package:safeher/cloud_social.dart';

/// Signalling that records what the controller asked for, with no Firestore.
class _FakeSignaling implements CallSignaling {
  final created = <String>[];
  final statuses = <String, CallStatus>{};

  @override
  Future<void> create({
    required String id,
    required String caller,
    required String callee,
    required CallKind kind,
    required Map<String, String> offer,
  }) async => created.add('$caller>$callee:${kind.name}');

  @override
  Stream<List<CallDoc>> ringingFor(String me) => const Stream.empty();

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
  Future<void> addCandidate(String id, String from, Map<String, dynamic> c) async {}

  @override
  Stream<Map<String, dynamic>> candidatesFrom(String id, String other) =>
      const Stream.empty();
}

void main() {
  test('signing in keeps the account after an earlier sign-out settles', () async {
    final controller = CallController(signaling: _FakeSignaling());

    // start() used to fire stop() without waiting, and that stop then cleared
    // the account it had just been given, so every later call failed silently.
    controller.start('first_user');
    await controller.start('second_user');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(controller.account, 'second_user');

    await controller.stop();
    expect(controller.account, isNull);
  });

  test('pairId is the same from either side', () {
    expect(pairId('amy', 'bob'), pairId('bob', 'amy'));
    expect(pairId('amy', 'bob'), 'amy__bob');
  });
}
