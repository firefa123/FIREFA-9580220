import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';

FirefaOrder _order({required FirefaOrderStatus status}) => FirefaOrder(
  id: 'ORD-RECONCILE-1',
  outletId: 'reconcile-outlet',
  orderType: 'Take Away',
  tableId: null,
  createdAt: DateTime.utc(2026, 10, 13),
  items: const [
    FirefaOrderItem(productName: 'Tea', quantity: 1, unitPrice: 1000),
  ],
  subtotal: 1000,
  discount: 0,
  tax: 0,
  service: 0,
  total: 1000,
  status: status,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reconciliation chooses newest event even when backup order is reversed', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = FirefaOfflineSyncQueue.instance;
    await queue.initialize();

    final olderOrder = _order(status: FirefaOrderStatus.confirmed);
    queue.enqueueOrder(olderOrder, 'order.created');
    final latestOrder = _order(status: FirefaOrderStatus.preparing);
    queue.enqueueOrder(latestOrder, 'order.updated');
    await queue.waitForPendingSave();

    final snapshot = queue.exportSnapshot();
    final entries = List<dynamic>.from(snapshot['entries'] as List).reversed.toList();
    queue.restoreCombinedSnapshot({
      ...snapshot,
      'entries': entries,
    });
    await queue.waitForPendingSave();

    expect(queue.reconcileOrders([latestOrder]), 0);
    expect(queue.entriesForOutlet('reconcile-outlet'), hasLength(2));

    for (final entry in queue.entriesForOutlet('reconcile-outlet')) {
      await queue.removeEvent(entry.eventId);
    }
    await queue.waitForPendingSave();
  });
}
