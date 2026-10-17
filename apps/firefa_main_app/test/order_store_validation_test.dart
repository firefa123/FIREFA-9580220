import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('order creation rejects item subtotal mismatch without creating order', () async {
    final store = FirefaOrderStore.instance;
    await store.initialize();

    expect(
      () => store.createOrder(
        outletId: 'outlet-order-validation',
        orderType: 'Take Away',
        tableId: null,
        items: const [
          FirefaOrderItem(productName: 'Kopi', quantity: 2, unitPrice: 10000),
        ],
        subtotal: 15000,
        discount: 0,
        tax: 0,
        service: 0,
        total: 15000,
      ),
      throwsArgumentError,
    );

    expect(store.ordersForOutlet('outlet-order-validation'), isEmpty);
  });

  test('order creation rejects invalid item quantities and names', () async {
    final store = FirefaOrderStore.instance;
    await store.initialize();

    for (final item in const [
      FirefaOrderItem(productName: 'Kopi', quantity: 0, unitPrice: 10000),
      FirefaOrderItem(productName: 'Kopi', quantity: -1, unitPrice: 10000),
      FirefaOrderItem(productName: '  ', quantity: 1, unitPrice: 10000),
      FirefaOrderItem(productName: 'Kopi', quantity: 1, unitPrice: -1),
    ]) {
      expect(
        () => store.createOrder(
          outletId: 'outlet-order-validation',
          orderType: 'Take Away',
          tableId: null,
          items: [item],
          subtotal: item.quantity * item.unitPrice,
          discount: 0,
          tax: 0,
          service: 0,
          total: item.quantity * item.unitPrice,
        ),
        throwsArgumentError,
      );
    }

    expect(store.ordersForOutlet('outlet-order-validation'), isEmpty);
  });

  test('order creation accepts matching financial snapshot and preserves details', () async {
    final store = FirefaOrderStore.instance;
    await store.initialize();

    final order = store.createOrder(
      outletId: 'outlet-order-validation',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(
          productName: 'Kopi Susu',
          quantity: 2,
          unitPrice: 15000,
          details: 'Less ice',
        ),
      ],
      subtotal: 30000,
      discount: 5000,
      tax: 2500,
      service: 0,
      total: 27500,
    );

    expect(order.subtotal, 30000);
    expect(order.total, 27500);
    expect(order.items.single.details, 'Less ice');
    await store.waitForPendingSave();
  });
}
