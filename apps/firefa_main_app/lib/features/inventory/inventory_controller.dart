import 'inventory_item_model.dart';

class InventoryController {
  final List<InventoryItem> items = [];

  void addItem(InventoryItem item) {
    items.add(item);
  }

  List<InventoryItem> get lowStockItems {
    return items.where((item) => item.isLowStock).toList();
  }

  double get totalItems {
    return items.length.toDouble();
  }
}
