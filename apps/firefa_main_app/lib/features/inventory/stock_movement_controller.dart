import 'stock_movement_model.dart';

/// In-memory stock movement history.
class StockMovementController {
  final List<StockMovement> _movements = [];

  List<StockMovement> get movements => List.unmodifiable(_movements);
  List<StockMovement> get history => movements;

  void addMovement(StockMovement movement) {
    final normalized = StockMovement(
      id: movement.id.trim(),
      itemId: movement.itemId.trim(),
      type: movement.type.trim().toLowerCase(),
      quantity: movement.quantity,
      createdAt: movement.createdAt,
    );
    _validate(normalized);
    if (_movements.any((entry) => entry.id == normalized.id)) {
      throw ArgumentError.value(normalized.id, 'movement.id', 'Movement ID must be unique.');
    }
    _movements.add(normalized);
  }

  StockMovement? findById(String id) {
    final normalized = id.trim();
    for (final movement in _movements) {
      if (movement.id == normalized) return movement;
    }
    return null;
  }

  List<StockMovement> historyForItem(String itemId) {
    final normalized = itemId.trim();
    return List.unmodifiable(_movements.where((movement) => movement.itemId == normalized));
  }

  List<StockMovement> historyForType(String type) {
    final normalized = type.trim().toLowerCase();
    return List.unmodifiable(_movements.where((movement) => movement.type == normalized));
  }

  double totalQuantityForItem(String itemId, {required String type}) {
    return historyForItem(itemId)
        .where((movement) => movement.type == type.trim().toLowerCase())
        .fold<double>(0, (total, movement) => total + movement.quantity);
  }

  void _validate(StockMovement movement) {
    if (movement.id.isEmpty) {
      throw ArgumentError.value(movement.id, 'movement.id', 'Movement ID cannot be empty.');
    }
    if (movement.itemId.isEmpty) {
      throw ArgumentError.value(movement.itemId, 'movement.itemId', 'Item ID cannot be empty.');
    }
    if (movement.type.isEmpty) {
      throw ArgumentError.value(movement.type, 'movement.type', 'Movement type cannot be empty.');
    }
    if (!movement.quantity.isFinite || movement.quantity <= 0) {
      throw ArgumentError.value(movement.quantity, 'movement.quantity', 'Quantity must be finite and greater than zero.');
    }
  }
}
