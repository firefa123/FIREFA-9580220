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

  FirefaOrder makeOrder() => FirefaOrder(
        id: 'retry-guard-order',
        outletId: 'retry-guard-outlet',
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

  test('terminal events cannot be moved back to pending', () async {
    final queue = FirefaOfflineSyncQueue.instance;
    final failed = queue.enqueueOrder(makeOrder(), 'order.created');
    await queue.waitForPendingSave();
    await queue.markSyncing(failed.eventId);
    await queue.markFailed(failed.eventId);

    await expectLater(
      queue.markPending(failed.eventId),
      throwsStateError,
    );
    expect(failed.status, FirefaSyncStatus.failed);

    await queue.removeEvent(failed.eventId);
    await queue.waitForPendingSave();
  });

  test('syncing events can return to pending after retryable transport failure', () async {
    final queue = FirefaOfflineSyncQueue.instance;
    final event = queue.enqueueOrder(makeOrder(), 'order.created');
    await queue.waitForPendingSave();
    await queue.markSyncing(event.eventId);
    await queue.markPending(event.eventId, retryDelay: const Duration(seconds: 5));

    expect(event.status, FirefaSyncStatus.pending);
    expect(event.nextAttemptAt, isNotNull);
    await queue.removeEvent(event.eventId);
    await queue.waitForPendingSave();
  });
}
