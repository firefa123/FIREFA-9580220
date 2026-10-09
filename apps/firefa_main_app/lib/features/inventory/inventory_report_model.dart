class InventoryReportModel {
  final int totalItems;
  final int stockIn;
  final int stockOut;
  final int lowStockItems;

  const InventoryReportModel({
    required this.totalItems,
    required this.stockIn,
    required this.stockOut,
    required this.lowStockItems,
  });
}
