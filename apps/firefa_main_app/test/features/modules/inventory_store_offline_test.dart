import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/inventory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirefaInventoryStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = FirefaInventoryStore.forTesting();
    await store.initialize();
  });

  tearDown(() async {
    await store.waitForPendingSave();
    store.dispose();
  });

  test('stock movement is durable and restored after an app restart', () async {
    expect(store.add(outletId: 'outlet-offline', name: 'Biji Kopi',
        unit: 'gram', stock: 1000, minimumStock: 100), isTrue);
    await store.waitForPendingSave();

    final item = store.forOutlet('outlet-offline').single;
    expect(await store.adjustConvertedAndPersist(outletId: item.outletId,
        id: item.id, type: 'out', amount: 125, inputUnit: 'gram',
        note: 'Pesanan offline'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(FirefaInventoryStore.storageKey);
    expect(raw, isNotNull);
    final saved = jsonDecode(raw!) as Map<String, dynamic>;
    expect((saved['items'] as List).single['stock'], 875);
    expect((saved['movements'] as List), hasLength(1));

    // A new store instance represents reopening the app from disk.
    final reopened = FirefaInventoryStore.forTesting();
    await reopened.initialize();
    expect(reopened.forOutlet('outlet-offline').single.stock, 875);
    final history = reopened.historyForOutlet('outlet-offline');
    expect(history, hasLength(1));
    expect(history.single.change, -125);
    expect(history.single.note, contains('Pesanan offline'));
    await reopened.waitForPendingSave();
    reopened.dispose();
  });

  test('unacknowledged movement stays in the durable ledger for retry', () async {
    expect(store.add(outletId: 'outlet-offline', name: 'Susu',
        unit: 'ml', stock: 500, minimumStock: 50), isTrue);
    await store.waitForPendingSave();
    final item = store.forOutlet('outlet-offline').single;
    expect(store.adjust(outletId: item.outletId, id: item.id, type: 'out',
        amount: 100, note: 'Pergerakan tanpa koneksi'), isTrue);
    await store.waitForPendingSave();

    final prefs = await SharedPreferences.getInstance();
    // Sent markers are separate from the local ledger and are only written
    // after a valid server acknowledgement.
    const sentKey =
        'firefa_inventory_synced_movements_v1:tenant-test:server-outlet-test:device-test';
    expect(prefs.getStringList(sentKey) ?? const <String>[], isEmpty);

    final reopened = FirefaInventoryStore.forTesting();
    await reopened.initialize();
    expect(reopened.forOutlet('outlet-offline').single.stock, 400);
    expect(reopened.historyForOutlet('outlet-offline'), hasLength(1));
    expect(prefs.getStringList(sentKey) ?? const <String>[], isEmpty);
    await reopened.waitForPendingSave();
    reopened.dispose();
  });

  test('movement history remains ordered and distinct across repeated saves', () async {
    expect(store.add(outletId: 'outlet-offline', name: 'Gula',
        unit: 'gram', stock: 1000, minimumStock: 100), isTrue);
    await store.waitForPendingSave();
    final item = store.forOutlet('outlet-offline').single;

    expect(store.adjust(outletId: item.outletId, id: item.id, type: 'out',
        amount: 100, note: 'event-1'), isTrue);
    await store.waitForPendingSave();
    expect(store.adjust(outletId: item.outletId, id: item.id, type: 'out',
        amount: 50, note: 'event-2'), isTrue);
    await store.waitForPendingSave();

    final reopened = FirefaInventoryStore.forTesting();
    await reopened.initialize();
    final history = reopened.historyForOutlet('outlet-offline');
    expect(history.map((movement) => movement.note), ['event-2', 'event-1']);
    expect(history.map((movement) => movement.id).toSet(), hasLength(2));
    expect(reopened.forOutlet('outlet-offline').single.stock, 850);
    await reopened.waitForPendingSave();
    reopened.dispose();
  });
}
