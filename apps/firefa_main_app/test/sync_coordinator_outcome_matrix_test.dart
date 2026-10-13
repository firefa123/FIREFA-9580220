import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/conflict_store.dart';
import 'package:firefa_main_app/features/modules/hybrid_sync_conflict_bridge.dart';
import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/sync_adapter.dart';
import 'package:firefa_main_app/features/modules/sync_coordinator.dart';

class _ReceiptAdapter extends FirefaSyncAdapter {
  final Future<FirefaSyncReceipt> Function(FirefaSyncEnvelope event) responder;

  const _ReceiptAdapter(this.responder);

  @override
  Future<FirefaSyncReceipt> send(FirefaSyncEnvelope event) => responder(event);
}

FirefaOrder _makeOrder(String id, String outletId) => FirefaOrder(
      id: id,
      outletId: outletId,
      orderType: 'Take Away',
      tableId: null,
      createdAt: DateTime.utc(2026, 10, 13),
      items: const [
        FirefaOrderItem(productName: 'Coffee', quantity: 1, unitPrice: 2500),
      ],
      subtotal: 2500,
      discount: 0,
      tax: 0,
      service: 0,
      total: 2500,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final queue = FirefaOfflineSyncQueue.instance;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await queue.initialize();
    await FirefaConflictStore.instance.initialize();
  });

  Future<FirefaSyncCoordinator> coordinator(
    Future<FirefaSyncReceipt> Function(FirefaSyncEnvelope event) responder,
  ) async =>
      FirefaSyncCoordinator(
        queue: queue,
        adapter: _ReceiptAdapter(responder),
        conflictBridge: FirefaHybridSyncConflictBridge(
          store: FirefaConflictStore.instance,
        ),
      );

  Future<FirefaSyncEntry> enqueue(String suffix) async {
    final order = _makeOrder('COORD-$suffix', 'coordinator-outlet-$suffix');
    final event = queue.enqueueOrder(order, 'order.created');
    await queue.waitForPendingSave();
    return event;
  }

  Future<void> cleanup(FirefaSyncEntry event) async {
    await queue.removeEvent(event.eventId);
    await queue.waitForPendingSave();
  }

  test('verified acknowledgement is the only successful terminal outcome', () async {
    final event = await enqueue('ack');
    final sync = await coordinator((envelope) async => FirefaSyncReceipt(
          eventId: envelope.eventId,
          outcome: FirefaSyncOutcome.acknowledged,
          serverReference: 'receipt-${envelope.eventId}',
        ));

    final summary = await sync.syncOutlet(event.outletId);

    expect(summary.attempted, 1);
    expect(summary.acknowledged, 1);
    expect(summary.conflicts, 0);
    expect(summary.retryableFailures, 0);
    expect(event.status, FirefaSyncStatus.synced);
    expect(event.nextAttemptAt, isNull);
    await cleanup(event);
  });

  test('retryable receipt retains event and schedules a future retry', () async {
    final event = await enqueue('retryable');
    final sync = await coordinator((envelope) async => FirefaSyncReceipt(
          eventId: envelope.eventId,
          outcome: FirefaSyncOutcome.retryableFailure,
          message: 'temporary outage',
        ));

    final summary = await sync.syncOutlet(event.outletId);

    expect(summary.acknowledged, 0);
    expect(summary.retryableFailures, 1);
    expect(event.status, FirefaSyncStatus.pending);
    expect(event.nextAttemptAt, isNotNull);
    expect(event.nextAttemptAt!.isAfter(DateTime.now().toUtc()), isTrue);
    await cleanup(event);
  });

  test('permanent rejection becomes failed and never acknowledged', () async {
    final event = await enqueue('permanent');
    final sync = await coordinator((envelope) async => FirefaSyncReceipt(
          eventId: envelope.eventId,
          outcome: FirefaSyncOutcome.permanentFailure,
          message: 'payload rejected',
        ));

    final summary = await sync.syncOutlet(event.outletId);

    expect(summary.acknowledged, 0);
    expect(summary.retryableFailures, 1);
    expect(event.status, FirefaSyncStatus.failed);
    expect(event.nextAttemptAt, isNull);
    await cleanup(event);
  });

  test('incomplete conflict receipt is retried instead of discarded', () async {
    final event = await enqueue('incomplete-conflict');
    final sync = await coordinator((envelope) async => FirefaSyncReceipt(
          eventId: envelope.eventId,
          outcome: FirefaSyncOutcome.conflict,
          serverOutletId: envelope.outletId,
          // Missing order ID and server snapshot means no safe reconciliation.
        ));

    final summary = await sync.syncOutlet(event.outletId);

    expect(summary.conflicts, 0);
    expect(summary.acknowledged, 0);
    expect(summary.retryableFailures, 1);
    expect(event.status, FirefaSyncStatus.pending);
    expect(event.nextAttemptAt, isNotNull);
    await cleanup(event);
  });

  test('adapter exception preserves event for later retry', () async {
    final event = await enqueue('throws');
    final sync = await coordinator((_) async => throw StateError('network unavailable'));

    final summary = await sync.syncOutlet(event.outletId);

    expect(summary.attempted, 1);
    expect(summary.acknowledged, 0);
    expect(summary.retryableFailures, 1);
    expect(event.status, FirefaSyncStatus.pending);
    expect(event.nextAttemptAt, isNotNull);
    await cleanup(event);
  });

  test('acknowledgement without a server reference is not trusted', () async {
    final event = await enqueue('missing-reference');
    final sync = await coordinator((envelope) async => FirefaSyncReceipt(
          eventId: envelope.eventId,
          outcome: FirefaSyncOutcome.acknowledged,
          serverReference: ' ',
        ));

    final summary = await sync.syncOutlet(event.outletId);

    expect(summary.acknowledged, 0);
    expect(summary.retryableFailures, 1);
    expect(event.status, FirefaSyncStatus.pending);
    expect(event.nextAttemptAt, isNotNull);
    await cleanup(event);
  });
}
