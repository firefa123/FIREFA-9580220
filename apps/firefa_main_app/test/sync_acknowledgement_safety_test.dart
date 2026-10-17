import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/conflict_store.dart';
import 'package:firefa_main_app/features/modules/hybrid_sync_conflict_bridge.dart';
import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/sync_adapter.dart';
import 'package:firefa_main_app/features/modules/sync_coordinator.dart';

class _MismatchedAcknowledgementAdapter extends FirefaSyncAdapter {
  const _MismatchedAcknowledgementAdapter();

  @override
  Future<FirefaSyncReceipt> send(FirefaSyncEnvelope event) async =>
      const FirefaSyncReceipt(
        eventId: 'evt-not-the-requested-event',
        outcome: FirefaSyncOutcome.acknowledged,
        serverReference: 'receipt-but-wrong-event',
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mismatched acknowledgement never marks an outbox event synced', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = FirefaOfflineSyncQueue.instance;
    await queue.initialize();
    await FirefaConflictStore.instance.initialize();

    final order = FirefaOrder(
      id: 'ORD-ACK-TEST',
      outletId: 'ack-validation-outlet',
      orderType: 'Take Away',
      tableId: null,
      createdAt: DateTime.utc(2026, 10, 13),
      items: const [
        FirefaOrderItem(productName: 'Test', quantity: 1, unitPrice: 1000),
      ],
      subtotal: 1000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 1000,
    );
    final event = queue.enqueueOrder(order, 'order.created');
    await queue.waitForPendingSave();

    final coordinator = FirefaSyncCoordinator(
      queue: queue,
      adapter: const _MismatchedAcknowledgementAdapter(),
      conflictBridge: FirefaHybridSyncConflictBridge(
        store: FirefaConflictStore.instance,
      ),
    );

    final summary = await coordinator.syncOutlet(order.outletId);

    expect(summary.attempted, 1);
    expect(summary.acknowledged, 0);
    expect(summary.retryableFailures, 1);
    expect(event.status, FirefaSyncStatus.pending);
    expect(event.nextAttemptAt, isNotNull);
    expect(event.nextAttemptAt!.isAfter(DateTime.now().toUtc()), isTrue);

    await queue.removeEvent(event.eventId);
    await queue.waitForPendingSave();
  });
}
