/// FIREFA POS Owner Monitoring Integration
///
/// Provides monitoring data from POS hybrid flow for owner dashboard.
/// This layer is read-only and does not modify transaction data.

class PosOwnerMonitoringSnapshot {
  final int pendingSyncTransactions;
  final int failedTransactions;
  final int retryQueueCount;
  final DateTime generatedAt;

  const PosOwnerMonitoringSnapshot({
    required this.pendingSyncTransactions,
    required this.failedTransactions,
    required this.retryQueueCount,
    required this.generatedAt,
  });

  bool get hasAttentionRequired =>
      failedTransactions > 0 || retryQueueCount > 0;
}

class PosOwnerMonitoringIntegration {
  const PosOwnerMonitoringIntegration();

  PosOwnerMonitoringSnapshot buildSnapshot({
    required int pendingSync,
    required int failed,
    required int retryQueue,
  }) {
    return PosOwnerMonitoringSnapshot(
      pendingSyncTransactions: pendingSync,
      failedTransactions: failed,
      retryQueueCount: retryQueue,
      generatedAt: DateTime.now(),
    );
  }
}
