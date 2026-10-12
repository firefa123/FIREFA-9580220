import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  Map<String, dynamic> entryFor(FirefaOrder order, String eventId) => {
        'eventId': eventId,
        'outletId': order.outletId,
        'orderId': order.id,
        'eventType': 'order.created',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'orderSnapshot': order.toJson(),
        'status': 'pending',
        'attempts': 0,
        'nextAttemptAt': null,
      };

  test('initialize rejects duplicate IDs in persisted outbox', () async {
    final order = makeOrder('persisted-order', 'persisted-outlet');
    final entry = entryFor(order, 'evt-duplicate');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'firefa_sync_outbox_v1',
      jsonEncode({
        'version': 1,
        'nextSequence': 3,
        'entries': [entry, entry],
      }),
    );

    final queue = FirefaOfflineSyncQueue.instance;
    await expectLater(queue.initialize(), throwsFormatException);
  });

  test('restore recovers interrupted sends as pending', () async {
    final queue = FirefaOfflineSyncQueue.instance;
    await queue.initialize();
    final event = queue.enqueueOrder(
      makeOrder('recovery-order', 'recovery-outlet'),
      'order.created',
    );
    await queue.waitForPendingSave();
    await queue.markSyncing(event.eventId);
    await queue.waitForPendingSave();

    final snapshot = queue.exportSnapshot();
    queue.restoreCombinedSnapshot(snapshot);
    await queue.waitForPendingSave();
    expect(queue.findEvent(event.eventId)!.status, FirefaSyncStatus.pending);
  });
}
