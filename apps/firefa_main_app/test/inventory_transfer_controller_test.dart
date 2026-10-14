import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/inventory/inventory_outlet_stock_model.dart';
import 'package:firefa_main_app/features/inventory/inventory_transfer_controller.dart';

InventoryOutletStock stock({
  String outletId = 'outlet-1',
  String itemId = 'item-1',
  double quantity = 2,
}) => InventoryOutletStock(
  outletId: outletId,
  itemId: itemId,
  quantity: quantity,
);

void main() {
  group('InventoryTransferController', () {
    test('records normalized outlet stock transfer', () {
      final controller = InventoryTransferController();
      controller.transfer(stock(outletId: ' outlet-1 ', itemId: ' item-1 '));

      expect(controller.history, hasLength(1));
      expect(controller.history.single.outletId, 'outlet-1');
      expect(controller.history.single.itemId, 'item-1');
      expect(controller.history.single.quantity, 2);
    });

    test('rejects blank outlet and item IDs', () {
      final controller = InventoryTransferController();
      expect(() => controller.transfer(stock(outletId: ' ')), throwsArgumentError);
      expect(() => controller.transfer(stock(itemId: ' ')), throwsArgumentError);
      expect(controller.history, isEmpty);
    });

    test('rejects non-positive or non-finite quantity', () {
      final controller = InventoryTransferController();
      for (final quantity in <double>[0, -1, double.nan, double.infinity]) {
        expect(
          () => controller.transfer(stock(quantity: quantity)),
          throwsArgumentError,
        );
      }
      expect(controller.history, isEmpty);
    });

    test('filters history by outlet and item', () {
      final controller = InventoryTransferController()
        ..transfer(stock(outletId: 'outlet-1', itemId: 'item-1', quantity: 2))
        ..transfer(stock(outletId: 'outlet-2', itemId: 'item-1', quantity: 3))
        ..transfer(stock(outletId: 'outlet-1', itemId: 'item-2', quantity: 4));

      expect(controller.historyForOutlet('outlet-1'), hasLength(2));
      expect(controller.historyForItem('item-1'), hasLength(2));
      expect(controller.historyForOutlet('missing'), isEmpty);
    });

    test('sums quantities recorded for an outlet', () {
      final controller = InventoryTransferController()
        ..transfer(stock(outletId: 'outlet-1', quantity: 2))
        ..transfer(stock(outletId: 'outlet-1', itemId: 'item-2', quantity: 4))
        ..transfer(stock(outletId: 'outlet-2', quantity: 10));

      expect(controller.totalQuantityForOutlet('outlet-1'), 6);
    });

    test('history and transfers cannot be mutated externally', () {
      final controller = InventoryTransferController()..transfer(stock());
      expect(() => controller.history.clear(), throwsUnsupportedError);
      expect(() => controller.transfers.clear(), throwsUnsupportedError);
    });
  });
}
