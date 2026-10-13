import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/inventory/inventory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('inventory mutations roll back completely when persistence fails', () async {
    var failWrites = false;
    final store = InventoryStore(
      persistString: (_, __) async => !failWrites,
    );
    await store.initialize();
    await store.addItem(
      const InventoryCatalogItem(id: 'milk', name: 'Milk', unit: 'L'),
    );
    await store.receiveStock(outletId: 'A', itemId: 'milk', quantity: 10);
    await store.receiveStock(outletId: 'B', itemId: 'milk', quantity: 4);

    failWrites = true;

    await expectLater(
      store.receiveStock(outletId: 'A', itemId: 'milk', quantity: 2),
      throwsStateError,
    );
    expect(store.stockFor('A', 'milk'), 10);
    expect(store.movementsForOutlet('A'), hasLength(1));

    await expectLater(
      store.issueStock(outletId: 'A', itemId: 'milk', quantity: 2),
      throwsStateError,
    );
    expect(store.stockFor('A', 'milk'), 10);
    expect(store.movementsForOutlet('A'), hasLength(1));

    await expectLater(
      store.transferStock(
        fromOutletId: 'A',
        toOutletId: 'B',
        itemId: 'milk',
        quantity: 3,
      ),
      throwsStateError,
    );
    expect(store.stockFor('A', 'milk'), 10);
    expect(store.stockFor('B', 'milk'), 4);
    expect(store.movementsForOutlet('A'), hasLength(1));
    expect(store.movementsForOutlet('B'), hasLength(1));

    await expectLater(
      store.consumeOrderIngredients(
        orderId: 'ORDER-ROLLBACK',
        outletId: 'A',
        ingredientQuantities: {'milk': 2},
      ),
      throwsStateError,
    );
    expect(store.stockFor('A', 'milk'), 10);
    expect(store.isOrderProcessed('ORDER-ROLLBACK', outletId: 'A'), isFalse);
    expect(
      store.movementsForOutlet('A').where(
        (movement) => movement.referenceOrderId == 'ORDER-ROLLBACK',
      ),
      isEmpty,
    );

    await expectLater(
      store.addItem(
        const InventoryCatalogItem(id: 'beans', name: 'Beans', unit: 'kg'),
      ),
      throwsStateError,
    );
    expect(store.items.map((item) => item.id), ['milk']);

    failWrites = false;
    await store.receiveStock(outletId: 'A', itemId: 'milk', quantity: 1);
    expect(store.stockFor('A', 'milk'), 11);
    expect(store.movementsForOutlet('A').last.id, 'INV-3');
  });
}
