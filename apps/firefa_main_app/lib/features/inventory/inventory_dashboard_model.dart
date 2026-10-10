class InventoryDashboardModel {
  final int totalItems;
  final int lowStockItems;
  final int outOfStockItems;

  const InventoryDashboardModel({
    required this.totalItems,
    required this.lowStockItems,
    required this.outOfStockItems,
  });
}
