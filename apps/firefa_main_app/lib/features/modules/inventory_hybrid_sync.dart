enum FirefaInventorySyncStatus {
  localOnly,
  queued,
  syncing,
  synced,
  conflict,
  failed,
}

class FirefaInventorySyncRecord {
  final String itemId;
  final String itemName;
  final int localStock;
  final int serverStock;
  final FirefaInventorySyncStatus status;
  final DateTime updatedAt;

  const FirefaInventorySyncRecord({
    required this.itemId,
    required this.itemName,
    required this.localStock,
    required this.serverStock,
    required this.status,
    required this.updatedAt,
  });

  bool get hasStockDifference => localStock != serverStock;
}

/// Compatibility names used by dashboard and review modules.
typedef InventoryHybridSyncRecord = FirefaInventorySyncRecord;
typedef InventoryConflictRecord = FirefaInventorySyncRecord;

class FirefaInventoryReconciliation {
  const FirefaInventoryReconciliation();

  FirefaInventorySyncStatus evaluate({
    required int localStock,
    required int serverStock,
  }) {
    if (localStock == serverStock) {
      return FirefaInventorySyncStatus.synced;
    }
    return FirefaInventorySyncStatus.conflict;
  }
}
