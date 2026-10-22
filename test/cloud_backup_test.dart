import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/cloud_backup.dart';

class _MemStore implements BackupStore {
  final docs = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String uid) async => docs[uid];
  @override
  Future<void> create(String uid, Map<String, dynamic> doc) async =>
      docs[uid] = {...doc};
  @override
  Future<void> delete(String uid) async => docs.remove(uid);
  @override
  Future<void> updateData(String uid, String data) async =>
      docs[uid]!['data'] = data;
}

void main() {
  test('backup round trips, stays unreadable, and rejects a wrong code', () async {
    final store = _MemStore();
    final backup = CloudBackup(store, iterations: 1000);
    final enabled = await backup.enable('uid1', '{"secret":"hello"}');

    final blob = store.docs['uid1'].toString();
    expect(blob, isNot(contains('hello')));
    expect(enabled.recoveryCode, matches(RegExp(r'^([A-Z2-9]{4}-){4}[A-Z2-9]{4}$')));

    await backup.save('uid1', enabled.keyB64, '{"secret":"newer"}');
    final back = await backup.restore(
      'uid1',
      enabled.recoveryCode.toLowerCase().replaceAll('-', ' '),
    );
    expect(back.snapshot, '{"secret":"newer"}');
    expect(back.keyB64, enabled.keyB64);

    expect(
      () => backup.restore('uid1', 'AAAA-AAAA-AAAA-AAAA-AAAA'),
      throwsA(isA<BackupFailure>()),
    );
    expect(() => backup.restore('nobody', 'x'), throwsA(isA<BackupFailure>()));
  });
}
