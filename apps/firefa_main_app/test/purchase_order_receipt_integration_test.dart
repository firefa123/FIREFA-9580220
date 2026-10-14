import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/inventory_store.dart';
import 'package:firefa_main_app/features/modules/purchase_order_store.dart';
import 'package:firefa_main_app/features/modules/supplier_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PO receipt updates inventory once and preserves PO supplier traceability', () async {
    SharedPreferences.setMockInitialValues({});
    final inventory = FirefaInventoryStore.instance;
    final suppliers = FirefaSupplierStore.instance;
    final orders = FirefaPurchaseOrderStore.instance;
    await inventory.initialize();
    await suppliers.initialize();
    await orders.initialize();

    const outlet = 'PO-RECEIPT-INTEGRATION';
    expect(inventory.add(
      outletId: outlet, name: 'Receipt test beans', unit: 'kg',
      stock: 5, minimumStock: 1,
    ), isTrue);
    final item = inventory.forOutlet(outlet).single;
    expect(suppliers.add(
      outletId: outlet, name: 'Receipt test supplier',
      contact: '', phone: '', address: '',
    ), isTrue);
    final supplier = suppliers.forOutlet(outlet).single;
    expect(orders.create(
      outletId: outlet, supplierId: supplier.id,
      itemId: item.id, quantity: 10, unitCost: 12000, note: 'integration',
    ), isTrue);
    final order = orders.forOutlet(outlet).single;

    final outcomes = await Future.wait([
      orders.receive(outletId: outlet, orderId: order.id, quantity: 4),
      orders.receive(outletId: outlet, orderId: order.id, quantity: 4),
    ]);
    expect(outcomes.where((success) => success), hasLength(1));
    await inventory.waitForPendingSave();
    await orders.waitForPendingSave();

    final received = orders.forOutlet(outlet).single;
    expect(received.supplierName, 'Receipt test supplier');
    expect(received.receivedQuantity, 4);
    expect(received.remainingQuantity, 6);
    expect(received.status, 'partial');
    expect(received.receipts, hasLength(1));
    expect(inventory.forOutlet(outlet).single.stock, 9);

    final movement = inventory.historyForOutlet(outlet).first;
    expect(movement.type, 'in');
    expect(movement.change, 4);
    expect(movement.note, contains(order.id));
    expect(movement.note, contains('Receipt test supplier'));

    expect(await orders.receive(
      outletId: outlet, orderId: order.id, quantity: 6,
    ), isTrue);
    expect(await orders.receive(
      outletId: outlet, orderId: order.id, quantity: 1,
    ), isFalse);
    await inventory.waitForPendingSave();
    await orders.waitForPendingSave();
    expect(orders.forOutlet(outlet).single.status, 'received');
    expect(orders.forOutlet(outlet).single.receivedQuantity, 10);
    expect(inventory.forOutlet(outlet).single.stock, 15);
    expect(inventory.historyForOutlet(outlet), hasLength(2));
  });
}
