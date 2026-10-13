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
    await queue.markSyncing(event.eventId);
    await queue.markConflict(event.eventId);
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

  test('conflict reconciliation rejects event IDs belonging to another outlet', () async {
    final orders = FirefaOrderStore.instance;
    final queue = FirefaOfflineSyncQueue.instance;
    await orders.initialize();
    await queue.initialize();

    final target = orders.createOrder(
      outletId: 'conflict-target-outlet',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(productName: 'Target', quantity: 1, unitPrice: 1000),
      ],
      subtotal: 1000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 1000,
    );
    final other = FirefaOrder(
      id: 'foreign-conflict-order',
      outletId: 'foreign-conflict-outlet',
      orderType: 'Take Away',
      tableId: null,
      createdAt: DateTime.utc(2026, 10, 13),
      items: const [
        FirefaOrderItem(productName: 'Foreign', quantity: 1, unitPrice: 2000),
      ],
      subtotal: 2000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 2000,
    );
    await orders.waitForPendingSave();

    final foreignEvent = queue.enqueueOrder(other, 'order.updated');
    await queue.waitForPendingSave();
    await queue.markSyncing(foreignEvent.eventId);
    await queue.markConflict(foreignEvent.eventId);

    expect(
      () => orders.reconcileConflict(
        eventId: foreignEvent.eventId,
        outletId: target.outletId,
        orderId: target.id,
        acceptServer: false,
      ),
      throwsStateError,
    );
    expect(queue.findEvent(foreignEvent.eventId), isNotNull);
    expect(orders.findOrder(target.outletId, target.id)!.status,
        FirefaOrderStatus.confirmed);

    await queue.removeEvent(foreignEvent.eventId);
    await queue.waitForPendingSave();
  });

  test('conflict reconciliation refuses a pending event before resolution', () async {
    final orders = FirefaOrderStore.instance;
    final queue = FirefaOfflineSyncQueue.instance;
    await orders.initialize();
    await queue.initialize();

    final order = orders.createOrder(
      outletId: 'conflict-pending-guard-outlet',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(productName: 'Juice', quantity: 1, unitPrice: 3500),
      ],
      subtotal: 3500,
      discount: 0,
      tax: 0,
      service: 0,
      total: 3500,
    );
    await orders.waitForPendingSave();

    final event = queue.enqueueOrder(order, 'order.updated');
    await queue.waitForPendingSave();

    expect(
      () => orders.reconcileConflict(
        eventId: event.eventId,
        outletId: order.outletId,
        orderId: order.id,
        acceptServer: false,
      ),
      throwsStateError,
    );
    expect(queue.findEvent(event.eventId), isNotNull);
    await queue.removeEvent(event.eventId);
    await queue.waitForPendingSave();
  });

  test('keep local conflict decision queues retained order snapshot', () async {
    final orders = FirefaOrderStore.instance;
    final queue = FirefaOfflineSyncQueue.instance;
    await orders.initialize();
    await queue.initialize();

    final order = orders.createOrder(
      outletId: 'conflict-keep-local-outlet',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(productName: 'Bread', quantity: 1, unitPrice: 4000),
      ],
      subtotal: 4000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 4000,
    );
    await orders.waitForPendingSave();

    final event = queue.enqueueOrder(order, 'order.updated');
    await queue.waitForPendingSave();
    await queue.markSyncing(event.eventId);
    await queue.markConflict(event.eventId);

    await orders.reconcileConflict(
      eventId: event.eventId,
      outletId: order.outletId,
      orderId: order.id,
      acceptServer: false,
    );

    expect(queue.findEvent(event.eventId), isNull);
    final retained = queue.entriesForOutlet(order.outletId)
        .where((entry) => entry.orderId == order.id && entry.eventType == 'order.updated')
        .toList();
    expect(retained, hasLength(1));
    expect(retained.single.orderSnapshot['id'], order.id);
    expect(retained.single.orderSnapshot['status'], order.status.name);
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
    await queue.markSyncing(event.eventId);
    await queue.markConflict(event.eventId);
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
