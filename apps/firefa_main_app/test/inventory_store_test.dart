import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/inventory/inventory_store.dart';
import 'package:firefa_main_app/features/inventory/order_inventory_service.dart';
import 'package:firefa_main_app/features/inventory/recipe_ingredient_model.dart';
import 'package:firefa_main_app/features/modules/inventory_store.dart' as legacy;

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
  test('order consumption validates all ingredients and is idempotent', () async {
    final store = InventoryStore();
    await store.initialize();
    await store.addItem(const InventoryCatalogItem(id: 'coffee', name: 'Coffee', unit: 'g'));
    await store.addItem(const InventoryCatalogItem(id: 'milk', name: 'Milk', unit: 'ml'));
    await store.receiveStock(outletId: 'A', itemId: 'coffee', quantity: 100);
    await store.receiveStock(outletId: 'A', itemId: 'milk', quantity: 200);

    await expectLater(
      store.consumeOrderIngredients(
        orderId: 'ORDER-1', outletId: 'A',
        ingredientQuantities: {'coffee': 10, 'milk': 300},
      ),
      throwsStateError,
    );
    expect(store.stockFor('A', 'coffee'), 100);
    expect(store.stockFor('A', 'milk'), 200);

    expect(await store.consumeOrderIngredients(
      orderId: 'ORDER-1', outletId: 'A',
      ingredientQuantities: {'coffee': 10, 'milk': 50},
    ), isTrue);
    expect(await store.consumeOrderIngredients(
      orderId: 'ORDER-1', outletId: 'A',
      ingredientQuantities: {'coffee': 10, 'milk': 50},
    ), isFalse);
    expect(store.stockFor('A', 'coffee'), 90);
    expect(store.stockFor('A', 'milk'), 150);
    expect(store.movementsForOutlet('A').where((m) => m.referenceOrderId == 'ORDER-1'), hasLength(2));

    final restored = InventoryStore();
    await restored.initialize();
    expect(restored.isOrderProcessed('ORDER-1'), isTrue);
    expect(await restored.consumeOrderIngredients(
      orderId: 'ORDER-1', outletId: 'A',
      ingredientQuantities: {'coffee': 10, 'milk': 50},
    ), isFalse);
    expect(restored.stockFor('A', 'coffee'), 90);
  });

  test('order service calculates recipe consumption and rejects missing recipe', () async {
    final store = InventoryStore();
    await store.initialize();
    await store.addItem(const InventoryCatalogItem(id: 'coffee', name: 'Coffee', unit: 'g'));
    await store.addItem(const InventoryCatalogItem(id: 'milk', name: 'Milk', unit: 'ml'));
    await store.receiveStock(outletId: 'A', itemId: 'coffee', quantity: 100);
    await store.receiveStock(outletId: 'A', itemId: 'milk', quantity: 500);
    final service = OrderInventoryService(inventory: store);
    final recipes = [
      const RecipeIngredient(menuId: 'latte', ingredientId: 'coffee', quantity: 18),
      const RecipeIngredient(menuId: 'latte', ingredientId: 'milk', quantity: 200),
    ];
    await expectLater(
      service.consumeOrder(orderId: 'ORDER-X', outletId: 'A',
        menuLines: [const OrderMenuQuantity(menuId: 'unknown', quantity: 1)], recipes: recipes),
      throwsStateError,
    );
    expect(store.stockFor('A', 'coffee'), 100);
    expect(await service.consumeOrder(orderId: 'ORDER-2', outletId: 'A',
      menuLines: [const OrderMenuQuantity(menuId: 'latte', quantity: 2)], recipes: recipes), isTrue);
    expect(store.stockFor('A', 'coffee'), 64);
    expect(store.stockFor('A', 'milk'), 100);
  });


  test('domain inventory uses a separate storage key from the legacy UI store', () {
    expect(InventoryStore().storageKey, 'firefa_inventory_domain_v1');
    expect(InventoryStore().storageKey, isNot('firefa_inventory_v1'));
  });


  test('legacy inventory recipes validate and deduct POS stock once per order', () async {
    final store = legacy.FirefaInventoryStore.instance;
    await store.initialize();
    expect(store.add(outletId: 'LEGACY-A', name: 'Coffee', unit: 'gram', stock: 100, minimumStock: 5), isTrue);
    expect(store.add(outletId: 'LEGACY-A', name: 'Milk', unit: 'ml', stock: 300, minimumStock: 20), isTrue);
    final coffee = store.forOutlet('LEGACY-A').singleWhere((item) => item.name == 'Coffee');
    final milk = store.forOutlet('LEGACY-A').singleWhere((item) => item.name == 'Milk');
    expect(store.addRecipeLine(outletId: 'LEGACY-A', menuId: 'menu-latte', ingredientId: coffee.id, quantity: 18), isTrue);
    expect(store.addRecipeLine(outletId: 'LEGACY-A', menuId: 'menu-latte', ingredientId: milk.id, quantity: 200), isTrue);
    expect(() => store.validateOrderStock(outletId: 'LEGACY-A', menuLines: [(menuId: 'menu-latte', quantity: 2)]), throwsStateError);
    expect(store.forOutlet('LEGACY-A').singleWhere((item) => item.id == coffee.id).stock, 100);
    expect(store.addRecipeLine(outletId: 'LEGACY-A', menuId: 'menu-latte', ingredientId: milk.id, quantity: 100), isTrue);
    expect(store.validateOrderStock(outletId: 'LEGACY-A', menuLines: [(menuId: 'menu-latte', quantity: 2)]), isTrue);
    expect(
      () => store.validateOrderStock(outletId: 'LEGACY-A', menuLines: const []),
      throwsStateError,
    );
    expect(
      () => store.validateOrderStock(
        outletId: 'LEGACY-A',
        menuLines: [(menuId: '  ', quantity: 1)],
      ),
      throwsStateError,
    );
    // Large quantities must fail validation rather than overflow arithmetic.
    expect(
      () => store.validateOrderStock(
        outletId: 'LEGACY-A',
        menuLines: [(menuId: 'menu-latte', quantity: 999999999)],
      ),
      throwsStateError,
    );
    // Individually valid lines must also be rejected if their combined
    // requirement for the same ingredient exceeds the supported limit.
    expect(
      () => store.validateOrderStock(
        outletId: 'LEGACY-A',
        menuLines: [
          (menuId: 'menu-latte', quantity: 5000000),
          (menuId: 'menu-latte', quantity: 5000000),
        ],
      ),
      throwsStateError,
    );
    expect(store.forOutlet('LEGACY-A').singleWhere((item) => item.id == coffee.id).stock, 100);
    expect(store.forOutlet('LEGACY-A').singleWhere((item) => item.id == milk.id).stock, 300);
    expect(await store.consumeOrderStock(orderId: 'POS-ORDER-1', outletId: 'LEGACY-A', menuLines: [(menuId: 'menu-latte', quantity: 2)]), isTrue);
    expect(await store.consumeOrderStock(orderId: 'POS-ORDER-1', outletId: 'LEGACY-A', menuLines: [(menuId: 'menu-latte', quantity: 2)]), isFalse);
    expect(store.forOutlet('LEGACY-A').singleWhere((item) => item.id == coffee.id).stock, 64);
    expect(store.forOutlet('LEGACY-A').singleWhere((item) => item.id == milk.id).stock, 100);
    // A wrong outlet must not restore stock or mark this order as reversed.
    await expectLater(
      store.restoreCancelledOrderStock(orderId: 'POS-ORDER-1', outletId: 'LEGACY-B'),
      throwsStateError,
    );
    expect(store.forOutlet('LEGACY-A').singleWhere((item) => item.id == coffee.id).stock, 64);
    expect(store.isOrderStockReversed('POS-ORDER-1'), isFalse);
    expect(await store.restoreCancelledOrderStock(orderId: 'POS-ORDER-1', outletId: 'LEGACY-A'), isTrue);
    expect(store.forOutlet('LEGACY-A').singleWhere((item) => item.id == coffee.id).stock, 100);
    expect(store.forOutlet('LEGACY-A').singleWhere((item) => item.id == milk.id).stock, 300);
    expect(await store.restoreCancelledOrderStock(orderId: 'POS-ORDER-1', outletId: 'LEGACY-A'), isFalse);
    expect(store.forOutlet('LEGACY-A').singleWhere((item) => item.id == coffee.id).stock, 100);
    expect(store.isOrderStockReversed('POS-ORDER-1'), isTrue);
    await store.waitForPendingSave();
  });

}
