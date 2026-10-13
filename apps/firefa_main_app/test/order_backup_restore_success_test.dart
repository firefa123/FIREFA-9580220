import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';
import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('valid backup restores order and outbox snapshot durably', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FirefaOrderStore.instance;
    final queue = FirefaOfflineSyncQueue.instance;
    await store.initialize();

    final order = store.createOrder(
      outletId: 'backup-success-outlet',
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
    final backup = store.exportLocalSnapshot();
    final backupEventIds = (backup['outbox'] as Map)['entries'] as List;

    expect(store.advance('backup-success-outlet', order.id), isTrue);
    await store.waitForPendingSave();
    expect(
      store.findOrder('backup-success-outlet', order.id)!.status,
      FirefaOrderStatus.preparing,
    );

    await store.restoreLocalSnapshotDurably(backup);

    expect(
      store.findOrder('backup-success-outlet', order.id)!.status,
      FirefaOrderStatus.confirmed,
    );
    expect(
      queue.entriesForOutlet('backup-success-outlet').map((entry) => entry.eventId),
      backupEventIds.map((entry) => (entry as Map)['eventId']),
    );
    await store.waitForPendingSave();
  });
}
