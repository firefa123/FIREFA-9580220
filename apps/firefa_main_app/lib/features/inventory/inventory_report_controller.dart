import 'inventory_report_model.dart';

class InventoryReportController {
  InventoryReportModel generate({
    required int totalItems,
    required int stockIn,
    required int stockOut,
    required int lowStockItems,
  }) {
    return InventoryReportModel(
      totalItems: totalItems,
      stockIn: stockIn,
      stockOut: stockOut,
      lowStockItems: lowStockItems,
    );
  }
}
