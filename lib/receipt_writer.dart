import 'dart:async';

typedef ReceiptWrite =
    Future<void> Function({required bool delivered, required bool read});

/// Coalesces receipt updates while server timestamps are still unresolved.
/// Successful stamps are remembered until the account session is cleared.
class ReceiptWriter {
  final Map<String, _ReceiptState> _receipts = {};

  void stamp(
    String id, {
    required bool delivered,
    required bool read,
    required bool reading,
    required ReceiptWrite write,
  }) {
    final receipt = _receipts.putIfAbsent(id, () => _ReceiptState(write));
    receipt
      ..delivered = receipt.delivered || delivered
      ..read = receipt.read || read
      ..reading = receipt.reading || reading
      ..write = write;
    if (receipt.pending || receipt.failed) return;
    if (receipt.delivered && (!receipt.reading || receipt.read)) return;
    receipt.pending = true;
    unawaited(_drain(id, receipt));
  }

  Future<void> _drain(String id, _ReceiptState receipt) async {
    try {
      while (identical(_receipts[id], receipt)) {
        final delivered = !receipt.delivered;
        final read = receipt.reading && !receipt.read;
        if (!delivered && !read) return;
        await receipt.write(delivered: delivered, read: read);
        receipt
          ..delivered = receipt.delivered || delivered
          ..read = receipt.read || read;
        // A read request may have arrived while delivery was in flight. The
        // next iteration sends only that missing field, never delivery again.
      }
    } catch (_) {
      // Repeated snapshots must not become retries after a quota failure.
      // A fresh session can try again after clear().
      receipt.failed = true;
    } finally {
      // clear() can replace an entry with another account's pending receipt.
      if (identical(_receipts[id], receipt)) receipt.pending = false;
    }
  }

  /// Invalidate cached receipts and follow-up work when the session changes.
  /// An already submitted backend write cannot be cancelled here.
  void clear() => _receipts.clear();
}

class _ReceiptState {
  _ReceiptState(this.write);

  ReceiptWrite write;
  bool delivered = false;
  bool read = false;
  bool reading = false;
  bool pending = false;
  bool failed = false;
}
