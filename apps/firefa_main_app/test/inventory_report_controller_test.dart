import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/inventory/inventory_report_controller.dart';

void main() {
  group('InventoryReportController', () {
    test('generates report from valid metrics', () {
      final report = InventoryReportController().generate(
        totalItems: 20,
        stockIn: 15,
        stockOut: 7,
        lowStockItems: 4,
      );
      expect(report.totalItems, 20);
      expect(report.stockIn, 15);
      expect(report.stockOut, 7);
      expect(report.lowStockItems, 4);
    });

    test('accepts zero values', () {
      final report = InventoryReportController().generate(
        totalItems: 0,
        stockIn: 0,
        stockOut: 0,
        lowStockItems: 0,
      );
      expect(report.totalItems, 0);
      expect(report.lowStockItems, 0);
    });

    test('rejects negative total item count', () {
      expect(
        () => InventoryReportController().generate(
          totalItems: -1, stockIn: 0, stockOut: 0, lowStockItems: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative stock movement counts', () {
      expect(
        () => InventoryReportController().generate(
          totalItems: 3, stockIn: -1, stockOut: 0, lowStockItems: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => InventoryReportController().generate(
          totalItems: 3, stockIn: 0, stockOut: -1, lowStockItems: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects low stock count outside total item range', () {
      final controller = InventoryReportController();
      expect(
        () => controller.generate(
          totalItems: 3, stockIn: 0, stockOut: 0, lowStockItems: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => controller.generate(
          totalItems: 3, stockIn: 0, stockOut: 0, lowStockItems: 4,
        ),
        throwsArgumentError,
      );
    });
  });
}
