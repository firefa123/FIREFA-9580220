import '../modules/inventory_store.dart';
import 'inventory_analytics_model.dart';

/// Summarizes inventory items for the outlet selected by the caller.
class InventoryAnalyticsController {
  InventoryAnalyticsController({required List<FirefaInventoryItem> items})
      : _items = List.unmodifiable(items);

  final List<FirefaInventoryItem> _items;

  InventoryAnalyticsModel getSummary() {
    return InventoryAnalyticsModel(
      totalItems: _items.length,
      lowStockItems: _items.where((item) => item.isLowStock).length,
      outOfStockItems: _items.where((item) => item.isOutOfStock).length,
    );
  }
}
