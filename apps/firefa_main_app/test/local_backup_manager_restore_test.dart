import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/local_backup_manager.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backup manager restores a valid saved order snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FirefaOrderStore.instance;
    final backups = FirefaLocalBackupManager.instance;
    await store.initialize();
    await backups.initialize();

    final order = store.createOrder(
      outletId: 'backup-manager-restore',
      orderType: 'Take Away',
      tableId: null,
      items: const [
        FirefaOrderItem(productName: 'Tea', quantity: 1, unitPrice: 1000),
      ],
      subtotal: 1000,
      discount: 0,
      tax: 0,
      service: 0,
      total: 1000,
    );
    await store.waitForPendingSave();

    final created = await backups.createBackup();
    expect(created.orderCount, 1);

    expect(store.advance('backup-manager-restore', order.id), isTrue);
    await store.waitForPendingSave();
    expect(
      store.findOrder('backup-manager-restore', order.id)!.status,
      FirefaOrderStatus.preparing,
    );

    final restored = await backups.restoreLatestBackup();
    expect(restored.orderCount, 1);
    expect(
      store.findOrder('backup-manager-restore', order.id)!.status,
      FirefaOrderStatus.confirmed,
    );
    await store.waitForPendingSave();
  });
}
