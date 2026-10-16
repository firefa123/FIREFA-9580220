import 'offline_sync_queue.dart';
import 'sync_adapter.dart';

/// Deterministic batch selection and acknowledgement/retry policy for the sync coordinator.
/// Queue transitions and HTTP transport are handled by their respective layers.
class FirefaSyncEngine {
  const FirefaSyncEngine();

  /// FIFO selection scoped to one outlet. Failed entries may be retried by
  /// a future worker; synced and in-flight events must never be resent here.
  List<FirefaSyncEnvelope> pendingBatch({
    required FirefaOfflineSyncQueue queue,
    required String outletId,
    int limit = 25,
    DateTime? now,
  }) {
    if (outletId.trim().isEmpty) {
      throw ArgumentError.value(outletId, 'outletId', 'Outlet wajib dipilih');
    }
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    final currentTime = (now ?? DateTime.now()).toUtc();
    final entries = queue.entriesForOutlet(outletId)
        .where((entry) =>
            entry.status == FirefaSyncStatus.pending &&
            (entry.nextAttemptAt == null ||
                !entry.nextAttemptAt!.toUtc().isAfter(currentTime)))
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

  /// Exponential retry delay with bounded jitter, capped at five minutes.
  /// This is a policy helper
  /// only; it does not schedule timers or send any requests.
  Duration retryDelay(int attempts, {int jitterMilliseconds = 0}) {
    if (attempts < 0) {
      throw ArgumentError.value(attempts, 'attempts');
    }
    if (jitterMilliseconds < 0 || jitterMilliseconds > 1000) {
      throw RangeError.range(jitterMilliseconds, 0, 1000, 'jitterMilliseconds');
    }
    final exponent = attempts > 8 ? 8 : attempts;
    final baseMilliseconds = (1 << exponent) * 1000;
    final totalMilliseconds = baseMilliseconds + jitterMilliseconds;
    return Duration(
      milliseconds: totalMilliseconds > 300000 ? 300000 : totalMilliseconds,
    );
  }
}
