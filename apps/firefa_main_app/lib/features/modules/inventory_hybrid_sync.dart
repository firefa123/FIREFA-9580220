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

typedef InventoryHybridSyncRecord = FirefaInventorySyncRecord;
typedef InventoryConflictRecord = FirefaInventorySyncRecord;

/// Immutable movement request. [eventId] must be reused for every retry of
/// the same logical change; generating a new ID on retry defeats idempotency.
class FirefaInventoryMovementRequest {
  final String eventId;
  final String outletId;
  final String itemId;
  final int expectedStock;
  final int quantityDelta;
  final String movementType;
  final DateTime createdAt;

  const FirefaInventoryMovementRequest({
    required this.eventId,
    required this.outletId,
    required this.itemId,
    required this.expectedStock,
    required this.quantityDelta,
    required this.movementType,
    required this.createdAt,
  });

  int get resultingStock => expectedStock + quantityDelta;

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'outletId': outletId,
        'itemId': itemId,
        'expectedStock': expectedStock,
        'quantityDelta': quantityDelta,
        'movementType': movementType,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  void validate() {
    if (eventId.trim().isEmpty ||
        outletId.trim().isEmpty ||
        itemId.trim().isEmpty ||
        expectedStock < 0 ||
        quantityDelta == 0 ||
        resultingStock < 0 ||
        resultingStock > 999999999 ||
        !const {'in', 'out', 'adjustment'}.contains(movementType)) {
      throw const FormatException('Permintaan pergerakan stok tidak valid.');
    }
    if ((movementType == 'in' && quantityDelta < 0) ||
        (movementType == 'out' && quantityDelta > 0)) {
      throw const FormatException(
        'Arah pergerakan stok tidak sesuai dengan kuantitas.',
      );
    }
  }
}

/// The client accepts an acknowledgement only when it identifies the exact
/// event and item sent. HTTP success alone is not proof that stock was applied.
class FirefaInventoryMovementAcknowledgement {
  final String eventId;
  final String outletId;
  final String itemId;
  final int previousStock;
  final int currentStock;
  final bool duplicate;

  const FirefaInventoryMovementAcknowledgement({
    required this.eventId,
    required this.outletId,
    required this.itemId,
    required this.previousStock,
    required this.currentStock,
    required this.duplicate,
  });

  factory FirefaInventoryMovementAcknowledgement.fromJson(
    Map<String, dynamic> json,
  ) {
    final value = FirefaInventoryMovementAcknowledgement(
      eventId: json['eventId'] as String,
      outletId: json['outletId'] as String,
      itemId: json['itemId'] as String,
      previousStock: json['previousStock'] as int,
      currentStock: json['currentStock'] as int,
      duplicate: json['duplicate'] as bool,
    );
    if (value.eventId.trim().isEmpty ||
        value.outletId.trim().isEmpty ||
        value.itemId.trim().isEmpty ||
        value.previousStock < 0 ||
        value.currentStock < 0 ||
        value.currentStock > 999999999) {
      throw const FormatException('Respons sinkronisasi stok tidak valid.');
    }
    return value;
  }

  void validateFor(FirefaInventoryMovementRequest request) {
    request.validate();
    if (eventId != request.eventId ||
        outletId != request.outletId ||
        itemId != request.itemId ||
        previousStock != request.expectedStock ||
        currentStock != request.resultingStock) {
      throw const FormatException(
        'Respons server tidak cocok dengan perubahan stok yang dikirim.',
      );
    }
  }
}

class FirefaInventoryReconciliationResult {
  final int matched;
  final List<String> conflictingItemIds;

  FirefaInventoryReconciliationResult({
    required this.matched,
    required List<String> conflictingItemIds,
  }) : conflictingItemIds = List.unmodifiable(conflictingItemIds);

  bool get isReconciled => conflictingItemIds.isEmpty;
}

class FirefaInventoryReconciliation {
  const FirefaInventoryReconciliation();

  FirefaInventorySyncStatus evaluate({
    required int localStock,
    required int serverStock,
  }) {
    if (localStock < 0 || serverStock < 0) {
      return FirefaInventorySyncStatus.conflict;
    }
    return localStock == serverStock
        ? FirefaInventorySyncStatus.synced
        : FirefaInventorySyncStatus.conflict;
  }

  /// Compares only items present in both snapshots. Missing items are conflicts,
  /// never silently treated as zero. Duplicate IDs make the snapshot ambiguous.
  FirefaInventoryReconciliationResult reconcile({
    required Map<String, int> localStockByItem,
    required Map<String, int> serverStockByItem,
  }) {
    if (localStockByItem.keys.any((id) => id.trim().isEmpty) ||
        serverStockByItem.keys.any((id) => id.trim().isEmpty) ||
        localStockByItem.values.any((stock) => stock < 0) ||
        serverStockByItem.values.any((stock) => stock < 0)) {
      throw const FormatException('Snapshot stok tidak valid.');
    }

    final allIds = <String>{
      ...localStockByItem.keys,
      ...serverStockByItem.keys,
    };
    final conflicts = <String>[];
    var matched = 0;
    for (final id in allIds) {
      final local = localStockByItem[id];
      final server = serverStockByItem[id];
      if (local == null || server == null || local != server) {
        conflicts.add(id);
      } else {
        matched++;
      }
    }
    conflicts.sort();
    return FirefaInventoryReconciliationResult(
      matched: matched,
      conflictingItemIds: conflicts,
    );
  }
}
