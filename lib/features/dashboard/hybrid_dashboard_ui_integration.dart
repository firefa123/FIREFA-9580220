// FIREFA Hybrid Dashboard UI Integration
// Connects Hybrid System Health data to the existing Owner Dashboard.

class HybridDashboardUIIntegration {
  final String systemStatus;
  final int pendingSync;
  final int conflictCount;
  final int failedTransactions;

  const HybridDashboardUIIntegration({
    required this.systemStatus,
    required this.pendingSync,
    required this.conflictCount,
    required this.failedTransactions,
  });

  bool get needsAttention =>
      conflictCount > 0 || failedTransactions > 0 || pendingSync > 0;

  Map<String, dynamic> get dashboardCardData => {
        'status': systemStatus,
        'pendingSync': pendingSync,
        'conflictCount': conflictCount,
        'failedTransactions': failedTransactions,
        'needsAttention': needsAttention,
      };
}
