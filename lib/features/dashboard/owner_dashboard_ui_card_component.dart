// FIREFA Owner Dashboard UI Card Component
// Integration layer for Hybrid Dashboard cards.

class OwnerDashboardCardData {
  final String title;
  final String value;
  final String status;
  final String actionId;

  const OwnerDashboardCardData({
    required this.title,
    required this.value,
    required this.status,
    required this.actionId,
  });
}

class OwnerDashboardCards {
  static List<OwnerDashboardCardData> build({
    required String systemHealth,
    required int pendingSync,
    required int conflicts,
    required int failedTransactions,
  }) {
    return [
      OwnerDashboardCardData(
        title: 'System Health',
        value: systemHealth,
        status: systemHealth,
        actionId: 'open_system_health',
      ),
      OwnerDashboardCardData(
        title: 'Sync Status',
        value: '$pendingSync pending',
        status: pendingSync > 0 ? 'ATTENTION' : 'HEALTHY',
        actionId: 'open_sync_queue',
      ),
      OwnerDashboardCardData(
        title: 'Conflict Alert',
        value: '$conflicts conflict',
        status: conflicts > 0 ? 'REVIEW' : 'CLEAR',
        actionId: 'open_conflict_center',
      ),
      OwnerDashboardCardData(
        title: 'Failed Transaction',
        value: '$failedTransactions failed',
        status: failedTransactions > 0 ? 'ACTION' : 'CLEAR',
        actionId: 'open_retry_queue',
      ),
    ];
  }
}
