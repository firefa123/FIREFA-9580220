import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FirefaOfflineSyncQueue.instance.initialize();
  });

  FirefaOrder makeOrder(String id, String outlet) => FirefaOrder(
        id: id,
        outletId: outlet,
        orderType: 'Take Away',
        tableId: null,
        createdAt: DateTime.utc(2026, 1, 1),
        items: const [
          FirefaOrderItem(productName: 'Coffee', quantity: 1, unitPrice: 1000),
        ],
        subtotal: 1000,
        discount: 0,
        tax: 0,
        service: 0,
        total: 1000,
      );

  test('restore rejects duplicate event IDs and preserves current queue', () async {
    final queue = FirefaOfflineSyncQueue.instance;
    final existing = queue.enqueueOrder(makeOrder('existing-order', 'restore-outlet'), 'order.created');
    await queue.waitForPendingSave();
    final before = queue.exportSnapshot();

    final duplicate = {
      'version': 1,
      'nextSequence': 10,
      'entries': [
        existing.toJson(),
        existing.toJson(),
      ],
    };
    expect(
      () => queue.restoreCombinedSnapshot(duplicate),
      throwsFormatException,
    );
    expect(queue.findEvent(existing.eventId), isNotNull);
    expect(queue.exportSnapshot()['entries'], before['entries']);

    await queue.removeEvent(existing.eventId);
    await queue.waitForPendingSave();
  });

  test('malformed event payload is normalized and leaves queue intact', () async {
    final queue = FirefaOfflineSyncQueue.instance;
    final existing = queue.enqueueOrder(
      makeOrder('malformed-restore-order', 'restore-outlet'),
      'order.created',
    );
    await queue.waitForPendingSave();
    final before = queue.exportSnapshot();

    expect(
      () => queue.restoreCombinedSnapshot({
        'version': 1,
        'nextSequence': 20,
        'entries': [null],
      }),
      throwsFormatException,
    );
    expect(queue.findEvent(existing.eventId), isNotNull);
    expect(queue.exportSnapshot()['entries'], before['entries']);

    await queue.removeEvent(existing.eventId);
    await queue.waitForPendingSave();
  });

  test('restore validates identity and recovers interrupted sends', () async {
    final queue = FirefaOfflineSyncQueue.instance;
    final existing = queue.enqueueOrder(makeOrder('restore-order', 'restore-outlet'), 'order.created');
    await queue.waitForPendingSave();
    await queue.markSyncing(existing.eventId);

    final snapshot = queue.exportSnapshot();
    queue.restoreCombinedSnapshot(snapshot);
    await queue.waitForPendingSave();
    expect(queue.findEvent(existing.eventId)!.status, FirefaSyncStatus.pending);

    final invalid = {
      'version': 1,
      'nextSequence': 12,
      'entries': [
        {
          ...existing.toJson(),
          'orderId': 'wrong-order',
        }
      ],
    };
    expect(
      () => queue.restoreCombinedSnapshot(invalid),
      throwsFormatException,
    );
    expect(queue.findEvent(existing.eventId)!.status, FirefaSyncStatus.pending);

    await queue.removeEvent(existing.eventId);
    await queue.waitForPendingSave();
  });
}
