import 'inventory_dashboard_model.dart';

class InventoryDashboardController {
  InventoryDashboardModel summary() {
    return const InventoryDashboardModel(
      totalItems: 0,
      lowStockItems: 0,
      outOfStockItems: 0,
    );
  }
}
