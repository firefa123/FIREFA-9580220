import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/inventory/stock_movement_controller.dart';
import 'package:firefa_main_app/features/inventory/stock_movement_model.dart';

StockMovement movement(String id, {
  String itemId = 'item-1',
  String type = 'stockIn',
  double quantity = 2,
}) => StockMovement(
  id: id,
  itemId: itemId,
  type: type,
  quantity: quantity,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('StockMovementController', () {
    test('adds normalized movement and finds by ID', () {
      final controller = StockMovementController()
        ..addMovement(movement(' MOVE-1 ', type: ' STOCKIN '));
      expect(controller.findById('MOVE-1')?.type, 'stockin');
      expect(controller.history, hasLength(1));
    });

    test('rejects duplicate IDs', () {
      final controller = StockMovementController()..addMovement(movement('MOVE-1'));
      expect(() => controller.addMovement(movement(' MOVE-1 ')), throwsArgumentError);
    });

    test('rejects blank IDs or type', () {
      final controller = StockMovementController();
      expect(() => controller.addMovement(movement(' ')), throwsArgumentError);
      expect(() => controller.addMovement(movement('MOVE-1', itemId: ' ')), throwsArgumentError);
      expect(() => controller.addMovement(movement('MOVE-2', type: ' ')), throwsArgumentError);
    });

    test('rejects non-positive and non-finite quantities', () {
      final controller = StockMovementController();
      for (final quantity in <double>[0, -1, double.nan, double.infinity]) {
        expect(() => controller.addMovement(movement('MOVE-$quantity', quantity: quantity)), throwsArgumentError);
      }
    });

    test('filters history by item and movement type', () {
      final controller = StockMovementController()
        ..addMovement(movement('1', itemId: 'item-1', type: 'stockIn'))
        ..addMovement(movement('2', itemId: 'item-2', type: 'stockOut'))
        ..addMovement(movement('3', itemId: 'item-1', type: 'stockOut'));
      expect(controller.historyForItem('item-1'), hasLength(2));
      expect(controller.historyForType('STOCKOUT'), hasLength(2));
      expect(controller.historyForItem('missing'), isEmpty);
    });

    test('sums quantities for item and movement type', () {
      final controller = StockMovementController()
        ..addMovement(movement('1', quantity: 2, type: 'stockIn'))
        ..addMovement(movement('2', quantity: 3, type: 'stockIn'))
        ..addMovement(movement('3', quantity: 7, type: 'stockOut'));
      expect(controller.totalQuantityForItem('item-1', type: 'stockIn'), 5);
      expect(controller.totalQuantityForItem('item-1', type: 'stockOut'), 7);
    });

    test('exposes unmodifiable history', () {
      final controller = StockMovementController()..addMovement(movement('1'));
      expect(() => controller.history.clear(), throwsUnsupportedError);
      expect(() => controller.movements.clear(), throwsUnsupportedError);
    });
  });
}
