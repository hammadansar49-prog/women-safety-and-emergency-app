import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/username_check.dart';

void main() {
  test('shows the Bloom hint at once, then the database verdict', () async {
    final checker = UsernameChecker(
      quick: (n) => n == 'fresh_name' ? true : null,
      confirm: (n) async => n == 'taken_one' ? false : (n == 'offline' ? null : true),
    );
    checker.update('fresh_name');
    expect(checker.state, UsernameState.available); // instant, before any wait
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(checker.state, UsernameState.available);

    checker.update('Taken_One ');
    expect(checker.name, 'taken_one');
    expect(checker.state, UsernameState.checking);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(checker.state, UsernameState.taken);
    expect(checker.isTaken, isTrue);

    checker.update('offline');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(checker.state, UsernameState.unknown); // cannot tell, never blocks

    checker.update('ab');
    expect(checker.state, UsernameState.invalid);
    checker.update('');
    expect(checker.state, UsernameState.idle);
    checker.dispose();
  });

  test('a slow answer for an older name never overwrites the newer one', () async {
    final checker = UsernameChecker(
      confirm: (n) async {
        if (n == 'old_name') await Future<void>.delayed(const Duration(milliseconds: 600));
        return n != 'old_name';
      },
    );
    checker.update('old_name');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    checker.update('new_name');
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    expect(checker.name, 'new_name');
    expect(checker.state, UsernameState.available);
    checker.dispose();
  });
}
