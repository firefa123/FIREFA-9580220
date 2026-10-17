import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/inventory_store.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';
import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inventory = FirefaInventoryStore.instance;
  final orders = FirefaOrderStore.instance;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FirefaOfflineSyncQueue.instance.initialize();
    await inventory.initialize();
    await orders.initialize();
  });

  test('cancelling an unpaid POS order restores its stock exactly once', () async {
    const outletId = 'outlet-001';
    const menuId = 'test-cancel-menu';
    expect(inventory.add(
      outletId: outletId,
      name: 'Cancellation test ingredient',
      unit: 'gram',
      stock: 80,
      minimumStock: 0,
    ), isTrue);
    final ingredient = inventory.forOutlet(outletId)
        .singleWhere((item) => item.name == 'Cancellation test ingredient');
    expect(inventory.addRecipeLine(
      outletId: outletId,
      menuId: menuId,
      ingredientId: ingredient.id,
      quantity: 10,
    ), isTrue);
    await inventory.waitForPendingSave();

    final order = orders.createOrder(
      outletId: outletId,
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(
          productName: 'Cancellation test menu',
          productId: menuId,
          quantity: 2,
          unitPrice: 500,
        ),
      ],
      subtotal: 1000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 1000,
    );
    await orders.waitForPendingSave();
    expect(await inventory.consumeOrderStock(
      orderId: order.id,
      outletId: outletId,
      menuLines: [(menuId: menuId, quantity: 2)],
    ), isTrue);
    expect(inventory.forOutlet(outletId)
        .singleWhere((item) => item.id == ingredient.id).stock, 60);

    expect(await orders.cancelAndRestoreStock(outletId, order.id), isTrue);
    expect(order.status, FirefaOrderStatus.cancelled);
    expect(inventory.forOutlet(outletId)
        .singleWhere((item) => item.id == ingredient.id).stock, 80);
    expect(await orders.cancelAndRestoreStock(outletId, order.id), isFalse);
    expect(inventory.forOutlet(outletId)
        .singleWhere((item) => item.id == ingredient.id).stock, 80);
    await orders.waitForPendingSave();
    await inventory.waitForPendingSave();
  });
}
