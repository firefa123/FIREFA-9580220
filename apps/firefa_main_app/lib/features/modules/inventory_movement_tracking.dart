enum InventoryMovementType { stockIn, stockOut, adjustment }

enum InventoryMovementSyncStatus { localOnly, queued, syncing, synced, conflict, failed }

class FirefaInventoryMovement {
  final String movementId;
  final String itemId;
  final String itemName;
  final InventoryMovementType type;
  final int quantity;
  final InventoryMovementSyncStatus syncStatus;
  final DateTime createdAt;

  const FirefaInventoryMovement({
    required this.movementId,
    required this.itemId,
    required this.itemName,
    required this.type,
    required this.quantity,
    required this.syncStatus,
    required this.createdAt,
  });

  FirefaInventoryMovement copyWith({
    InventoryMovementSyncStatus? syncStatus,
  }) {
    return FirefaInventoryMovement(
      movementId: movementId,
      itemId: itemId,
      itemName: itemName,
      type: type,
      quantity: quantity,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt,
    );
  }
}
