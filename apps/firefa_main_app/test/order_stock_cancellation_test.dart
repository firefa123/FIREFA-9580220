import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/inventory_store.dart' as legacy;
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stock processing and reversal are isolated by outlet for reused order IDs', () async {
    SharedPreferences.setMockInitialValues({});
    final store = legacy.FirefaInventoryStore.instance;
    await store.initialize();

    for (final outlet in ['SCOPE-A', 'SCOPE-B']) {
      expect(store.add(
        outletId: outlet, name: 'Scoped beans', unit: 'gram',
        stock: 10, minimumStock: 0,
      ), isTrue);
      final beans = store.forOutlet(outlet).singleWhere(
        (item) => item.name == 'Scoped beans',
      );
      expect(store.addRecipeLine(
        outletId: outlet, menuId: 'scoped-coffee',
        ingredientId: beans.id, quantity: 2,
      ), isTrue);
    }

    expect(await store.consumeOrderStock(
      orderId: 'ORD-1001', outletId: 'SCOPE-A',
      menuLines: [(menuId: 'scoped-coffee', quantity: 2)],
    ), isTrue);
    expect(await store.consumeOrderStock(
      orderId: 'ORD-1001', outletId: 'SCOPE-B',
      menuLines: [(menuId: 'scoped-coffee', quantity: 2)],
    ), isTrue);
    expect(store.forOutlet('SCOPE-A').single.stock, 6);
    expect(store.forOutlet('SCOPE-B').single.stock, 6);

    expect(await store.restoreCancelledOrderStock(
      orderId: 'ORD-1001', outletId: 'SCOPE-A',
    ), isTrue);
    expect(store.forOutlet('SCOPE-A').single.stock, 10);
    expect(store.forOutlet('SCOPE-B').single.stock, 6);
    expect(await store.restoreCancelledOrderStock(
      orderId: 'ORD-1001', outletId: 'SCOPE-B',
    ), isTrue);
    expect(store.forOutlet('SCOPE-B').single.stock, 10);
    expect(await store.restoreCancelledOrderStock(
      orderId: 'ORD-1001', outletId: 'SCOPE-B',
    ), isFalse);

    expect(store.isOrderStockProcessed('ORD-1001', outletId: 'SCOPE-A'), isTrue);
    expect(store.isOrderStockReversed('ORD-1001', outletId: 'SCOPE-A'), isTrue);
    await store.waitForPendingSave();
  });

  test('cancelling unpaid POS order restores recipe stock exactly once', () async {
    SharedPreferences.setMockInitialValues({});
    final inventory = legacy.FirefaInventoryStore.instance;
    final orders = FirefaOrderStore.instance;
    await inventory.initialize();
    await orders.initialize();

    expect(
      inventory.add(
        outletId: 'CANCEL-TEST',
        name: 'Coffee beans',
        unit: 'gram',
        stock: 20,
        minimumStock: 0,
      ),
      isTrue,
    );
    final ingredient = inventory
        .forOutlet('CANCEL-TEST')
        .singleWhere((item) => item.name == 'Coffee beans');
    expect(
      inventory.addRecipeLine(
        outletId: 'CANCEL-TEST',
        menuId: 'menu-coffee',
        ingredientId: ingredient.id,
        quantity: 2,
      ),
      isTrue,
    );

    final order = orders.createOrder(
      outletId: 'CANCEL-TEST',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(
          productName: 'Coffee',
          productId: 'menu-coffee',
          quantity: 3,
          unitPrice: 1000,
        ),
      ],
      subtotal: 3000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 3000,
    );

    expect(
      await inventory.consumeOrderStock(
        orderId: order.id,
        outletId: 'CANCEL-TEST',
        menuLines: [(menuId: 'menu-coffee', quantity: 3)],
      ),
      isTrue,
    );
    expect(inventory.forOutlet('CANCEL-TEST').single.stock, 14);

    expect(await orders.cancelAndRestoreStock('CANCEL-TEST', order.id), isTrue);
    expect(order.status, FirefaOrderStatus.cancelled);
    expect(inventory.forOutlet('CANCEL-TEST').single.stock, 20);

    expect(await orders.cancelAndRestoreStock('CANCEL-TEST', order.id), isFalse);
    expect(inventory.forOutlet('CANCEL-TEST').single.stock, 20);
    expect(inventory.isOrderStockReversed(order.id), isTrue);

    // A paid order must not be cancelled or have its stock restored.
    final paidOrder = orders.createOrder(
      outletId: 'CANCEL-TEST',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(
          productName: 'Coffee',
          productId: 'menu-coffee',
          quantity: 2,
          unitPrice: 1000,
        ),
      ],
      subtotal: 2000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 2000,
    );
    expect(
      await inventory.consumeOrderStock(
        orderId: paidOrder.id,
        outletId: 'CANCEL-TEST',
        menuLines: [(menuId: 'menu-coffee', quantity: 2)],
      ),
      isTrue,
    );
    expect(orders.markPaid('CANCEL-TEST', paidOrder.id), isTrue);
    expect(await orders.cancelAndRestoreStock('CANCEL-TEST', paidOrder.id), isFalse);
    expect(paidOrder.status, isNot(FirefaOrderStatus.cancelled));
    expect(inventory.forOutlet('CANCEL-TEST').single.stock, 16);
    expect(inventory.isOrderStockReversed(paidOrder.id), isFalse);

    // Simulate an interrupted legacy cancellation: the order is durably
    // cancelled, but the inventory reversal has not run yet.
    final interruptedOrder = orders.createOrder(
      outletId: 'CANCEL-TEST',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(
          productName: 'Coffee',
          productId: 'menu-coffee',
          quantity: 1,
          unitPrice: 1000,
        ),
      ],
      subtotal: 1000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 1000,
    );
    expect(
      await inventory.consumeOrderStock(
        orderId: interruptedOrder.id,
        outletId: 'CANCEL-TEST',
        menuLines: [(menuId: 'menu-coffee', quantity: 1)],
      ),
      isTrue,
    );
    expect(inventory.forOutlet('CANCEL-TEST').single.stock, 14);
    expect(orders.cancel('CANCEL-TEST', interruptedOrder.id), isTrue);
    await orders.waitForPendingSave();

    expect(await orders.recoverCancelledOrderStock(), 1);
    expect(inventory.forOutlet('CANCEL-TEST').single.stock, 16);
    expect(inventory.isOrderStockReversed(interruptedOrder.id), isTrue);
    expect(await orders.recoverCancelledOrderStock(), 0);
    expect(inventory.forOutlet('CANCEL-TEST').single.stock, 16);

    await orders.waitForPendingSave();
    await inventory.waitForPendingSave();

    // Verify the idempotency marker and restored quantity reached durable storage.
    final prefs = await SharedPreferences.getInstance();

    // The cancelled order and its matching sync-outbox snapshot must be
    // durable together, so a future sync cannot accidentally recreate an
    // active order after stock has already been restored.
    final rawCombined = prefs.getString('firefa_orders_outbox_v2');
    expect(rawCombined, isNotNull);
    final combined = jsonDecode(rawCombined!) as Map<String, dynamic>;
    final combinedOrders = (combined['orders'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    expect(
      combinedOrders.singleWhere((value) => value['id'] == order.id)['status'],
      FirefaOrderStatus.cancelled.name,
    );
    final outbox = Map<String, dynamic>.from(combined['outbox'] as Map);
    final cancellationEvents = (outbox['entries'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .where((entry) =>
            entry['orderId'] == order.id &&
            entry['eventType'] == 'order.updated' &&
            (entry['orderSnapshot'] as Map)['status'] ==
                FirefaOrderStatus.cancelled.name)
        .toList();
    expect(cancellationEvents, isNotEmpty);
    expect(
      cancellationEvents.every((entry) =>
          entry['outletId'] == 'CANCEL-TEST' &&
          (entry['orderSnapshot'] as Map)['paymentStatus'] ==
              FirefaPaymentStatus.unpaid.name),
      isTrue,
    );

    final rawInventory = prefs.getString(legacy.FirefaInventoryStore.storageKey);
    expect(rawInventory, isNotNull);
    final savedInventory = jsonDecode(rawInventory!) as Map<String, dynamic>;
    expect((savedInventory['reversedOrderIds'] as List).cast<String>(),
        containsAll([order.id, interruptedOrder.id]));
    final savedItems = (savedInventory['items'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    expect(
      savedItems.singleWhere((item) => item['id'] == ingredient.id)['stock'],
      16,
    );
  });
}
