import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';

FirefaOrder _order(String id, String outletId) => FirefaOrder(
      id: id,
      outletId: outletId,
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
  final queue = FirefaOfflineSyncQueue.instance;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await queue.initialize();
  });

  Future<FirefaSyncEntry> createEvent(String suffix, String outlet) async {
    final entry = queue.enqueueOrder(_order('STATE-$suffix', outlet), 'order.created');
    await queue.waitForPendingSave();
    return entry;
  }

  Future<void> remove(FirefaSyncEntry entry) async {
    await queue.removeEvent(entry.eventId);
    await queue.waitForPendingSave();
  }

  test('terminal transitions require an event to be syncing', () async {
    final entry = await createEvent('guards', 'state-guard-outlet');

    await expectLater(queue.markSynced(entry.eventId), throwsStateError);
    await expectLater(queue.markFailed(entry.eventId), throwsStateError);
    await expectLater(queue.markConflict(entry.eventId), throwsStateError);
    expect(entry.status, FirefaSyncStatus.pending);

    await queue.markSyncing(entry.eventId);
    await queue.markSynced(entry.eventId);
    expect(entry.status, FirefaSyncStatus.synced);
    await expectLater(queue.markSyncing(entry.eventId), throwsStateError);
    await remove(entry);
  });

  test('failed events require explicit outlet-scoped retry', () async {
    final failed = await createEvent('failed-a', 'state-outlet-A');
    final unrelated = await createEvent('failed-b', 'state-outlet-B');

    await queue.markSyncing(failed.eventId);
    await queue.markFailed(failed.eventId);
    await queue.markSyncing(unrelated.eventId);
    await queue.markFailed(unrelated.eventId);

    expect(await queue.retryFailedForOutlet('state-outlet-A'), 1);
    expect(failed.status, FirefaSyncStatus.pending);
    expect(failed.nextAttemptAt, isNull);
    expect(unrelated.status, FirefaSyncStatus.failed);

    await remove(failed);
    await remove(unrelated);
  });

  test('conflict event cannot enter a pending batch before resolution', () async {
    final entry = await createEvent('conflict', 'state-conflict-outlet');
    await queue.markSyncing(entry.eventId);
    await queue.markConflict(entry.eventId);

    expect(entry.status, FirefaSyncStatus.conflict);
    expect(
      queue.entriesForOutlet(entry.outletId).where((value) => value.eventId == entry.eventId),
      hasLength(1),
    );

    final snapshot = queue.exportSnapshot();
    final restored = Map<String, dynamic>.from(snapshot);
    final restoredEntries = List<dynamic>.from(restored['entries'] as List);
    final row = Map<String, dynamic>.from(
      restoredEntries.singleWhere((value) =>
          Map<String, dynamic>.from(value as Map)['eventId'] == entry.eventId) as Map,
    );
    expect(row['status'], FirefaSyncStatus.conflict.name);
    await remove(entry);
  });
}
