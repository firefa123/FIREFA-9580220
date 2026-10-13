import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';

FirefaOrder _order(String id) => FirefaOrder(
  id: id,
  outletId: 'restore-atomicity-outlet',
  orderType: 'Take Away',
  tableId: null,
  createdAt: DateTime.utc(2026, 10, 13),
  items: const [
    FirefaOrderItem(productName: 'Tea', quantity: 1, unitPrice: 1000),
  ],
  subtotal: 1000,
  discount: 0,
  tax: 0,
  service: 0,
  total: 1000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invalid combined snapshot cannot partially replace the live outbox', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = FirefaOfflineSyncQueue.instance;
    await queue.initialize();

    final existing = queue.enqueueOrder(_order('KEEP-EXISTING'), 'order.created');
    await queue.waitForPendingSave();
    final before = queue.exportSnapshot();

    final duplicate = FirefaSyncEntry.fromJson({
      ...existing.toJson(),
      'eventId': 'duplicate-event-id',
    });
    final invalid = <String, dynamic>{
      'version': 1,
      'nextSequence': 3,
      'entries': [
        duplicate.toJson(),
        duplicate.toJson(),
      ],
    };

    expect(
      () => queue.restoreCombinedSnapshot(invalid),
      throwsFormatException,
    );

    expect(queue.findEvent(existing.eventId), isNotNull);
    expect(queue.findEvent(existing.eventId)!.status, FirefaSyncStatus.pending);
    expect(queue.entriesForOutlet('restore-atomicity-outlet'), hasLength(1));
    expect(queue.exportSnapshot()['nextSequence'], before['nextSequence']);

    await queue.waitForPendingSave();
    await queue.removeEvent(existing.eventId);
    await queue.waitForPendingSave();
  });
}
