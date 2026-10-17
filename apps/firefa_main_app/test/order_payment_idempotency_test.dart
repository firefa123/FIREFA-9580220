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

  test('payment transition is idempotent and cancelled order stays unpaid', () async {
    final store = FirefaOrderStore.instance;
    final queue = FirefaOfflineSyncQueue.instance;
    await store.initialize();
    await queue.initialize();

    final order = store.createOrder(
      outletId: 'payment-idempotency-outlet',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(productName: 'Coffee', quantity: 1, unitPrice: 15000),
      ],
      subtotal: 15000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 15000,
    );
    await store.waitForPendingSave();
    await queue.waitForPendingSave();

    expect(store.markPaid(order.outletId, order.id), isTrue);
    await store.waitForPendingSave();
    await queue.waitForPendingSave();
    final afterFirstPayment = queue.entriesForOutlet(order.outletId).length;

    expect(store.markPaid(order.outletId, order.id), isFalse);
    expect(queue.entriesForOutlet(order.outletId), hasLength(afterFirstPayment));
    expect(order.paymentStatus, FirefaPaymentStatus.paid);

    final cancelled = store.createOrder(
      outletId: order.outletId,
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(productName: 'Tea', quantity: 1, unitPrice: 8000),
      ],
      subtotal: 8000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 8000,
    );
    expect(store.cancel(order.outletId, cancelled.id), isTrue);
    expect(store.markPaid(order.outletId, cancelled.id), isFalse);
    expect(cancelled.status, FirefaOrderStatus.cancelled);
    expect(cancelled.paymentStatus, FirefaPaymentStatus.unpaid);

    await store.waitForPendingSave();
    await queue.waitForPendingSave();
  });
}
