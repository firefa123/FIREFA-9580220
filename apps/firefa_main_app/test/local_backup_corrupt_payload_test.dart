import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/local_backup_manager.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('corrupt stored backup is rejected without mutating active orders', () async {
    SharedPreferences.setMockInitialValues({
      'firefa_local_backup_v1': '{"backupVersion":1,"createdAt":"broken","snapshot":{',
    });
    final store = FirefaOrderStore.instance;
    final backups = FirefaLocalBackupManager.instance;
    await store.initialize();
    await backups.initialize();

    final order = store.createOrder(
      outletId: 'corrupt-backup-outlet',
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
    final before = store.ordersForOutlet('corrupt-backup-outlet');

    await expectLater(backups.restoreLatestBackup(), throwsFormatException);

    expect(store.ordersForOutlet('corrupt-backup-outlet'), before);
    expect(
      store.findOrder('corrupt-backup-outlet', order.id),
      isNotNull,
    );
    await store.waitForPendingSave();
  });
}
