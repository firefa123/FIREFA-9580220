import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/inventory/inventory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('validates item IDs and catalog fields', () async {
    final store = InventoryStore(); await store.initialize();
    await store.addItem(const InventoryCatalogItem(id: 'beans', name: 'Beans', unit: 'kg', minimumStock: 2));
    await expectLater(store.addItem(const InventoryCatalogItem(id: 'beans', name: 'Duplicate', unit: 'kg')), throwsStateError);
    await expectLater(store.addItem(const InventoryCatalogItem(id: 'bad', name: '', unit: 'kg')), throwsArgumentError);
    expect(store.items, hasLength(1));
  });

  test('stock-in and stock-out persist outlet-scoped quantities and ledger', () async {
    final store = InventoryStore(); await store.initialize();
    await store.addItem(const InventoryCatalogItem(id: 'milk', name: 'Milk', unit: 'L', minimumStock: 1));
    await store.receiveStock(outletId: 'A', itemId: 'milk', quantity: 5);
    await store.issueStock(outletId: 'A', itemId: 'milk', quantity: 2);
    expect(store.stockFor('A', 'milk'), 3);
    expect(store.stockFor('B', 'milk'), 0);
    expect(store.movementsForOutlet('A').map((m) => m.type), ['stock_in', 'stock_out']);
    final restored = InventoryStore(); await restored.initialize();
    expect(restored.stockFor('A', 'milk'), 3);
    expect(restored.movementsForOutlet('A'), hasLength(2));
  });

  test('rejects negative stock and insufficient issue without mutation', () async {
    final store = InventoryStore(); await store.initialize();
    await store.addItem(const InventoryCatalogItem(id: 'rice', name: 'Rice', unit: 'kg'));
    await expectLater(store.receiveStock(outletId: 'A', itemId: 'rice', quantity: -1), throwsArgumentError);
    await expectLater(store.issueStock(outletId: 'A', itemId: 'rice', quantity: 1), throwsStateError);
    expect(store.stockFor('A', 'rice'), 0);
  });

  test('transfer moves stock and writes paired movements', () async {
    final store = InventoryStore(); await store.initialize();
    await store.addItem(const InventoryCatalogItem(id: 'syrup', name: 'Syrup', unit: 'bottle'));
    await store.receiveStock(outletId: 'A', itemId: 'syrup', quantity: 8);
    await store.transferStock(fromOutletId: 'A', toOutletId: 'B', itemId: 'syrup', quantity: 3);
    expect(store.stockFor('A', 'syrup'), 5);
    expect(store.stockFor('B', 'syrup'), 3);
    expect(store.movementsForOutlet('A').where((m) => m.type == 'transfer_out'), hasLength(1));
    expect(store.movementsForOutlet('B').where((m) => m.type == 'transfer_in'), hasLength(1));
  });

  test('low-stock list uses threshold and outlet-specific stock', () async {
    final store = InventoryStore(); await store.initialize();
    await store.addItem(const InventoryCatalogItem(id: 'cups', name: 'Cups', unit: 'pcs', minimumStock: 5));
    await store.receiveStock(outletId: 'A', itemId: 'cups', quantity: 4);
    await store.receiveStock(outletId: 'B', itemId: 'cups', quantity: 10);
    expect(store.lowStockItems('A').map((i) => i.id), ['cups']);
    expect(store.lowStockItems('B'), isEmpty);
  });
}
