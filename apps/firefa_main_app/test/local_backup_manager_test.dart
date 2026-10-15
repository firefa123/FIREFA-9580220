import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/inventory_store.dart';
import 'package:firefa_main_app/features/modules/customer_store.dart';
import 'package:firefa_main_app/features/modules/local_backup_manager.dart';
import 'package:firefa_main_app/features/modules/menu_store.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';
import 'package:firefa_main_app/features/modules/table_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('full local backup restores inventory, menu, tables and order snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    await Future.wait([
      FirefaOrderStore.instance.initialize(),
      FirefaInventoryStore.instance.initialize(),
      FirefaMenuStore.instance.initialize(),
      FirefaTableStore.instance.initialize(),
      FirefaCustomerStore.instance.initialize(),
    ]);

    final inventory = FirefaInventoryStore.instance;
    final menu = FirefaMenuStore.instance;
    final tables = FirefaTableStore.instance;
    final backup = FirefaLocalBackupManager.instance;
    final customers = FirefaCustomerStore.instance;
    expect(customers.add(outletId: 'OUTLET-A', name: 'Backup Customer', phone: '08123456780', creditLimit: 50000), isTrue);

    expect(inventory.add(
      outletId: 'OUTLET-A',
      name: 'Coffee Beans',
      unit: 'gram',
      stock: 500,
      minimumStock: 50,
    ), isTrue);
    expect(menu.add(
      outletId: 'OUTLET-A',
      name: 'Americano',
      category: 'Coffee',
      price: 18000,
    ), isTrue);
    expect(tables.add('OUTLET-A', 'Meja 1'), isTrue);

    await Future.wait([
      inventory.waitForPendingSave(),
      menu.waitForPendingSave(),
      tables.waitForPendingSave(),
      FirefaOrderStore.instance.waitForPendingSave(),
    ]);

    await backup.createBackup();
    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('firefa_local_backup_v1')!) as Map;
    expect(stored['backupVersion'], 2);
    final snapshot = Map<String, dynamic>.from(stored['snapshot'] as Map);
    expect(snapshot.keys, containsAll(['orders', 'inventory', 'menu', 'tables', 'customers']));
    expect(customers.update(outletId: 'OUTLET-A', id: customers.forOutlet('OUTLET-A').single.id, name: 'Changed Customer', phone: '08123456780', email: '', creditLimit: 50000, notes: ''), isTrue);

    final ingredientId = inventory.forOutlet('OUTLET-A').single.id;
    final menuId = menu.forOutlet('OUTLET-A').single.id;
    final tableId = tables.forOutlet('OUTLET-A').single.id;
    // Deletion now protects non-zero stock. Clear the live stock after the
    // backup is taken so this test can still verify restoration of 500 units.
    expect(inventory.adjust(
      outletId: 'OUTLET-A',
      id: ingredientId,
      type: 'out',
      amount: 500,
      note: 'Prepare empty catalog for restore test',
    ), isTrue);
    expect(inventory.remove('OUTLET-A', ingredientId), isTrue);
    expect(menu.remove('OUTLET-A', menuId), isTrue);
    expect(tables.remove('OUTLET-A', tableId), isTrue);
    await Future.wait([
      inventory.waitForPendingSave(),
      menu.waitForPendingSave(),
      tables.waitForPendingSave(),
    ]);

    await backup.restoreLatestBackup();

    expect(inventory.forOutlet('OUTLET-A').single.name, 'Coffee Beans');
    expect(inventory.forOutlet('OUTLET-A').single.stock, 500);
    expect(menu.forOutlet('OUTLET-A').single.name, 'Americano');
    expect(tables.forOutlet('OUTLET-A').single.name, 'Meja 1');
    expect(customers.forOutlet('OUTLET-A').single.name, 'Backup Customer');
  });

  test('unsupported backup version is rejected before changing active data', () async {
    SharedPreferences.setMockInitialValues({});
    // The test runs in its own test isolate; initialize clean singleton stores.
    await Future.wait([
      FirefaOrderStore.instance.initialize(),
      FirefaInventoryStore.instance.initialize(),
      FirefaMenuStore.instance.initialize(),
      FirefaTableStore.instance.initialize(),
    ]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('firefa_local_backup_v1', jsonEncode({
      'backupVersion': 999,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'snapshot': {},
    }));
    await expectLater(
      FirefaLocalBackupManager.instance.restoreLatestBackup(),
      throwsFormatException,
    );
  });
}
