/// FIREFA Hybrid Owner Control Center
/// Aggregates owner visibility for POS, inventory, sync and backup health.

class HybridOwnerControlCenter {
  final int pendingTransactions;
  final int failedTransactions;
  final int inventoryConflicts;
  final bool backupAvailable;
  final String syncHealth;

  const HybridOwnerControlCenter({
    required this.pendingTransactions,
    required this.failedTransactions,
    required this.inventoryConflicts,
    required this.backupAvailable,
    required this.syncHealth,
  });

  bool get requiresAttention =>
      pendingTransactions > 0 ||
      failedTransactions > 0 ||
      inventoryConflicts > 0;

  Map<String, dynamic> toDashboardSummary() {
    return {
      'pendingTransactions': pendingTransactions,
      'failedTransactions': failedTransactions,
      'inventoryConflicts': inventoryConflicts,
      'backupAvailable': backupAvailable,
      'syncHealth': syncHealth,
      'requiresAttention': requiresAttention,
    };
  }
}
