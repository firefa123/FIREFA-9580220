import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('order status and demo payment persist with matching outbox snapshots',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FirefaOrderStore.instance;
    final queue = FirefaOfflineSyncQueue.instance;
    await store.initialize();

    final order = store.createOrder(
      outletId: 'LIFECYCLE-TEST',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(
          productName: 'Coffee',
          productId: 'coffee',
          quantity: 1,
          unitPrice: 12000,
        ),
      ],
      subtotal: 12000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 12000,
    );

    await store.waitForPendingSave();
    expect(
      await store.advanceAndPersist('LIFECYCLE-TEST', order.id),
      isTrue,
    );
    expect(order.status, FirefaOrderStatus.preparing);

    expect(
      await store.markPaidAndPersist('LIFECYCLE-TEST', order.id),
      isTrue,
    );
    expect(order.paymentStatus, FirefaPaymentStatus.paid);
    await store.waitForPendingSave();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('firefa_orders_outbox_v2');
    expect(raw, isNotNull);
    final snapshot = jsonDecode(raw!) as Map<String, dynamic>;
    final savedOrders = (snapshot['orders'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    final savedOrder = savedOrders.singleWhere(
      (value) => value['id'] == order.id,
    );
    expect(savedOrder['status'], FirefaOrderStatus.preparing.name);
    expect(savedOrder['paymentStatus'], FirefaPaymentStatus.paid.name);

    final events = queue.entriesForOutlet('LIFECYCLE-TEST')
        .where((entry) => entry.orderId == order.id)
        .toList();
    expect(events, hasLength(3));
    expect(events[1].orderSnapshot['status'], FirefaOrderStatus.preparing.name);
    expect(events[2].orderSnapshot['paymentStatus'], FirefaPaymentStatus.paid.name);
    expect(events[2].orderSnapshot['status'], FirefaOrderStatus.preparing.name);
    expect(events.every((entry) => entry.status == FirefaSyncStatus.pending), isTrue);
  });

  test('durable lifecycle methods reject invalid transitions without new events',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = FirefaOrderStore.instance;
    final queue = FirefaOfflineSyncQueue.instance;
    await store.initialize();

    final order = store.createOrder(
      outletId: 'LIFECYCLE-INVALID',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(
          productName: 'Tea',
          productId: 'tea',
          quantity: 1,
          unitPrice: 5000,
        ),
      ],
      subtotal: 5000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 5000,
      status: FirefaOrderStatus.cancelled,
    );
    await store.waitForPendingSave();
    final eventCount = queue.entriesForOutlet('LIFECYCLE-INVALID').length;

    expect(
      await store.advanceAndPersist('LIFECYCLE-INVALID', order.id),
      isFalse,
    );
    expect(
      await store.markPaidAndPersist('LIFECYCLE-INVALID', order.id),
      isFalse,
    );
    expect(
      queue.entriesForOutlet('LIFECYCLE-INVALID'),
      hasLength(eventCount),
    );
    expect(order.status, FirefaOrderStatus.cancelled);
    expect(order.paymentStatus, FirefaPaymentStatus.unpaid);
  });
}
