import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/sync_adapter.dart';
import 'package:firefa_main_app/features/modules/sync_engine.dart';

FirefaOrder makeOrder(String id, String outlet) => FirefaOrder(
  id: id,
  outletId: outlet,
  orderType: 'Take Away',
  tableId: null,
  createdAt: DateTime.utc(2026, 1, 1),
  items: [const FirefaOrderItem(productName: 'Test', quantity: 1, unitPrice: 1000)],
  subtotal: 1000,
  discount: 0,
  tax: 0,
  service: 0,
  total: 1000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final queue = FirefaOfflineSyncQueue.instance;
  const engine = FirefaSyncEngine();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await queue.initialize();
  });

  test('FIFO selection, batch limit and outlet isolation', () async {
    final first = queue.enqueueOrder(makeOrder('TEST-A1', 'test-outlet-A'), 'order.created');
    final second = queue.enqueueOrder(makeOrder('TEST-B1', 'test-outlet-B'), 'order.created');
    final third = queue.enqueueOrder(makeOrder('TEST-A2', 'test-outlet-A'), 'order.created');
    final batch = engine.pendingBatch(queue: queue, outletId: 'test-outlet-A', limit: 1);
    expect(batch, hasLength(1));
    expect(batch.single.eventId, first.eventId);
    final allA = engine.pendingBatch(queue: queue, outletId: 'test-outlet-A');
    expect(allA.map((e) => e.eventId), [first.eventId, third.eventId]);
    expect(allA.every((e) => e.outletId == 'test-outlet-A'), isTrue);
    expect(engine.pendingBatch(queue: queue, outletId: 'test-outlet-B').single.eventId, second.eventId);
    await queue.waitForPendingSave();
  });

  test('batch validates limits and outlet', () {
    expect(() => engine.pendingBatch(queue: queue, outletId: ''), throwsArgumentError);
    expect(() => engine.pendingBatch(queue: queue, outletId: 'test-outlet-A', limit: 0), throwsRangeError);
    expect(() => engine.pendingBatch(queue: queue, outletId: 'test-outlet-A', limit: 101), throwsRangeError);
  });

  test('retry policy uses exponential backoff with cap', () {
    expect(engine.retryDelay(0), const Duration(seconds: 1));
    expect(engine.retryDelay(1), const Duration(seconds: 2));
    expect(engine.retryDelay(3), const Duration(seconds: 8));
    expect(engine.retryDelay(8), const Duration(seconds: 256));
    expect(engine.retryDelay(100), const Duration(seconds: 256));
    expect(() => engine.retryDelay(-1), throwsArgumentError);
  });

  test('acknowledgement requires matching event and server reference', () {
    final envelope = FirefaSyncEnvelope.fromEntry(
      queue.entriesForOutlet('test-outlet-A').first,
    );
    expect(engine.isValidAcknowledgement(envelope, FirefaSyncReceipt(
      eventId: envelope.eventId,
      outcome: FirefaSyncOutcome.acknowledged,
      serverReference: 'server-1',
    )), isTrue);
    expect(engine.isValidAcknowledgement(envelope, const FirefaSyncReceipt(
      eventId: 'wrong-id',
      outcome: FirefaSyncOutcome.acknowledged,
      serverReference: 'server-1',
    )), isFalse);
    expect(engine.isValidAcknowledgement(envelope, FirefaSyncReceipt(
      eventId: envelope.eventId,
      outcome: FirefaSyncOutcome.acknowledged,
    )), isFalse);
  });

  test('disabled transport never acknowledges and leaves queue pending', () async {
    final entry = queue.entriesForOutlet('test-outlet-A').first;
    final before = queue.pendingCountForOutlet('test-outlet-A');
    final envelope = FirefaSyncEnvelope.fromEntry(entry);
    final receipt = await const FirefaDisabledSyncAdapter().send(envelope);
    expect(receipt.outcome, FirefaSyncOutcome.retryableFailure);
    expect(engine.isValidAcknowledgement(envelope, receipt), isFalse);
    expect(queue.pendingCountForOutlet('test-outlet-A'), before);
    expect(entry.status, FirefaSyncStatus.pending);
  });
}
