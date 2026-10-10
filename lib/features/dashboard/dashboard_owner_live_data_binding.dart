// FIREFA Dashboard Owner Live Data Binding
// Connects Hybrid dashboard cards with runtime system state.

class DashboardOwnerLiveDataBinding {
  final int pendingSync;
  final int activeConflict;
  final int failedTransaction;
  final bool backupHealthy;

  const DashboardOwnerLiveDataBinding({
    required this.pendingSync,
    required this.activeConflict,
    required this.failedTransaction,
    required this.backupHealthy,
  });

  bool get needsAttention =>
      pendingSync > 0 ||
      activeConflict > 0 ||
      failedTransaction > 0 ||
      !backupHealthy;

  String get healthStatus {
    return needsAttention ? 'ATTENTION_REQUIRED' : 'HEALTHY';
  }
}
