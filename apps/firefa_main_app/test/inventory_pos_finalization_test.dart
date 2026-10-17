import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/inventory_store.dart';
import 'package:firefa_main_app/features/modules/inventory_hybrid_sync.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FirefaInventoryStore inventory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    inventory = FirefaInventoryStore.forTesting();
    await inventory.initialize();
  });

  test('POS consumption is outlet-scoped, durable, and idempotent', () async {
    expect(inventory.add(
      outletId: 'outlet-a', name: 'Coffee beans', unit: 'gram',
      stock: 100, minimumStock: 5,
    ), isTrue);
    final item = inventory.forOutlet('outlet-a').single;
    expect(inventory.addRecipeLine(
      outletId: 'outlet-a', menuId: 'coffee', ingredientId: item.id,
      quantity: 12,
    ), isTrue);
    await inventory.waitForPendingSave();

    expect(await inventory.consumeOrderStock(
      orderId: 'ORD-1001', outletId: 'outlet-a',
      menuLines: [(menuId: 'coffee', quantity: 2)],
    ), isTrue);
    expect(inventory.forOutlet('outlet-a').single.stock, 76);
    expect(await inventory.consumeOrderStock(
      orderId: 'ORD-1001', outletId: 'outlet-a',
      menuLines: [(menuId: 'coffee', quantity: 2)],
    ), isFalse);
    expect(inventory.forOutlet('outlet-a').single.stock, 76);
    expect(inventory.historyForOutlet('outlet-a')
        .where((movement) => movement.note == 'POS order ORD-1001').length, 1);

    final reopened = FirefaInventoryStore.forTesting();
    await reopened.initialize();
    expect(reopened.forOutlet('outlet-a').single.stock, 76);
    expect(await reopened.consumeOrderStock(
      orderId: 'ORD-1001', outletId: 'outlet-a',
      menuLines: [(menuId: 'coffee', quantity: 2)],
    ), isFalse);
    expect(reopened.forOutlet('outlet-a').single.stock, 76);
  });

  test('startup recovers stock deduction after an interrupted checkout', () async {
    inventory.add(
      outletId: 'outlet-recovery', name: 'Recovery flour', unit: 'gram',
      stock: 100, minimumStock: 1,
    );
    final ingredient = inventory.forOutlet('outlet-recovery').single;
    inventory.addRecipeLine(
      outletId: 'outlet-recovery', menuId: 'recovery-bread',
      ingredientId: ingredient.id, quantity: 20,
    );
    await inventory.waitForPendingSave();

    const orderId = 'ORD-RECOVERY-1';
    expect(await inventory.prepareOrderStockConsumption(
      orderId: orderId, outletId: 'outlet-recovery',
      menuLines: [(menuId: 'recovery-bread', quantity: 2)],
    ), isTrue);
    // A recipe edit after the intent was journaled must not change the
    // quantities that recovery applies for this already-created checkout.
    expect(inventory.removeRecipeLine(
      outletId: 'outlet-recovery', menuId: 'recovery-bread',
      ingredientId: ingredient.id,
    ), isTrue);
    expect(inventory.addRecipeLine(
      outletId: 'outlet-recovery', menuId: 'recovery-bread',
      ingredientId: ingredient.id, quantity: 30,
    ), isTrue);
    await inventory.waitForPendingSave();

    final order = FirefaOrder(
      id: orderId,
      outletId: 'outlet-recovery',
      orderType: 'Take Away',
      tableId: null,
      createdAt: DateTime.utc(2026, 10, 17),
      items: const [FirefaOrderItem(
        productName: 'Recovery bread', productId: 'recovery-bread',
        quantity: 2, unitPrice: 1000,
      )],
      subtotal: 2000, discount: 0, tax: 0, service: 0, total: 2000,
    );

    // Simulate a new process after the order snapshot is durable but before
    // consumeOrderStock is called.
    final reopened = FirefaInventoryStore.forTesting();
    await reopened.initialize();
    expect(reopened.forOutlet('outlet-recovery').single.stock, 100);
    expect(await reopened.recoverPendingOrderStock([order]), 1);
    expect(reopened.forOutlet('outlet-recovery').single.stock, 60);
    expect(await reopened.recoverPendingOrderStock([order]), 0);
    expect(reopened.forOutlet('outlet-recovery').single.stock, 60);
    expect(reopened.isOrderStockProcessed(orderId, outletId: 'outlet-recovery'), isTrue);
    await reopened.waitForPendingSave();
  });

  test('cancellation restores exactly the original POS deduction once', () async {
    inventory.add(
      outletId: 'outlet-a', name: 'Milk', unit: 'ml',
      stock: 1000, minimumStock: 100,
    );
    final item = inventory.forOutlet('outlet-a').single;
    inventory.addRecipeLine(
      outletId: 'outlet-a', menuId: 'latte', ingredientId: item.id,
      quantity: 150,
    );
    await inventory.waitForPendingSave();

    expect(await inventory.consumeOrderStock(
      orderId: 'ORD-1002', outletId: 'outlet-a',
      menuLines: [(menuId: 'latte', quantity: 2)],
    ), isTrue);
    expect(inventory.forOutlet('outlet-a').single.stock, 700);
    expect(await inventory.restoreCancelledOrderStock(
      orderId: 'ORD-1002', outletId: 'outlet-a',
    ), isTrue);
    expect(inventory.forOutlet('outlet-a').single.stock, 1000);
    expect(await inventory.restoreCancelledOrderStock(
      orderId: 'ORD-1002', outletId: 'outlet-a',
    ), isFalse);
    expect(inventory.forOutlet('outlet-a').single.stock, 1000);
    expect(inventory.historyForOutlet('outlet-a')
        .where((movement) => movement.note == 'Pembatalan POS order ORD-1002').length, 1);
  });

  test('stock transfer debits source and credits destination once', () async {
    inventory.add(
      outletId: 'outlet-a', name: 'Paper cup', unit: 'pcs',
      stock: 30, minimumStock: 2,
    );
    inventory.add(
      outletId: 'outlet-b', name: 'Paper cup', unit: 'pcs',
      stock: 4, minimumStock: 2,
    );
    await inventory.waitForPendingSave();
    final source = inventory.forOutlet('outlet-a').single;
    final target = inventory.forOutlet('outlet-b').single;

    expect(await inventory.transferStock(
      transferId: 'TRF-1', sourceOutletId: 'outlet-a',
      sourceItemId: source.id, targetOutletId: 'outlet-b',
      targetItemId: target.id, quantity: 7,
    ), isTrue);
    expect(inventory.forOutlet('outlet-a').single.stock, 23);
    expect(inventory.forOutlet('outlet-b').single.stock, 11);
    expect(await inventory.transferStock(
      transferId: 'TRF-1', sourceOutletId: 'outlet-a',
      sourceItemId: source.id, targetOutletId: 'outlet-b',
      targetItemId: target.id, quantity: 7,
    ), isFalse);
    expect(await inventory.transferStock(
      transferId: 'TRF-1 ', sourceOutletId: 'outlet-a',
      sourceItemId: source.id, targetOutletId: 'outlet-b',
      targetItemId: target.id, quantity: 7,
    ), isFalse);
    expect(inventory.forOutlet('outlet-a').single.stock, 23);
    expect(inventory.forOutlet('outlet-b').single.stock, 11);

    final reopened = FirefaInventoryStore.forTesting();
    await reopened.initialize();
    expect(await reopened.transferStock(
      transferId: 'TRF-1', sourceOutletId: 'outlet-a',
      sourceItemId: source.id, targetOutletId: 'outlet-b',
      targetItemId: target.id, quantity: 7,
    ), isFalse);
    expect(reopened.forOutlet('outlet-a').single.stock, 23);
    expect(reopened.forOutlet('outlet-b').single.stock, 11);

    final backup = reopened.exportLocalSnapshot();
    final restored = FirefaInventoryStore.forTesting();
    await restored.initialize();
    await restored.restoreLocalSnapshot(backup);
    expect(await restored.transferStock(
      transferId: 'TRF-1', sourceOutletId: 'outlet-a',
      sourceItemId: source.id, targetOutletId: 'outlet-b',
      targetItemId: target.id, quantity: 7,
    ), isFalse);
    expect(restored.forOutlet('outlet-a').single.stock, 23);
    expect(restored.forOutlet('outlet-b').single.stock, 11);
  });

  test('stock opname correction and approval are applied only once', () async {
    inventory.add(
      outletId: 'outlet-a', name: 'Sugar', unit: 'gram',
      stock: 50, minimumStock: 1,
    );
    await inventory.waitForPendingSave();
    final item = inventory.forOutlet('outlet-a').single;
    expect(inventory.createOpname(
      outletId: 'outlet-a', itemId: item.id,
      physicalStock: 42, note: 'Hitung fisik',
    ), isTrue);
    await inventory.waitForPendingSave();
    final opname = inventory.opnamesForOutlet('outlet-a').single;

    expect(await inventory.resolveOpname(
      outletId: 'outlet-a', opnameId: opname.id, approve: true,
    ), isTrue);
    expect(inventory.forOutlet('outlet-a').single.stock, 42);
    expect(await inventory.resolveOpname(
      outletId: 'outlet-a', opnameId: opname.id, approve: true,
    ), isFalse);
    expect(inventory.forOutlet('outlet-a').single.stock, 42);
    expect(inventory.historyForOutlet('outlet-a')
        .where((movement) => movement.note.startsWith('Stock opname ${opname.id}:')).length, 1);
  });

  test('reconciliation flags missing and mismatched inventory without overwriting', () {
    const reconciliation = FirefaInventoryReconciliation();
    final result = reconciliation.reconcile(
      localStockByItem: {'a': 10, 'b': 4},
      serverStockByItem: {'a': 10, 'c': 2},
    );
    expect(result.matched, 1);
    expect(result.conflictingItemIds, ['b', 'c']);
    expect(result.isReconciled, isFalse);
    expect(reconciliation.evaluate(localStock: 10, serverStock: 9),
        FirefaInventorySyncStatus.conflict);
  });
}
