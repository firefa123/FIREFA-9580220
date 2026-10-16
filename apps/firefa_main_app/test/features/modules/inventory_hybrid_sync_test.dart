import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/modules/inventory_hybrid_sync.dart';

void main() {
  group('FirefaInventoryMovementRequest', () {
    final validRequest = FirefaInventoryMovementRequest(
      eventId: 'stock-event-001',
      outletId: 'outlet-1',
      itemId: 'item-1',
      expectedStock: 10,
      quantityDelta: -3,
      movementType: 'out',
      createdAt: DateTime.utc(2026, 10, 16),
    );

    test('validates movement and computes resulting stock', () {
      validRequest.validate();
      expect(validRequest.resultingStock, 7);
      expect(validRequest.toJson()['eventId'], 'stock-event-001');
    });

    test('rejects a stock movement that would make stock negative', () {
      final request = FirefaInventoryMovementRequest(
        eventId: 'event-2',
        outletId: 'outlet-1',
        itemId: 'item-1',
        expectedStock: 2,
        quantityDelta: -3,
        movementType: 'out',
        createdAt: DateTime.utc(2026, 10, 16),
      );
      expect(request.validate, throwsFormatException);
    });

    test('rejects inconsistent movement direction', () {
      final request = FirefaInventoryMovementRequest(
        eventId: 'event-3',
        outletId: 'outlet-1',
        itemId: 'item-1',
        expectedStock: 2,
        quantityDelta: -1,
        movementType: 'in',
        createdAt: DateTime.utc(2026, 10, 16),
      );
      expect(request.validate, throwsFormatException);
    });

    test('only accepts acknowledgement for the exact event and stock delta', () {
      const acknowledgement = FirefaInventoryMovementAcknowledgement(
        eventId: 'stock-event-001',
        outletId: 'outlet-1',
        itemId: 'item-1',
        previousStock: 10,
        currentStock: 7,
        duplicate: false,
      );
      expect(() => acknowledgement.validateFor(validRequest), returnsNormally);

      const wrongAck = FirefaInventoryMovementAcknowledgement(
        eventId: 'stock-event-001',
        outletId: 'outlet-1',
        itemId: 'item-1',
        previousStock: 10,
        currentStock: 8,
        duplicate: false,
      );
      expect(() => wrongAck.validateFor(validRequest), throwsFormatException);
    });

    test('parses server acknowledgement and rejects invalid stock values', () {
      expect(
        FirefaInventoryMovementAcknowledgement.fromJson({
          'eventId': 'event-4',
          'outletId': 'outlet-1',
          'itemId': 'item-1',
          'previousStock': 3,
          'currentStock': 4,
          'duplicate': false,
        }).currentStock,
        4,
      );
      expect(
        () => FirefaInventoryMovementAcknowledgement.fromJson({
          'eventId': 'event-4',
          'outletId': 'outlet-1',
          'itemId': 'item-1',
          'previousStock': 3,
          'currentStock': -1,
          'duplicate': false,
        }),
        throwsFormatException,
      );
    });
  });

  group('FirefaInventoryReconciliation', () {
    const reconciliation = FirefaInventoryReconciliation();

    test('reconciles identical snapshots', () {
      final result = reconciliation.reconcile(
        localStockByItem: {'item-1': 5, 'item-2': 0},
        serverStockByItem: {'item-1': 5, 'item-2': 0},
      );
      expect(result.isReconciled, isTrue);
      expect(result.matched, 2);
      expect(result.conflictingItemIds, isEmpty);
    });

    test('reports stock differences and missing server items', () {
      final result = reconciliation.reconcile(
        localStockByItem: {'item-1': 5, 'item-2': 8},
        serverStockByItem: {'item-1': 4, 'item-3': 1},
      );
      expect(result.isReconciled, isFalse);
      expect(result.matched, 0);
      expect(result.conflictingItemIds, ['item-1', 'item-2', 'item-3']);
    });

    test('rejects invalid snapshots instead of coercing stock to zero', () {
      expect(
        () => reconciliation.reconcile(
          localStockByItem: {'item-1': -1},
          serverStockByItem: {'item-1': 0},
        ),
        throwsFormatException,
      );
    });

    test('negative stock is always a conflict', () {
      expect(
        reconciliation.evaluate(localStock: -1, serverStock: -1),
        FirefaInventorySyncStatus.conflict,
      );
    });
  });
}
