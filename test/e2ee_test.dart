import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/e2ee.dart';

void main() {
  test('two friends read each other, an outsider and a replay cannot', () async {
    const e = E2ee();
    final a = await e.newIdentity();
    final b = await e.newIdentity();
    final eve = await e.newIdentity();

    final sealed = await e.encrypt(
      myPriv: a.priv,
      theirPub: b.pub,
      pair: 'amy__bob',
      text: 'meet me at the gate',
    );
    expect(sealed, isNot(contains('gate')));

    expect(
      await e.decrypt(
        myPriv: b.priv,
        theirPub: a.pub,
        pair: 'amy__bob',
        sealed: sealed,
      ),
      'meet me at the gate',
    );
    // The sender can read her own message back too.
    expect(
      await e.decrypt(
        myPriv: a.priv,
        theirPub: b.pub,
        pair: 'amy__bob',
        sealed: sealed,
      ),
      'meet me at the gate',
    );
    // An outsider with the public keys but not a private key cannot.
    expect(
      () => e.decrypt(
        myPriv: eve.priv,
        theirPub: a.pub,
        pair: 'amy__bob',
        sealed: sealed,
      ),
      throwsA(isA<DecryptFailure>()),
    );
    // Moved into another conversation it no longer opens.
    expect(
      () => e.decrypt(
        myPriv: b.priv,
        theirPub: a.pub,
        pair: 'amy__cat',
        sealed: sealed,
      ),
      throwsA(isA<DecryptFailure>()),
    );
    expect(await e.publicFromPrivate(a.priv), a.pub);
  });
}
