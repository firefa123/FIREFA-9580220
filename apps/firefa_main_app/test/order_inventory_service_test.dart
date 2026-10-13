import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/inventory/inventory_store.dart';
import 'package:firefa_main_app/features/inventory/order_inventory_service.dart';
import 'package:firefa_main_app/features/inventory/recipe_ingredient_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('aggregates repeated menu lines and consumes recipe stock exactly once', () async {
    final inventory = InventoryStore();
    await inventory.initialize();
    await inventory.addItem(
      const InventoryCatalogItem(id: 'coffee-beans', name: 'Coffee Beans', unit: 'g'),
    );
    await inventory.receiveStock(
      outletId: 'outlet-service',
      itemId: 'coffee-beans',
      quantity: 100,
    );

    const service = OrderInventoryService(inventory: inventory);
    const recipes = [
      RecipeIngredient(menuId: 'espresso', ingredientId: 'coffee-beans', quantity: 10),
      RecipeIngredient(menuId: 'espresso', ingredientId: 'coffee-beans', quantity: 2),
    ];
    const lines = [
      OrderMenuQuantity(menuId: 'espresso', quantity: 2),
      OrderMenuQuantity(menuId: 'espresso', quantity: 1),
    ];

    expect(await service.consumeOrder(
      orderId: 'ORDER-SERVICE-1',
      outletId: 'outlet-service',
      menuLines: lines,
      recipes: recipes,
    ), isTrue);
    expect(inventory.stockFor('outlet-service', 'coffee-beans'), 64);
    expect(await service.consumeOrder(
      orderId: 'ORDER-SERVICE-1',
      outletId: 'outlet-service',
      menuLines: lines,
      recipes: recipes,
    ), isFalse);
    expect(inventory.stockFor('outlet-service', 'coffee-beans'), 64);
    expect(
      inventory.movementsForOutlet('outlet-service')
          .where((movement) => movement.referenceOrderId == 'ORDER-SERVICE-1'),
      hasLength(1),
    );
  });

  test('invalid or missing recipes reject the whole order before stock mutation', () async {
    final inventory = InventoryStore();
    await inventory.initialize();
    await inventory.addItem(
      const InventoryCatalogItem(id: 'milk-service', name: 'Milk', unit: 'ml'),
    );
    await inventory.receiveStock(
      outletId: 'outlet-service-validation',
      itemId: 'milk-service',
      quantity: 200,
    );
    const service = OrderInventoryService(inventory: inventory);

    await expectLater(
      service.consumeOrder(
        orderId: 'ORDER-MISSING-RECIPE',
        outletId: 'outlet-service-validation',
        menuLines: const [OrderMenuQuantity(menuId: 'latte', quantity: 1)],
        recipes: const [],
      ),
      throwsStateError,
    );
    await expectLater(
      service.consumeOrder(
        orderId: 'ORDER-BAD-RECIPE',
        outletId: 'outlet-service-validation',
        menuLines: const [OrderMenuQuantity(menuId: 'latte', quantity: 1)],
        recipes: const [
          RecipeIngredient(menuId: 'latte', ingredientId: 'milk-service', quantity: -5),
        ],
      ),
      throwsStateError,
    );

    expect(inventory.stockFor('outlet-service-validation', 'milk-service'), 200);
    expect(inventory.movementsForOutlet('outlet-service-validation'), hasLength(1));
  });
}
