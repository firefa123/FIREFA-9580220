class InventoryAnalyticsModel {
  final int totalItems;
  final int lowStockItems;
  final int outOfStockItems;

  const InventoryAnalyticsModel({
    required this.totalItems,
    required this.lowStockItems,
    required this.outOfStockItems,
  });
}
