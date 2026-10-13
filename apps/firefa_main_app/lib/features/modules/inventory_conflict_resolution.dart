import 'inventory_hybrid_sync.dart';

/// Inventory conflict bridge. It creates a review state instead of silently
/// overwriting stock values when local and server quantities differ.
class FirefaInventoryConflictResolution {
  const FirefaInventoryConflictResolution();

  FirefaInventoryConflictDecision evaluate(
    FirefaInventorySyncRecord record,
  ) {
    if (record.localStock == record.serverStock) {
      return const FirefaInventoryConflictDecision(
        status: FirefaInventoryConflictStatus.resolved,
      );
    }

    return FirefaInventoryConflictDecision(
      status: FirefaInventoryConflictStatus.reviewRequired,
      reason:
          'Local stock ${record.localStock} differs from server stock ${record.serverStock}',
    );
  }
}

enum FirefaInventoryConflictStatus {
  resolved,
  reviewRequired,
}

class FirefaInventoryConflictDecision {
  final FirefaInventoryConflictStatus status;
  final String? reason;

  const FirefaInventoryConflictDecision({
    required this.status,
    this.reason,
  });
}
