import 'conflict_management.dart';
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

    Future<void> scheduleRetry(String eventId) async {
      final entry = queue.findEvent(eventId);
      await queue.markPending(
        eventId,
        retryDelay: engine.retryDelay(entry?.attempts ?? 0),
      );
    }

    for (final envelope in batch) {
      var markedSyncing = false;
      try {
        await queue.markSyncing(envelope.eventId);
        markedSyncing = true;
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
            await scheduleRetry(envelope.eventId);
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
            await queue.markConflict(envelope.eventId);
            conflicts++;
          } else {
            // Identical snapshots need no conflict, but a conflict receipt
            // must not be treated as a verified acknowledgement.
            await scheduleRetry(envelope.eventId);
            retryableFailures++;
          }
          continue;
        }

        // A permanent rejection is visible to the operator; other failures
        // remain retryable and never count as a successful sync.
        if (receipt.outcome == FirefaSyncOutcome.permanentFailure) {
          await queue.markFailed(envelope.eventId);
        } else {
          await scheduleRetry(envelope.eventId);
        }
        retryableFailures++;
      } catch (_) {
        // Preserve the event for a later retry. Never report false success.
        if (markedSyncing) {
          try {
            await scheduleRetry(envelope.eventId);
          } catch (_) {
            // Keep the original failure as the reported outcome.
          }
        }
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
