class DashboardOwnerRealServiceConnector {
  final int pendingSync;
  final int activeConflict;
  final int failedTransaction;
  final bool backupHealthy;

  const DashboardOwnerRealServiceConnector({
    required this.pendingSync,
    required this.activeConflict,
    required this.failedTransaction,
    required this.backupHealthy,
  });

  Map<String, dynamic> getDashboardStatus() {
    return {
      'pendingSync': pendingSync,
      'activeConflict': activeConflict,
      'failedTransaction': failedTransaction,
      'backupHealthy': backupHealthy,
      'healthStatus': _calculateHealth(),
    };
  }

  String _calculateHealth() {
    if (failedTransaction > 0 || activeConflict > 0 || !backupHealthy) {
      return 'ATTENTION_REQUIRED';
    }

    return 'HEALTHY';
  }
}
