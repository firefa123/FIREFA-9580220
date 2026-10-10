class OwnerDashboardQuickAction {
  final String id;
  final String title;
  final String description;
  final String action;

  const OwnerDashboardQuickAction({
    required this.id,
    required this.title,
    required this.description,
    required this.action,
  });
}

class OwnerDashboardQuickActions {
  static const List<OwnerDashboardQuickAction> actions = [
    OwnerDashboardQuickAction(
      id: 'retry_sync',
      title: 'Retry Sync',
      description: 'Retry pending hybrid synchronization queue',
      action: 'SYNC_RETRY',
    ),
    OwnerDashboardQuickAction(
      id: 'review_conflict',
      title: 'Review Conflict',
      description: 'Open unresolved inventory or transaction conflicts',
      action: 'CONFLICT_REVIEW',
    ),
    OwnerDashboardQuickAction(
      id: 'backup_restore',
      title: 'Backup Restore',
      description: 'Check backup availability and restore readiness',
      action: 'BACKUP_RESTORE',
    ),
    OwnerDashboardQuickAction(
      id: 'refresh_health',
      title: 'Refresh Health',
      description: 'Refresh FIREFA hybrid system status',
      action: 'HEALTH_REFRESH',
    ),
  ];
}
