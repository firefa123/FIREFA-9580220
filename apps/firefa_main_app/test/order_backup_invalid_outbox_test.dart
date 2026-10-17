import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';
import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invalid outbox snapshot cannot replace active orders', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FirefaOrderStore.instance;
    final queue = FirefaOfflineSyncQueue.instance;
    await store.initialize();

    final order = store.createOrder(
      outletId: 'invalid-outbox-restore',
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
    final beforeStatus = store.findOrder('invalid-outbox-restore', order.id)!.status;
    final beforeEventIds = queue
        .entriesForOutlet('invalid-outbox-restore')
        .map((entry) => entry.eventId)
        .toList();

    final snapshot = store.exportLocalSnapshot();
    final outbox = Map<String, dynamic>.from(snapshot['outbox'] as Map);
    final entries = List<dynamic>.from(outbox['entries'] as List);
    entries.add(entries.first);
    outbox['entries'] = entries;

    expect(
      () => store.restoreLocalSnapshot({...snapshot, 'outbox': outbox}),
      throwsFormatException,
    );

    expect(
      store.findOrder('invalid-outbox-restore', order.id)!.status,
      beforeStatus,
    );
    expect(
      queue.entriesForOutlet('invalid-outbox-restore').map((entry) => entry.eventId),
      beforeEventIds,
    );
    await store.waitForPendingSave();
  });
}
