// FIREFA Dashboard Owner Runtime Card Update Layer
// Connects live hybrid data to dashboard cards.

class DashboardOwnerRuntimeCardUpdate {
  final int pendingSync;
  final int activeConflict;
  final int failedTransaction;
  final bool backupHealthy;

  DashboardOwnerRuntimeCardUpdate({
    required this.pendingSync,
    required this.activeConflict,
    required this.failedTransaction,
    required this.backupHealthy,
  });

  Map<String, dynamic> buildCardState() {
    return {
      'system_health': _healthStatus(),
      'sync_status': pendingSync,
      'conflict_alert': activeConflict,
      'failed_transaction': failedTransaction,
      'backup_health': backupHealthy,
    };
  }

  String _healthStatus() {
    if (failedTransaction > 0 || activeConflict > 0 || !backupHealthy) {
      return 'ATTENTION_REQUIRED';
    }

    return 'HEALTHY';
  }
}
