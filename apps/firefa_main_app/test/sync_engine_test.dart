import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/sync_adapter.dart';
import 'package:firefa_main_app/features/modules/sync_engine.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';
import 'package:firefa_main_app/features/modules/conflict_management.dart';
import 'package:firefa_main_app/features/modules/conflict_store.dart';
import 'package:firefa_main_app/features/modules/hybrid_sync_conflict_bridge.dart';
import 'package:firefa_main_app/features/modules/sync_coordinator.dart';

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

class _ConflictAdapter extends FirefaSyncAdapter {
  final Map<String, dynamic> serverSnapshot;
  final String outletId;
  final String orderId;

  const _ConflictAdapter({
    required this.serverSnapshot,
    required this.outletId,
    required this.orderId,
  });

  @override
  Future<FirefaSyncReceipt> send(FirefaSyncEnvelope event) async =>
      FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.conflict,
        serverOutletId: outletId,
        serverOrderId: orderId,
        serverSnapshot: serverSnapshot,
        conflictKind: FirefaConflictKind.concurrentEdit,
      );
}

class _CountingAckAdapter extends FirefaSyncAdapter {
  int sends = 0;

  @override
  Future<FirefaSyncReceipt> send(FirefaSyncEnvelope event) async {
    sends++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return FirefaSyncReceipt(
      eventId: event.eventId,
      outcome: FirefaSyncOutcome.acknowledged,
      serverReference: 'receipt-${event.eventId}',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final queue = FirefaOfflineSyncQueue.instance;
  const engine = FirefaSyncEngine();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await queue.initialize();
    await FirefaOrderStore.instance.initialize();
    await FirefaConflictStore.instance.initialize();
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

  test('retry backoff adds bounded jitter and respects five minute cap', () {
    expect(
      engine.retryDelay(0, jitterMilliseconds: 500),
      const Duration(milliseconds: 1500),
    );
    expect(
      engine.retryDelay(3, jitterMilliseconds: 1000),
      const Duration(seconds: 9),
    );
    expect(
      engine.retryDelay(8, jitterMilliseconds: 1000),
      const Duration(seconds: 257),
    );
    expect(
      () => engine.retryDelay(1, jitterMilliseconds: 1001),
      throwsRangeError,
    );
  });

  test('restoring interrupted sends persists pending status and retry time', () async {
    final interrupted = queue.enqueueOrder(
      makeOrder('RECOVERY-SYNCING', 'recovery-test-outlet'),
      'order.created',
    );
    final deferred = queue.enqueueOrder(
      makeOrder('RECOVERY-DEFERRED', 'recovery-test-outlet'),
      'order.created',
    );
    await queue.waitForPendingSave();

    await queue.markSyncing(interrupted.eventId);
    await queue.markPending(
      deferred.eventId,
      retryDelay: const Duration(minutes: 2),
    );
    final expectedRetryAt = deferred.nextAttemptAt;
    final snapshot = queue.exportSnapshot();

    queue.restoreCombinedSnapshot(snapshot);
    await queue.waitForPendingSave();

    expect(queue.findEvent(interrupted.eventId)!.status, FirefaSyncStatus.pending);
    expect(queue.findEvent(interrupted.eventId)!.nextAttemptAt, isNull);
    expect(queue.findEvent(deferred.eventId)!.status, FirefaSyncStatus.pending);
    expect(queue.findEvent(deferred.eventId)!.nextAttemptAt, expectedRetryAt);

    final prefs = await SharedPreferences.getInstance();
    final saved = Map<String, dynamic>.from(
      jsonDecode(prefs.getString('firefa_sync_outbox_v1')!) as Map,
    );
    final savedEntries = (saved['entries'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    expect(
      savedEntries.firstWhere((entry) => entry['eventId'] == interrupted.eventId)['status'],
      FirefaSyncStatus.pending.name,
    );
    expect(
      savedEntries.firstWhere((entry) => entry['eventId'] == deferred.eventId)['nextAttemptAt'],
      expectedRetryAt!.toIso8601String(),
    );

    await queue.removeEvent(interrupted.eventId);
    await queue.removeEvent(deferred.eventId);
    await queue.waitForPendingSave();
  });

  test('pending batch respects retry time and excludes failed events', () async {
    final dueOrder = queue.enqueueOrder(
      makeOrder('RETRY-DUE-1', 'retry-window-outlet'),
      'order.created',
    );
    final failedOrder = queue.enqueueOrder(
      makeOrder('RETRY-FAILED-1', 'retry-window-outlet'),
      'order.created',
    );
    await queue.waitForPendingSave();

    await queue.markPending(
      dueOrder.eventId,
      retryDelay: const Duration(minutes: 2),
    );
    await queue.markSyncing(failedOrder.eventId);
    await queue.markFailed(failedOrder.eventId);

    final beforeDue = engine.pendingBatch(
      queue: queue,
      outletId: 'retry-window-outlet',
      now: DateTime.now().toUtc(),
    );
    expect(beforeDue.any((event) => event.eventId == dueOrder.eventId), isFalse);
    expect(beforeDue.any((event) => event.eventId == failedOrder.eventId), isFalse);

    final afterDue = engine.pendingBatch(
      queue: queue,
      outletId: 'retry-window-outlet',
      now: DateTime.now().toUtc().add(const Duration(minutes: 3)),
    );
    expect(afterDue.map((event) => event.eventId), [dueOrder.eventId]);

    await queue.removeEvent(dueOrder.eventId);
    await queue.removeEvent(failedOrder.eventId);
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

  test('Keep Local retains order and replaces conflicted outbox event', () async {
    final store = FirefaOrderStore.instance;
    final order = store.createOrder(
      outletId: 'conflict-keep-local', orderType: 'Take Away', tableId: null,
      items: const [FirefaOrderItem(productName: 'Tea', quantity: 1, unitPrice: 1000)],
      subtotal: 1000, discount: 0, tax: 0, service: 0, total: 1000,
    );
    await store.waitForPendingSave();
    final entry = queue.entriesForOutlet(order.outletId).last;
    final server = Map<String, dynamic>.from(order.toJson())..['status'] = 'preparing';
    final bridge = FirefaHybridSyncConflictBridge(store: FirefaConflictStore.instance);
    expect(await bridge.processServerMismatch(
      local: entry, outletId: order.outletId, orderId: order.id,
      serverSnapshot: server,
    ), isTrue);

    await store.reconcileConflict(
      eventId: entry.eventId, outletId: order.outletId, orderId: order.id,
      acceptServer: false,
    );
    expect(store.findOrder(order.outletId, order.id)!.status, FirefaOrderStatus.confirmed);
    expect(queue.entriesForOutlet(order.outletId).any((e) => e.eventId == entry.eventId), isFalse);
    expect(queue.entriesForOutlet(order.outletId).where(
      (e) => e.orderId == order.id && e.eventType == 'order.updated',
    ), hasLength(1));
    // Retrying after a partial failure must not create duplicate outbox events.
    await store.reconcileConflict(
      eventId: entry.eventId, outletId: order.outletId, orderId: order.id,
      acceptServer: false,
    );
    expect(queue.entriesForOutlet(order.outletId).where(
      (e) => e.orderId == order.id && e.eventType == 'order.updated',
    ), hasLength(1));
    await FirefaConflictStore.instance.remove(entry.eventId);
    await store.waitForPendingSave();
  });

  test('Accept Server applies a validated server snapshot to the local order', () async {
    final store = FirefaOrderStore.instance;
    final order = store.createOrder(
      outletId: 'conflict-accept-server', orderType: 'Take Away', tableId: null,
      items: const [FirefaOrderItem(productName: 'Coffee', quantity: 1, unitPrice: 1500)],
      subtotal: 1500, discount: 0, tax: 0, service: 0, total: 1500,
    );
    await store.waitForPendingSave();
    final entry = queue.entriesForOutlet(order.outletId).last;
    final server = Map<String, dynamic>.from(order.toJson())..['status'] = 'preparing';
    final bridge = FirefaHybridSyncConflictBridge(store: FirefaConflictStore.instance);
    expect(await bridge.processServerMismatch(
      local: entry, outletId: order.outletId, orderId: order.id,
      serverSnapshot: server,
    ), isTrue);

    await store.reconcileConflict(
      eventId: entry.eventId, outletId: order.outletId, orderId: order.id,
      acceptServer: true, serverSnapshot: server,
    );
    expect(store.findOrder(order.outletId, order.id)!.status, FirefaOrderStatus.preparing);
    expect(queue.entriesForOutlet(order.outletId).any((e) => e.eventId == entry.eventId), isFalse);
    await FirefaConflictStore.instance.remove(entry.eventId);
    await store.waitForPendingSave();
  });

  test('Accept Server rejects invalid item totals without mutating local order', () async {
    final store = FirefaOrderStore.instance;
    final outletId = 'conflict-invalid-server';
    final order = store.createOrder(
      outletId: outletId, orderType: 'Take Away', tableId: null,
      items: const [FirefaOrderItem(productName: 'Rice', quantity: 1, unitPrice: 1500)],
      subtotal: 1500, discount: 0, tax: 0, service: 0, total: 1500,
    );
    await store.waitForPendingSave();
    final entry = queue.entriesForOutlet(outletId).last;
    final invalidServer = Map<String, dynamic>.from(order.toJson())
      ..['items'] = [
        FirefaOrderItem(productName: 'Rice', quantity: -1, unitPrice: 1500).toJson(),
      ]
      ..['status'] = 'preparing';
    await expectLater(
      store.reconcileConflict(
        eventId: entry.eventId,
        outletId: outletId,
        orderId: order.id,
        acceptServer: true,
        serverSnapshot: invalidServer,
      ),
      throwsFormatException,
    );
    expect(store.findOrder(outletId, order.id)!.status, FirefaOrderStatus.confirmed);
    expect(queue.findEvent(entry.eventId), isNotNull);
    await queue.removeEvent(entry.eventId);
    await store.waitForPendingSave();
  });

  test('sync coordinator automatically routes server mismatch into conflict inbox', () async {
    final store = FirefaOrderStore.instance;
    final outletId = 'coordinator-conflict-outlet';
    final order = store.createOrder(
      outletId: outletId, orderType: 'Take Away', tableId: null,
      items: const [FirefaOrderItem(productName: 'Noodle', quantity: 1, unitPrice: 2000)],
      subtotal: 2000, discount: 0, tax: 0, service: 0, total: 2000,
    );
    await store.waitForPendingSave();
    final event = queue.entriesForOutlet(outletId).last;
    final server = Map<String, dynamic>.from(order.toJson())..['status'] = 'preparing';
    final coordinator = FirefaSyncCoordinator(
      queue: queue,
      adapter: _ConflictAdapter(
        serverSnapshot: server, outletId: outletId, orderId: order.id,
      ),
      conflictBridge: FirefaHybridSyncConflictBridge(store: FirefaConflictStore.instance),
    );

    final summary = await coordinator.syncOutlet(outletId);
    expect(summary.attempted, 1);
    expect(summary.conflicts, 1);
    expect(summary.acknowledged, 0);
    expect(FirefaConflictStore.instance.conflicts.any((c) => c.eventId == event.eventId), isTrue);
    expect(queue.findEvent(event.eventId)!.status, FirefaSyncStatus.conflict);
    expect(queue.findEvent(event.eventId)!.attempts, 1);
    expect(engine.pendingBatch(queue: queue, outletId: outletId), isEmpty);

    await FirefaConflictStore.instance.remove(event.eventId);
    await queue.removeEvent(event.eventId);
    await store.waitForPendingSave();
  });

  test('Accept Server rejects invalid totals without mutating local order or outbox', () async {
    final store = FirefaOrderStore.instance;
    const outletId = 'invalid-server-snapshot';
    final order = store.createOrder(
      outletId: outletId,
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
    final event = queue.entriesForOutlet(outletId).last;
    final invalidSnapshot = Map<String, dynamic>.from(order.toJson())
      ..['total'] = 500;

    await expectLater(
      store.reconcileConflict(
        eventId: event.eventId,
        outletId: outletId,
        orderId: order.id,
        acceptServer: true,
        serverSnapshot: invalidSnapshot,
      ),
      throwsFormatException,
    );

    expect(store.findOrder(outletId, order.id)!.total, 1000);
    expect(queue.findEvent(event.eventId), isNotNull);
    expect(queue.findEvent(event.eventId)!.status, FirefaSyncStatus.pending);

    await queue.removeEvent(event.eventId);
    await store.waitForPendingSave();
  });

  test('outbox rejects illegal terminal state transitions', () async {
    final event = queue.enqueueOrder(
      makeOrder('ILLEGAL-TRANSITION', 'transition-test-outlet'),
      'order.created',
    );
    await queue.waitForPendingSave();

    await expectLater(queue.markSynced(event.eventId), throwsStateError);
    await expectLater(queue.markConflict(event.eventId), throwsStateError);
    await expectLater(queue.markFailed(event.eventId), throwsStateError);
    expect(event.status, FirefaSyncStatus.pending);

    await queue.removeEvent(event.eventId);
    await queue.waitForPendingSave();
  });

  test('syncing increments attempts and can safely return to pending', () async {
    final event = queue.enqueueOrder(
      makeOrder('STATUS-TEST', 'status-test-outlet'),
      'order.created',
    );
    await queue.waitForPendingSave();

    await queue.markSyncing(event.eventId);
    expect(event.status, FirefaSyncStatus.syncing);
    expect(event.attempts, 1);

    await queue.markPending(event.eventId);
    expect(event.status, FirefaSyncStatus.pending);
    expect(event.attempts, 1);

    await queue.removeEvent(event.eventId);
    await queue.waitForPendingSave();
  });

  test('permanent failure is recorded and explicit retry restores pending', () async {
    final event = queue.enqueueOrder(
      makeOrder('FAILED-TEST', 'failed-test-outlet'),
      'order.created',
    );
    await queue.waitForPendingSave();
    await queue.markSyncing(event.eventId);
    await queue.markFailed(event.eventId);
    expect(event.status, FirefaSyncStatus.failed);

    expect(await queue.retryFailedForOutlet('failed-test-outlet'), 1);
    expect(event.status, FirefaSyncStatus.pending);
    expect(await queue.retryFailedForOutlet('failed-test-outlet'), 0);

    await queue.removeEvent(event.eventId);
    await queue.waitForPendingSave();
  });

  test('concurrent sync requests never send the same event twice', () async {
    final event = queue.enqueueOrder(
      makeOrder('CONCURRENT-SYNC', 'concurrent-test-outlet'),
      'order.created',
    );
    await queue.waitForPendingSave();
    final adapter = _CountingAckAdapter();
    final coordinator = FirefaSyncCoordinator(
      queue: queue,
      adapter: adapter,
      conflictBridge: FirefaHybridSyncConflictBridge(
        store: FirefaConflictStore.instance,
      ),
    );

    final summaries = await Future.wait([
      coordinator.syncOutlet('concurrent-test-outlet'),
      coordinator.syncOutlet('concurrent-test-outlet'),
    ]);

    expect(adapter.sends, 1);
    expect(summaries.fold<int>(0, (sum, value) => sum + value.attempted), 1);
    expect(summaries.fold<int>(0, (sum, value) => sum + value.acknowledged), 1);
    expect(summaries.fold<int>(0, (sum, value) => sum + value.retryableFailures), 0);
    expect(event.status, FirefaSyncStatus.synced);

    await queue.removeEvent(event.eventId);
    await queue.waitForPendingSave();
  });

  test('coordinator schedules retry after disabled transport failure', () async {
    final event = queue.enqueueOrder(
      makeOrder('COORDINATOR-RETRY', 'coordinator-retry-outlet'),
      'order.created',
    );
    await queue.waitForPendingSave();
    final coordinator = FirefaSyncCoordinator(
      queue: queue,
      adapter: const FirefaDisabledSyncAdapter(),
      conflictBridge: FirefaHybridSyncConflictBridge(
        store: FirefaConflictStore.instance,
      ),
    );

    final summary = await coordinator.syncOutlet('coordinator-retry-outlet');
    expect(summary.attempted, 1);
    expect(summary.retryableFailures, 1);
    expect(event.status, FirefaSyncStatus.pending);
    expect(event.attempts, 1);
    expect(event.nextAttemptAt, isNotNull);
    expect(event.nextAttemptAt!.isAfter(DateTime.now().toUtc()), isTrue);
    expect(
      engine.pendingBatch(
        queue: queue,
        outletId: 'coordinator-retry-outlet',
      ),
      isEmpty,
    );

    await queue.removeEvent(event.eventId);
    await queue.waitForPendingSave();
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
