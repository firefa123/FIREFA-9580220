import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/order_store.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invalid backup leaves active orders and outbox unchanged', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FirefaOrderStore.instance;
    final queue = FirefaOfflineSyncQueue.instance;
    await store.initialize();

    final order = store.createOrder(
      outletId: 'backup-atomicity-outlet',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(productName: 'Tea', quantity: 1, unitPrice: 1000),
      ],
      subtotal: 1000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 1000,
    );
    await store.waitForPendingSave();

    final beforeOrders = store.ordersForOutlet('backup-atomicity-outlet');
    final beforeEvents = queue.entriesForOutlet('backup-atomicity-outlet');
    final snapshot = store.exportLocalSnapshot();
    final orders = List<dynamic>.from(snapshot['orders'] as List);
    orders.add(orders.single);

    final invalid = <String, dynamic>{
      ...snapshot,
      'orders': orders,
    };

    expect(
      () => store.restoreLocalSnapshot(invalid),
      throwsFormatException,
    );

    expect(store.ordersForOutlet('backup-atomicity-outlet'), beforeOrders);
    expect(
      queue.entriesForOutlet('backup-atomicity-outlet').map((entry) => entry.eventId),
      beforeEvents.map((entry) => entry.eventId),
    );
    expect(store.findOrder('backup-atomicity-outlet', order.id), isNotNull);
    await store.waitForPendingSave();
  });
}
