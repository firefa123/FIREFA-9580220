import 'offline_sync_queue.dart';
import 'sync_adapter.dart';

/// Safe preparation layer for a future authenticated sync worker.
/// Does not mutate the queue, perform network requests, or mark events synced.
class FirefaSyncEngine {
  const FirefaSyncEngine();

  /// FIFO selection scoped to one outlet. Failed entries may be retried by
  /// a future worker; synced and in-flight events must never be resent here.
  List<FirefaSyncEnvelope> pendingBatch({
    required FirefaOfflineSyncQueue queue,
    required String outletId,
    int limit = 25,
  }) {
    if (outletId.trim().isEmpty) {
      throw ArgumentError.value(outletId, 'outletId', 'Outlet wajib dipilih');
    }
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    final entries = queue.entriesForOutlet(outletId)
        .where((entry) => entry.status == FirefaSyncStatus.pending)
        .toList()
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.eventId.compareTo(b.eventId);
      });
    return List.unmodifiable(
      entries.take(limit).map(FirefaSyncEnvelope.fromEntry),
    );
  }

  /// Validate a backend receipt before the future worker is allowed to
  /// transition an event to synced. Never trust a success flag alone.
  bool isValidAcknowledgement(
    FirefaSyncEnvelope envelope,
    FirefaSyncReceipt receipt,
  ) => receipt.acknowledges(envelope);

  /// Exponential retry delay capped at five minutes. This is a policy helper
  /// only; it does not schedule timers or send any requests.
  Duration retryDelay(int attempts) {
    if (attempts < 0) {
      throw ArgumentError.value(attempts, 'attempts');
    }
    final exponent = attempts > 8 ? 8 : attempts;
    final seconds = 1 << exponent;
    return Duration(seconds: seconds > 300 ? 300 : seconds);
  }
}
