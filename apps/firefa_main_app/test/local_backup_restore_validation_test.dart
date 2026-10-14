import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/inventory_store.dart';
import 'package:firefa_main_app/features/modules/local_backup_manager.dart';
import 'package:firefa_main_app/features/modules/menu_store.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';
import 'package:firefa_main_app/features/modules/table_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('malformed outbox is rejected before inventory is replaced', () async {
    SharedPreferences.setMockInitialValues({});
    await Future.wait([
      FirefaOrderStore.instance.initialize(),
      FirefaInventoryStore.instance.initialize(),
      FirefaMenuStore.instance.initialize(),
      FirefaTableStore.instance.initialize(),
    ]);

    final inventory = FirefaInventoryStore.instance;
    final menu = FirefaMenuStore.instance;
    final tables = FirefaTableStore.instance;
    final backup = FirefaLocalBackupManager.instance;

    expect(inventory.add(
      outletId: 'OUTLET-A',
      name: 'Coffee Beans',
      unit: 'gram',
      stock: 500,
      minimumStock: 50,
    ), isTrue);
    await inventory.waitForPendingSave();

    final currentItem = inventory.forOutlet('OUTLET-A').single;
    final invalidOutbox = <String, dynamic>{
      'version': 1,
      'nextSequence': 1,
      'entries': [
        {'eventId': 'broken-event'},
      ],
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('firefa_local_backup_v1', jsonEncode({
      'backupVersion': 2,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'snapshot': {
        'orders': {
          'version': 2,
          'nextNumber': 1001,
          'orders': [],
          'outbox': invalidOutbox,
        },
        'inventory': {
          'version': 1,
          'nextId': 999,
          'items': [],
          'nextMovementId': 1,
          'movements': [],
          'nextOpnameId': 1,
          'opnames': [],
          'recipes': [],
          'processedOrderIds': [],
          'reversedOrderIds': [],
        },
        'menu': {
          'version': 1,
          'nextId': 1,
          'items': [],
        },
        'tables': [],
      },
    }));

    await expectLater(backup.restoreLatestBackup(), throwsFormatException);

    expect(inventory.forOutlet('OUTLET-A'), hasLength(1));
    expect(inventory.forOutlet('OUTLET-A').single.id, currentItem.id);
    expect(inventory.forOutlet('OUTLET-A').single.stock, 500);
    // Other stores are untouched as well because restore was rejected in preflight.
    expect(menu.forOutlet('OUTLET-A'), isEmpty);
    expect(tables.forOutlet('OUTLET-A'), isEmpty);
  });
}
