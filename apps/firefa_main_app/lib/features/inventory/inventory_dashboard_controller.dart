import 'inventory_dashboard_model.dart';
import 'inventory_item_model.dart';

/// Builds inventory dashboard metrics from the current inventory snapshot.
class InventoryDashboardController {
  InventoryDashboardModel summary({List<InventoryItem> items = const []}) {
    var lowStock = 0;
    var outOfStock = 0;

    for (final item in items) {
      if (item.stock <= 0) {
        outOfStock++;
      } else if (item.isLowStock) {
        lowStock++;
      }
    }

    return InventoryDashboardModel(
      totalItems: items.length,
      lowStockItems: lowStock,
      outOfStockItems: outOfStock,
    );
  }
}
