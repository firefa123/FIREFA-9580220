import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/inventory_store.dart';
import 'package:firefa_main_app/features/modules/purchase_order_store.dart';
import 'package:firefa_main_app/features/modules/supplier_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('purchase order lifecycle receives partial quantities and cancels only remainder', () async {
    SharedPreferences.setMockInitialValues({});

    final inventory = FirefaInventoryStore.instance;
    final suppliers = FirefaSupplierStore.instance;
    final orders = FirefaPurchaseOrderStore.instance;

    await Future.wait([
      inventory.initialize(),
      suppliers.initialize(),
      orders.initialize(),
    ]);

    const outletId = 'po-lifecycle-outlet';
    expect(inventory.add(
      outletId: outletId,
      name: 'Coffee Beans',
      unit: 'gram',
      stock: 10,
      minimumStock: 2,
    ), isTrue);
    expect(suppliers.add(
      outletId: outletId,
      name: 'Supplier Kopi',
      contact: 'Admin',
      phone: '081234567890',
      address: 'Bandung',
    ), isTrue);

    expect(orders.create(
      outletId: outletId,
      supplierId: 'supplier-1',
      itemId: 'inventory-1',
      quantity: 8,
      unitCost: 2000,
      note: 'First delivery',
    ), isTrue);

    var po = orders.forOutlet(outletId).single;
    expect(po.status, 'ordered');
    expect(po.remainingQuantity, 8);
    expect(po.totalCost, 16000);

    expect(await orders.receiveDurably(
      outletId: outletId,
      orderId: po.id,
      quantity: 3,
    ), isTrue);
    po = orders.forOutlet(outletId).single;
    expect(po.status, 'partial');
    expect(po.receivedQuantity, 3);
    expect(po.remainingQuantity, 5);
    expect(po.receipts, hasLength(1));
    expect(inventory.forOutlet(outletId).single.stock, 13);

    expect(await orders.receiveDurably(
      outletId: outletId,
      orderId: po.id,
      quantity: 6,
    ), isFalse);
    expect(inventory.forOutlet(outletId).single.stock, 13);
    expect(orders.forOutlet(outletId).single.receivedQuantity, 3);

    expect(await orders.receiveDurably(
      outletId: outletId,
      orderId: po.id,
      quantity: 5,
    ), isTrue);
    po = orders.forOutlet(outletId).single;
    expect(po.status, 'received');
    expect(po.receivedQuantity, 8);
    expect(po.remainingQuantity, 0);
    expect(po.receipts, hasLength(2));
    expect(inventory.forOutlet(outletId).single.stock, 18);
    expect(orders.cancel(outletId: outletId, orderId: po.id), isFalse);

    expect(orders.create(
      outletId: outletId,
      supplierId: 'supplier-1',
      itemId: 'inventory-1',
      quantity: 2,
      unitCost: 2500,
      note: 'Second delivery',
    ), isTrue);
    final second = orders.forOutlet(outletId).first;
    final concurrentReceipts = await Future.wait([
      orders.receiveDurably(
        outletId: outletId,
        orderId: second.id,
        quantity: 1,
      ),
      orders.receiveDurably(
        outletId: outletId,
        orderId: second.id,
        quantity: 1,
      ),
    ]);
    expect(concurrentReceipts.where((success) => success), hasLength(1));
    expect(orders.forOutlet(outletId).first.receivedQuantity, 1);
    expect(inventory.forOutlet(outletId).single.stock, 19);

    expect(await orders.cancelDurably(outletId: outletId, orderId: second.id), isTrue);
    final cancelled = orders.forOutlet(outletId).first;
    expect(cancelled.status, 'cancelled');
    expect(cancelled.receivedQuantity, 1);
    expect(cancelled.remainingQuantity, 1);
    expect(await orders.receiveDurably(
      outletId: outletId,
      orderId: second.id,
      quantity: 1,
    ), isFalse);
    expect(inventory.forOutlet(outletId).single.stock, 19);

    await Future.wait([
      inventory.waitForPendingSave(),
      suppliers.waitForPendingSave(),
      orders.waitForPendingSave(),
    ]);

    // Persisted records must preserve receipt history and stock changes.
    final prefs = await SharedPreferences.getInstance();
    final savedOrders = jsonDecode(
      prefs.getString(FirefaPurchaseOrderStore.storageKey)!,
    ) as Map<String, dynamic>;
    final savedRecords = (savedOrders['orders'] as List<dynamic>)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    final savedFirst = savedRecords.singleWhere((entry) => entry['id'] == po.id);
    final savedSecond = savedRecords.singleWhere((entry) => entry['id'] == second.id);
    expect(savedFirst['status'], 'received');
    expect(savedFirst['receivedQuantity'], 8);
    expect(savedFirst['receipts'], hasLength(2));
    expect(savedSecond['status'], 'cancelled');
    expect(savedSecond['quantity'] - savedSecond['receivedQuantity'], 1);

    final savedInventory = jsonDecode(
      prefs.getString(FirefaInventoryStore.storageKey)!,
    ) as Map<String, dynamic>;
    final savedItems = (savedInventory['items'] as List<dynamic>)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    expect(savedItems.singleWhere((entry) => entry['id'] == 'inventory-1')['stock'], 19);
  });
}
