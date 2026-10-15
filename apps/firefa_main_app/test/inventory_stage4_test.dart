import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/inventory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('converts compatible mass and volume units and rejects unrelated units', () {
    expect(FirefaInventoryStore.convertQuantity(quantity: 1.5, fromUnit: 'kg', toUnit: 'gram'), 1500);
    expect(FirefaInventoryStore.convertQuantity(quantity: 2, fromUnit: 'liter', toUnit: 'ml'), 2000);
    expect(() => FirefaInventoryStore.convertQuantity(quantity: 1, fromUnit: 'box', toUnit: 'pcs'), throwsArgumentError);
    expect(() => FirefaInventoryStore.convertQuantity(quantity: -1, fromUnit: 'kg', toUnit: 'gram'), throwsArgumentError);
  });

  test('stock movement accepts converted input and records converted quantity', () async {
    final store = FirefaInventoryStore.forTesting();
    await store.initialize();
    expect(store.add(outletId: 'A', name: 'Tepung', unit: 'gram', stock: 0, minimumStock: 100, unitCost: 2), isTrue);
    final item = store.forOutlet('A').single;
    expect(store.adjustConverted(outletId: 'A', id: item.id, type: 'in', amount: 1.5, inputUnit: 'kg', note: 'Pembelian'), isTrue);
    expect(store.forOutlet('A').single.stock, 1500);
    expect(store.historyForOutlet('A').first.note, contains('1500 gram'));
    expect(store.forOutlet('A').single.unitCost, 2);
    await store.waitForPendingSave();
  });

  test('prepared ingredient production consumes raw materials and calculates unit HPP', () async {
    final store = FirefaInventoryStore.forTesting();
    await store.initialize();
    expect(store.add(outletId: 'A', name: 'Tepung', unit: 'gram', stock: 1000, minimumStock: 100, unitCost: 2), isTrue);
    expect(store.add(outletId: 'A', name: 'Adonan', unit: 'gram', stock: 0, minimumStock: 50), isTrue);
    final flour = store.forOutlet('A').firstWhere((item) => item.name == 'Tepung');
    final dough = store.forOutlet('A').firstWhere((item) => item.name == 'Adonan');
    expect(store.setPreparedIngredient(outletId: 'A', id: dough.id, prepared: true), isTrue);
    expect(store.addPreparedRecipeLine(outletId: 'A', preparedItemId: dough.id, ingredientId: flour.id, quantity: 200, outputQuantity: 150), isTrue);

    expect(await store.producePreparedIngredient(outletId: 'A', preparedItemId: dough.id, batches: 2), isTrue);
    expect(store.forOutlet('A').firstWhere((item) => item.id == flour.id).stock, 600);
    final produced = store.forOutlet('A').firstWhere((item) => item.id == dough.id);
    expect(produced.stock, 300);
    expect(produced.unitCost, closeTo(800 / 300, 0.00001));
    expect(store.historyForOutlet('A').where((movement) => movement.note.contains('Produksi')).length, 1);

    expect(store.addRecipeLine(outletId: 'A', menuId: 'menu-latte', ingredientId: dough.id, quantity: 10), isTrue);
    expect(store.hppForMenu(outletId: 'A', menuId: 'menu-latte'), closeTo(10 * 800 / 300, 0.00001));
    await store.waitForPendingSave();

    final restored = FirefaInventoryStore.forTesting();
    await restored.initialize();
    expect(restored.forOutlet('A').firstWhere((item) => item.id == dough.id).unitCost, closeTo(800 / 300, 0.00001));
    expect(restored.preparedRecipesForOutlet('A'), hasLength(1));
  });

  test('automatic POS stock deduction remains idempotent and HPP uses recipe cost', () async {
    final store = FirefaInventoryStore.forTesting();
    await store.initialize();
    expect(store.add(outletId: 'A', name: 'Biji Kopi', unit: 'gram', stock: 1000, minimumStock: 100, unitCost: 1.5), isTrue);
    final coffee = store.forOutlet('A').single;
    expect(store.addRecipeLine(outletId: 'A', menuId: 'coffee-menu', ingredientId: coffee.id, quantity: 20), isTrue);
    expect(store.hppForMenu(outletId: 'A', menuId: 'coffee-menu'), 30);
    expect(await store.consumeOrderStock(orderId: 'ORDER-1', outletId: 'A', menuLines: [(menuId: 'coffee-menu', quantity: 3)]), isTrue);
    expect(store.forOutlet('A').single.stock, 940);
    expect(await store.consumeOrderStock(orderId: 'ORDER-1', outletId: 'A', menuLines: [(menuId: 'coffee-menu', quantity: 3)]), isFalse);
    expect(store.forOutlet('A').single.stock, 940);
    await store.waitForPendingSave();
  });
}
