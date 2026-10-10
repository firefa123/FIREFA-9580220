class StockMovement {
  final String id;
  final String itemId;
  final String type;
  final double quantity;
  final DateTime createdAt;

  const StockMovement({
    required this.id,
    required this.itemId,
    required this.type,
    required this.quantity,
    required this.createdAt,
  });
}
