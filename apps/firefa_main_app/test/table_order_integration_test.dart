import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';
import 'package:firefa_main_app/features/modules/table_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('active dine-in orders reserve their table and prevent manual release', () async {
    SharedPreferences.setMockInitialValues({});
    final tables = FirefaTableStore.instance;
    final orders = FirefaOrderStore.instance;
    await tables.initialize();
    await orders.initialize();

    const outletId = 'TABLE-ORDER-INTEGRATION';
    expect(tables.add(outletId, 'Meja 01'), isTrue);
    final table = tables.forOutlet(outletId).single;
    expect(table.occupied, isFalse);

    final order = orders.createOrder(
      outletId: outletId,
      orderType: 'Dine In',
      tableId: 'Meja 01',
      items: const [
        FirefaOrderItem(
          productName: 'Kopi',
          productId: 'menu-kopi',
          quantity: 2,
          unitPrice: 12000,
        ),
      ],
      subtotal: 24000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 24000,
    );

    // Repairs a reservation missed if the app stopped between order and table writes.
    await orders.synchronizeTableOccupancy();
    expect(tables.forOutlet(outletId).single.occupied, isTrue);

    // Active dine-in orders own the table lifecycle; manual release is blocked.
    expect(tables.setOccupied(outletId, table.id, false), isFalse);
    expect(tables.rename(outletId, table.id, 'Meja Baru'), isFalse);
    expect(tables.remove(outletId, table.id), isFalse);

    expect(orders.findOrder(outletId, order.id)?.tableId, 'Meja 01');

    // Completing the paid order releases the reservation for the next guest.
    expect(orders.markPaid(outletId, order.id), isTrue);
    expect(orders.advance(outletId, order.id), isTrue); // Preparing
    expect(orders.advance(outletId, order.id), isTrue); // Ready
    expect(orders.advance(outletId, order.id), isTrue); // Served
    expect(orders.advance(outletId, order.id), isTrue); // Completed
    await orders.waitForPendingSave();
    await tables.waitForPendingSave();
    expect(tables.forOutlet(outletId).single.occupied, isFalse);
    expect(tables.setOccupied(outletId, table.id, true), isTrue);

    await orders.waitForPendingSave();
    await tables.waitForPendingSave();
  });
}
