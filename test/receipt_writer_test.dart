import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/receipt_writer.dart';

void main() {
  test('repeated stale snapshots share one pending delivery write', () async {
    final writer = ReceiptWriter();
    final pending = Completer<void>();
    final writes = <({bool delivered, bool read})>[];
    Future<void> write({required bool delivered, required bool read}) {
      writes.add((delivered: delivered, read: read));
      return pending.future;
    }

    for (var i = 0; i < 20; i++) {
      writer.stamp(
        'message',
        delivered: false,
        read: false,
        reading: false,
        write: write,
      );
    }
    expect(writes, [(delivered: true, read: false)]);
    pending.complete();
    await Future<void>.delayed(Duration.zero);
    writer.stamp(
      'message',
      delivered: false,
      read: false,
      reading: false,
      write: write,
    );
    expect(writes, hasLength(1));
  });

  test('read intent during delivery becomes one serial follow-up', () async {
    final writer = ReceiptWriter();
    final delivery = Completer<void>();
    final writes = <({bool delivered, bool read})>[];
    Future<void> write({required bool delivered, required bool read}) {
      writes.add((delivered: delivered, read: read));
      return writes.length == 1 ? delivery.future : Future<void>.value();
    }

    writer.stamp(
      'message',
      delivered: false,
      read: false,
      reading: false,
      write: write,
    );
    for (var i = 0; i < 20; i++) {
      writer.stamp(
        'message',
        delivered: false,
        read: false,
        reading: true,
        write: write,
      );
    }
    expect(writes, hasLength(1));
    delivery.complete();
    await Future<void>.delayed(Duration.zero);
    expect(writes, [
      (delivered: true, read: false),
      (delivered: false, read: true),
    ]);
  });

  test('already stamped receipts need no writes', () {
    final writer = ReceiptWriter();
    var writes = 0;
    writer.stamp(
      'message',
      delivered: true,
      read: true,
      reading: true,
      write: ({required delivered, required read}) async {
        writes++;
      },
    );
    expect(writes, 0);
  });

  test('an open conversation stamps delivery and read together', () async {
    final writer = ReceiptWriter();
    final writes = <({bool delivered, bool read})>[];
    writer.stamp(
      'message',
      delivered: false,
      read: false,
      reading: true,
      write: ({required delivered, required read}) async {
        writes.add((delivered: delivered, read: read));
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(writes, [(delivered: true, read: true)]);
  });

  test('a failed receipt retries a bounded number of times', () async {
    final writer = ReceiptWriter();
    var writes = 0;
    Future<void> write({required bool delivered, required bool read}) async {
      writes++;
      throw StateError('quota exceeded');
    }

    writer.stamp(
      'message',
      delivered: false,
      read: false,
      reading: false,
      write: write,
    );
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 20; i++) {
      writer.stamp(
        'message',
        delivered: false,
        read: false,
        reading: true,
        write: write,
      );
      await Future<void>.delayed(Duration.zero);
    }
    // A dropped connection may clear, so a later snapshot tries again, but
    // repeated snapshots can never turn a hard rejection into a write loop.
    expect(writes, 3);
    writer.clear();
    writer.stamp(
      'message',
      delivered: false,
      read: false,
      reading: false,
      write: write,
    );
    await Future<void>.delayed(Duration.zero);
    // clear() forgets the attempts too, so a fresh session starts over.
    expect(writes, 4);
  });

  test('old session completion cannot disturb new pending receipts', () async {
    final writer = ReceiptWriter();
    final oldPending = Completer<void>();
    final newPending = Completer<void>();
    var oldWrites = 0;
    var newWrites = 0;
    Future<void> oldWrite({required bool delivered, required bool read}) {
      oldWrites++;
      return oldPending.future;
    }

    Future<void> newWrite({required bool delivered, required bool read}) {
      newWrites++;
      return newPending.future;
    }

    writer.stamp(
      'same-id',
      delivered: false,
      read: false,
      reading: false,
      write: oldWrite,
    );
    writer.stamp(
      'same-id',
      delivered: false,
      read: false,
      reading: true,
      write: oldWrite,
    );
    writer.clear();
    writer.stamp(
      'same-id',
      delivered: false,
      read: false,
      reading: false,
      write: newWrite,
    );
    oldPending.complete();
    await Future<void>.delayed(Duration.zero);
    writer.stamp(
      'same-id',
      delivered: false,
      read: false,
      reading: false,
      write: newWrite,
    );
    expect(oldWrites, 1);
    expect(newWrites, 1);
    newPending.complete();
    await Future<void>.delayed(Duration.zero);
  });
}
