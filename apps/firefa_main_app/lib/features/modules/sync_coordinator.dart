import 'conflict_management.dart';
import 'conflict_store.dart';
import 'hybrid_sync_conflict_bridge.dart';
import 'offline_sync_queue.dart';
import 'sync_adapter.dart';
import 'sync_engine.dart';

/// Connects an adapter response to the durable outbox and conflict inbox.
/// This coordinator does not provide transport or authentication by itself.
class FirefaSyncCoordinator {
  final FirefaOfflineSyncQueue queue;
  final FirefaSyncAdapter adapter;
  final FirefaHybridSyncConflictBridge conflictBridge;
  final FirefaSyncEngine engine;

  const FirefaSyncCoordinator({
    required this.queue,
    required this.adapter,
    required this.conflictBridge,
    this.engine = const FirefaSyncEngine(),
  });

  Future<FirefaSyncRunSummary> syncOutlet(
    String outletId, {
    int limit = 25,
  }) async {
    final batch = engine.pendingBatch(
      queue: queue,
      outletId: outletId,
      limit: limit,
    );
    var acknowledged = 0;
    var conflicts = 0;
    var retryableFailures = 0;

    for (final envelope in batch) {
      try {
        final receipt = await adapter.send(envelope);
        if (receipt.outcome == FirefaSyncOutcome.acknowledged &&
            engine.isValidAcknowledgement(envelope, receipt)) {
          await queue.markSynced(envelope.eventId);
          acknowledged++;
          continue;
        }

        if (receipt.outcome == FirefaSyncOutcome.conflict) {
          final local = queue.findEvent(envelope.eventId);
          final snapshot = receipt.serverSnapshot;
          final serverOutletId = receipt.serverOutletId;
          final serverOrderId = receipt.serverOrderId;
          if (local == null ||
              snapshot == null ||
              serverOutletId == null ||
              serverOrderId == null) {
            retryableFailures++;
            continue;
          }
          final created = await conflictBridge.processServerMismatch(
            local: local,
            outletId: serverOutletId,
            orderId: serverOrderId,
            serverSnapshot: snapshot,
            kind: receipt.conflictKind ??
                FirefaConflictKind.invalidServerResponse,
          );
          if (created) {
            conflicts++;
          } else {
            // Identical snapshots need no conflict, but a conflict receipt
            // must not be treated as a verified acknowledgement.
            retryableFailures++;
          }
          continue;
        }

        // Retryable/permanent failures and invalid acknowledgements stay out
        // of the synced state until a verified contract is received.
        retryableFailures++;
      } catch (_) {
        // Preserve the event for a later retry. Never report false success.
        retryableFailures++;
      }
    }

    return FirefaSyncRunSummary(
      attempted: batch.length,
      acknowledged: acknowledged,
      conflicts: conflicts,
      retryableFailures: retryableFailures,
    );
  }
}

class FirefaSyncRunSummary {
  final int attempted;
  final int acknowledged;
  final int conflicts;
  final int retryableFailures;

  const FirefaSyncRunSummary({
    required this.attempted,
    required this.acknowledged,
    required this.conflicts,
    required this.retryableFailures,
  });
}
