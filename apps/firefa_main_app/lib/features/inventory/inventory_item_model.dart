class InventoryItem {
  final String id;
  final String name;
  final double stock;
  final String unit;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.stock,
    required this.unit,
  });

  bool get isLowStock => stock <= 5;
}
