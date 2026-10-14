import 'inventory_item_model.dart';

/// In-memory inventory catalog controller.
class InventoryController {
  final List<InventoryItem> _items = [];

  List<InventoryItem> get items => List.unmodifiable(_items);

  void addItem(InventoryItem item) {
    final normalized = _normalize(item);
    _validate(normalized);
    if (_items.any((existing) => existing.id == normalized.id)) {
      throw ArgumentError.value(normalized.id, 'item.id', 'Inventory item ID must be unique.');
    }
    _items.add(normalized);
  }

  bool updateItem(String id, InventoryItem item) {
    final normalizedId = id.trim();
    final index = _items.indexWhere((existing) => existing.id == normalizedId);
    if (index < 0) return false;

    final normalized = _normalize(item);
    _validate(normalized);
    if (_items.any((existing) =>
        existing.id == normalized.id && existing.id != normalizedId)) {
      throw ArgumentError.value(normalized.id, 'item.id', 'Inventory item ID must be unique.');
    }
    _items[index] = normalized;
    return true;
  }

  bool removeItem(String id) {
    final index = _items.indexWhere((item) => item.id == id.trim());
    if (index < 0) return false;
    _items.removeAt(index);
    return true;
  }

  InventoryItem? findById(String id) {
    final normalizedId = id.trim();
    for (final item in _items) {
      if (item.id == normalizedId) return item;
    }
    return null;
  }

  List<InventoryItem> search(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return items;
    return List.unmodifiable(_items.where((item) =>
        item.id.toLowerCase().contains(normalizedQuery) ||
        item.name.toLowerCase().contains(normalizedQuery) ||
        item.unit.toLowerCase().contains(normalizedQuery)));
  }

  List<InventoryItem> get lowStockItems =>
      List.unmodifiable(_items.where((item) => item.isLowStock));

  double get totalItems => _items.length.toDouble();

  InventoryItem _normalize(InventoryItem item) => InventoryItem(
        id: item.id.trim(),
        name: item.name.trim(),
        stock: item.stock,
        unit: item.unit.trim(),
      );

  void _validate(InventoryItem item) {
    if (item.id.isEmpty) {
      throw ArgumentError.value(item.id, 'item.id', 'Item ID cannot be empty.');
    }
    if (item.name.isEmpty) {
      throw ArgumentError.value(item.name, 'item.name', 'Item name cannot be empty.');
    }
    if (item.unit.isEmpty) {
      throw ArgumentError.value(item.unit, 'item.unit', 'Unit cannot be empty.');
    }
    if (!item.stock.isFinite || item.stock < 0) {
      throw ArgumentError.value(item.stock, 'item.stock', 'Stock must be finite and non-negative.');
    }
  }
}
