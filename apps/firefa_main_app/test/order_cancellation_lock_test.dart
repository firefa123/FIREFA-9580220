import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/inventory_store.dart';
import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('async cancellation locks order against payment and status changes', () async {
    final orders = FirefaOrderStore.instance;
    final inventory = FirefaInventoryStore.instance;
    final queue = FirefaOfflineSyncQueue.instance;

    await Future.wait([
      orders.initialize(),
      inventory.initialize(),
      queue.initialize(),
    ]);

    final order = orders.createOrder(
      outletId: 'cancel-lock-outlet',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(productName: 'Coffee', quantity: 1, unitPrice: 12000),
      ],
      subtotal: 12000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 12000,
    );
    await orders.waitForPendingSave();

    // Begin cancellation. Even if local store initialization completes quickly,
    // the order must not accept payment or status transitions during this call.
    final cancellation = orders.cancelAndRestoreStock(order.outletId, order.id);
    expect(orders.markPaid(order.outletId, order.id), isFalse);
    expect(orders.advance(order.outletId, order.id), isFalse);
    expect(orders.cancel(order.outletId, order.id), isFalse);

    expect(await cancellation, isTrue);
    expect(order.status, FirefaOrderStatus.cancelled);
    expect(order.paymentStatus, FirefaPaymentStatus.unpaid);

    await orders.waitForPendingSave();
    await queue.waitForPendingSave();
  });
}
