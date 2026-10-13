import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/inventory_store.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';
import 'package:firefa_main_app/features/modules/table_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('table stays occupied until its last active dine-in order is closed', () async {
    SharedPreferences.setMockInitialValues({});
    final tables = FirefaTableStore.instance;
    final orders = FirefaOrderStore.instance;
    await tables.initialize();
    await FirefaInventoryStore.instance.initialize();
    await orders.initialize();

    expect(tables.add('TABLE-LIFECYCLE', 'A1'), isTrue);
    final table = tables.forOutlet('TABLE-LIFECYCLE').single;
    expect(tables.setOccupied('TABLE-LIFECYCLE', table.id, true), isTrue);

    FirefaOrder createDineInOrder() => orders.createOrder(
      outletId: 'TABLE-LIFECYCLE',
      orderType: 'Dine In',
      tableId: 'A1',
      items: const [
        FirefaOrderItem(productName: 'Kopi', quantity: 1, unitPrice: 10000),
      ],
      subtotal: 10000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 10000,
    );

    final first = createDineInOrder();
    final second = createDineInOrder();

    expect(await orders.cancelAndRestoreStock('TABLE-LIFECYCLE', first.id), isTrue);
    expect(tables.forOutlet('TABLE-LIFECYCLE').single.occupied, isTrue);

    expect(await orders.cancelAndRestoreStock('TABLE-LIFECYCLE', second.id), isTrue);
    expect(tables.forOutlet('TABLE-LIFECYCLE').single.occupied, isFalse);

    await orders.waitForPendingSave();
    await tables.waitForPendingSave();
  });
}
