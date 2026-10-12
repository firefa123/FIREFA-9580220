import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/inventory_store.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cancelling unpaid POS order restores recipe stock exactly once', () async {
    SharedPreferences.setMockInitialValues({});
    final inventory = FirefaInventoryStore.instance;
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

    await orders.waitForPendingSave();
    await inventory.waitForPendingSave();
  });
}
