import 'inventory_analytics_model.dart';

class InventoryAnalyticsController {
  InventoryAnalyticsModel getSummary() {
    return const InventoryAnalyticsModel(
      totalItems: 0,
      lowStockItems: 0,
      outOfStockItems: 0,
    );
  }
}
