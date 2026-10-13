import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('invalid server conflict snapshot preserves local order and event', () async {
    final orders = FirefaOrderStore.instance;
    final queue = FirefaOfflineSyncQueue.instance;
    await orders.initialize();
    await queue.initialize();

    final order = orders.createOrder(
      outletId: 'conflict-validation-outlet',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(productName: 'Coffee', quantity: 2, unitPrice: 5000),
      ],
      subtotal: 10000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 10000,
    );
    await orders.waitForPendingSave();

    final event = queue.enqueueOrder(order, 'order.updated');
    await queue.waitForPendingSave();
    final invalidServerSnapshot = Map<String, dynamic>.from(order.toJson())
      ..['status'] = FirefaOrderStatus.served.name
      ..['total'] = 1;

    expect(
      () => orders.reconcileConflict(
        eventId: event.eventId,
        outletId: order.outletId,
        orderId: order.id,
        acceptServer: true,
        serverSnapshot: invalidServerSnapshot,
      ),
      throwsFormatException,
    );

    expect(orders.findOrder(order.outletId, order.id)!.status,
        FirefaOrderStatus.confirmed);
    expect(queue.findEvent(event.eventId), isNotNull);
    await orders.waitForPendingSave();
  });

  test('accept server conflict snapshot updates order and retires stale event', () async {
    final orders = FirefaOrderStore.instance;
    final queue = FirefaOfflineSyncQueue.instance;
    await orders.initialize();
    await queue.initialize();

    final order = orders.createOrder(
      outletId: 'conflict-accept-outlet',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(productName: 'Tea', quantity: 1, unitPrice: 3000),
      ],
      subtotal: 3000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 3000,
    );
    await orders.waitForPendingSave();

    final event = queue.enqueueOrder(order, 'order.updated');
    await queue.waitForPendingSave();
    final serverSnapshot = Map<String, dynamic>.from(order.toJson())
      ..['status'] = FirefaOrderStatus.preparing.name;

    await orders.reconcileConflict(
      eventId: event.eventId,
      outletId: order.outletId,
      orderId: order.id,
      acceptServer: true,
      serverSnapshot: serverSnapshot,
    );

    expect(orders.findOrder(order.outletId, order.id)!.status,
        FirefaOrderStatus.preparing);
    expect(queue.findEvent(event.eventId), isNull);
    await orders.waitForPendingSave();
  });
}
