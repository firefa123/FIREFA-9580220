import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/analytics/inventory_analytics_controller.dart';
import 'package:firefa_main_app/features/modules/inventory_store.dart';

void main() {
  group('InventoryAnalyticsController', () {
    test('counts total, low-stock, and out-of-stock inventory items', () {
      final analytics = InventoryAnalyticsController(items: const [
        FirefaInventoryItem(
          id: 'INV-1',
          outletId: 'OUTLET-1',
          name: 'Coffee',
          unit: 'pack',
          stock: 10,
          minimumStock: 3,
        ),
        FirefaInventoryItem(
          id: 'INV-2',
          outletId: 'OUTLET-1',
          name: 'Milk',
          unit: 'liter',
          stock: 2,
          minimumStock: 3,
        ),
        FirefaInventoryItem(
          id: 'INV-3',
          outletId: 'OUTLET-1',
          name: 'Sugar',
          unit: 'kg',
          stock: 0,
          minimumStock: 5,
        ),
      ]);

      final summary = analytics.getSummary();

      expect(summary.totalItems, 3);
      expect(summary.lowStockItems, 1);
      expect(summary.outOfStockItems, 1);
    });

    test('returns zero totals when inventory is empty', () {
      final summary =
          InventoryAnalyticsController(items: const []).getSummary();

      expect(summary.totalItems, 0);
      expect(summary.lowStockItems, 0);
      expect(summary.outOfStockItems, 0);
    });
  });
}
