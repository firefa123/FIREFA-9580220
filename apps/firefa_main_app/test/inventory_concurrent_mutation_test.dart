import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/inventory/inventory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('concurrent stock mutations remain consistent after one write fails', () async {
    var holdNextWrite = false;
    Completer<void>? writeStarted;
    Completer<void>? releaseWrite;

    final store = InventoryStore(
      persistString: (_, __) async {
        if (holdNextWrite) {
          holdNextWrite = false;
          writeStarted!.complete();
          await releaseWrite!.future;
          return false;
        }
        return true;
      },
    );
    await store.initialize();
    await store.addItem(
      const InventoryCatalogItem(id: 'rice-concurrent', name: 'Rice', unit: 'kg'),
    );
    await store.receiveStock(
      outletId: 'A',
      itemId: 'rice-concurrent',
      quantity: 10,
    );

    holdNextWrite = true;
    writeStarted = Completer<void>();
    releaseWrite = Completer<void>();

    final failedMutation = store.receiveStock(
      outletId: 'A',
      itemId: 'rice-concurrent',
      quantity: 1,
    );
    await writeStarted!.future;

    final succeedingMutation = store.receiveStock(
      outletId: 'A',
      itemId: 'rice-concurrent',
      quantity: 2,
    );
    releaseWrite!.complete();

    await expectLater(failedMutation, throwsStateError);
    await succeedingMutation;

    expect(store.stockFor('A', 'rice-concurrent'), 12);
    expect(
      store.movementsForOutlet('A').map((movement) => movement.id),
      ['INV-1', 'INV-2'],
    );
  });
}
