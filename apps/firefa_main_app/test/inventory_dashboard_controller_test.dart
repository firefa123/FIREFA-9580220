import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/inventory/inventory_dashboard_controller.dart';
import 'package:firefa_main_app/features/inventory/inventory_item_model.dart';

InventoryItem item(String id, double stock) => InventoryItem(
  id: id,
  name: 'Item $id',
  stock: stock,
  unit: 'pcs',
);

void main() {
  group('InventoryDashboardController', () {
    test('returns zero metrics for empty inventory', () {
      final summary = InventoryDashboardController().summary();
      expect(summary.totalItems, 0);
      expect(summary.lowStockItems, 0);
      expect(summary.outOfStockItems, 0);
    });

    test('counts total, low-stock, and out-of-stock items', () {
      final summary = InventoryDashboardController().summary(items: [
        item('A', 10),
        item('B', 5),
        item('C', 1),
        item('D', 0),
      ]);

      expect(summary.totalItems, 4);
      expect(summary.lowStockItems, 2);
      expect(summary.outOfStockItems, 1);
    });

    test('counts negative stock as out of stock, not low stock', () {
      final summary = InventoryDashboardController().summary(items: [
        item('A', -1),
      ]);
      expect(summary.totalItems, 1);
      expect(summary.lowStockItems, 0);
      expect(summary.outOfStockItems, 1);
    });

    test('does not count stock exactly above threshold as low', () {
      final summary = InventoryDashboardController().summary(items: [
        item('A', 5.01),
        item('B', 5),
      ]);
      expect(summary.lowStockItems, 1);
      expect(summary.outOfStockItems, 0);
    });
  });
}
