/// FIREFA Hybrid System Final Aggregator
///
/// Central layer to combine operational health signals from:
/// - POS
/// - Payment
/// - Inventory
/// - Sync
/// - Backup
/// - Conflict Management
///
/// This layer is read-only and intended for dashboard monitoring.

class HybridSystemHealth {
  final int posIssues;
  final int paymentIssues;
  final int inventoryConflicts;
  final int pendingSync;
  final int backupWarnings;

  const HybridSystemHealth({
    this.posIssues = 0,
    this.paymentIssues = 0,
    this.inventoryConflicts = 0,
    this.pendingSync = 0,
    this.backupWarnings = 0,
  });

  bool get needsAttention =>
      posIssues > 0 ||
      paymentIssues > 0 ||
      inventoryConflicts > 0 ||
      pendingSync > 0 ||
      backupWarnings > 0;

  String get healthStatus {
    if (needsAttention) {
      return 'ATTENTION_REQUIRED';
    }

    return 'HEALTHY';
  }
}

class HybridSystemFinalAggregator {
  static HybridSystemHealth aggregate({
    int posIssues = 0,
    int paymentIssues = 0,
    int inventoryConflicts = 0,
    int pendingSync = 0,
    int backupWarnings = 0,
  }) {
    return HybridSystemHealth(
      posIssues: posIssues,
      paymentIssues: paymentIssues,
      inventoryConflicts: inventoryConflicts,
      pendingSync: pendingSync,
      backupWarnings: backupWarnings,
    );
  }
}
