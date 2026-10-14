import 'inventory_report_model.dart';

/// Validates and builds a summary report from supplied inventory movement data.
class InventoryReportController {
  InventoryReportModel generate({
    required int totalItems,
    required int stockIn,
    required int stockOut,
    required int lowStockItems,
  }) {
    if (totalItems < 0) {
      throw ArgumentError.value(totalItems, 'totalItems', 'Cannot be negative.');
    }
    if (stockIn < 0) {
      throw ArgumentError.value(stockIn, 'stockIn', 'Cannot be negative.');
    }
    if (stockOut < 0) {
      throw ArgumentError.value(stockOut, 'stockOut', 'Cannot be negative.');
    }
    if (lowStockItems < 0 || lowStockItems > totalItems) {
      throw ArgumentError.value(
        lowStockItems,
        'lowStockItems',
        'Must be between zero and totalItems.',
      );
    }

    return InventoryReportModel(
      totalItems: totalItems,
      stockIn: stockIn,
      stockOut: stockOut,
      lowStockItems: lowStockItems,
    );
  }
}
