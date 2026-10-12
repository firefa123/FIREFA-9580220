import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  FirefaOrder order({
    String id = 'backup-order',
    String outletId = 'backup-outlet',
    int quantity = 2,
    int subtotal = 2000,
    int total = 2000,
  }) => FirefaOrder(
        id: id,
        outletId: outletId,
        orderType: 'Take Away',
        tableId: null,
        createdAt: DateTime.utc(2026, 1, 1),
        items: [
          FirefaOrderItem(
            productName: 'Coffee',
            quantity: quantity,
            unitPrice: 1000,
          ),
        ],
        subtotal: subtotal,
        discount: 0,
        tax: 0,
        service: 0,
        total: total,
      );

  test('restore rejects duplicate order IDs within same outlet', () async {
    final store = FirefaOrderStore.instance;
    await store.initialize();
    final existing = store.createOrder(
      outletId: 'live-outlet',
      orderType: 'Take Away',
      tableId: null,
      items: const [FirefaOrderItem(productName: 'Tea', quantity: 1, unitPrice: 500)],
      subtotal: 500,
      discount: 0,
      tax: 0,
      service: 0,
      total: 500,
    );
    final before = store.exportLocalSnapshot();

    final invalid = {
      'version': 2,
      'nextNumber': 2000,
      'orders': [order().toJson(), order().toJson()],
      'outbox': before['outbox'],
    };

    expect(() => store.restoreLocalSnapshot(invalid), throwsFormatException);
    expect(store.ordersForOutlet('live-outlet').single.id, existing.id);
    expect(store.exportLocalSnapshot()['orders'], before['orders']);
  });

  test('restore rejects invalid financial snapshot without replacing orders', () async {
    final store = FirefaOrderStore.instance;
    await store.initialize();
    final existing = store.createOrder(
      outletId: 'live-outlet',
      orderType: 'Take Away',
      tableId: null,
      items: const [FirefaOrderItem(productName: 'Tea', quantity: 1, unitPrice: 500)],
      subtotal: 500,
      discount: 0,
      tax: 0,
      service: 0,
      total: 500,
    );
    final before = store.exportLocalSnapshot();

    final invalidOrder = order(subtotal: 999, total: 999);
    final invalid = {
      'version': 2,
      'nextNumber': 2000,
      'orders': [invalidOrder.toJson()],
      'outbox': before['outbox'],
    };

    expect(() => store.restoreLocalSnapshot(invalid), throwsFormatException);
    expect(store.ordersForOutlet('live-outlet').single.id, existing.id);
    expect(store.exportLocalSnapshot()['orders'], before['orders']);
  });
}
