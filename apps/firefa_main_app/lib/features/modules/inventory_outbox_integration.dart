/// Bridge between inventory movement and hybrid outbox sync.
/// Keeps stock changes durable before network synchronization.

class InventoryOutboxEvent {
  final String movementId;
  final String itemId;
  final double quantity;
  final String action;
  final DateTime createdAt;

  const InventoryOutboxEvent({
    required this.movementId,
    required this.itemId,
    required this.quantity,
    required this.action,
    required this.createdAt,
  });
}

class InventoryOutboxIntegration {
  const InventoryOutboxIntegration();

  InventoryOutboxEvent createEvent({
    required String movementId,
    required String itemId,
    required double quantity,
    required String action,
  }) {
    return InventoryOutboxEvent(
      movementId: movementId,
      itemId: itemId,
      quantity: quantity,
      action: action,
      createdAt: DateTime.now().toUtc(),
    );
  }
}
