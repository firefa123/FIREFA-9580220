import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';

FirefaOrder _order({
  required String id,
  required String outletId,
  FirefaOrderStatus status = FirefaOrderStatus.confirmed,
}) {
  return FirefaOrder(
    id: id,
    outletId: outletId,
    orderType: 'Take Away',
    tableId: null,
    createdAt: DateTime.utc(2026, 10, 13),
    items: const [
      FirefaOrderItem(productName: 'Coffee', quantity: 1, unitPrice: 10000),
    ],
    subtotal: 10000,
    discount: 0,
    tax: 0,
    service: 0,
    total: 10000,
    status: status,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('outbox retry is outlet-scoped and order recovery is idempotent', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = FirefaOfflineSyncQueue.instance;
    await queue.initialize();

    final failedOrder = _order(id: 'ORD-QUEUE-1', outletId: 'outlet-A');
    final otherOrder = _order(id: 'ORD-QUEUE-2', outletId: 'outlet-B');
    final failedEvent = queue.enqueueOrder(failedOrder, 'order.created');
    final otherEvent = queue.enqueueOrder(otherOrder, 'order.created');
    await queue.waitForPendingSave();

    await queue.markSyncing(failedEvent.eventId);
    await queue.markFailed(failedEvent.eventId);
    await queue.markSyncing(otherEvent.eventId);
    await queue.markFailed(otherEvent.eventId);

    expect(await queue.retryFailedForOutlet('outlet-A'), 1);
    expect(queue.findEvent(failedEvent.eventId)!.status, FirefaSyncStatus.pending);
    expect(queue.findEvent(otherEvent.eventId)!.status, FirefaSyncStatus.failed);

    final repaired = queue.reconcileOrders([
      _order(
        id: 'ORD-QUEUE-1',
        outletId: 'outlet-A',
        status: FirefaOrderStatus.ready,
      ),
    ]);
    expect(repaired, 1);
    await queue.waitForPendingSave();

    final repairEvents = queue.entriesForOutlet('outlet-A')
        .where((entry) => entry.eventType == 'order.recovered')
        .toList();
    expect(repairEvents, hasLength(1));
    expect(repairEvents.single.orderSnapshot['status'], 'ready');

    expect(
      queue.reconcileOrders([
        _order(
          id: 'ORD-QUEUE-1',
          outletId: 'outlet-A',
          status: FirefaOrderStatus.ready,
        ),
      ]),
      0,
    );
    await queue.waitForPendingSave();
    expect(
      queue.entriesForOutlet('outlet-A')
          .where((entry) => entry.eventType == 'order.recovered'),
      hasLength(1),
    );
  });
}
