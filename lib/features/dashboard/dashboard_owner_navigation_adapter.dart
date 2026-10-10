// Dashboard Owner Navigation Adapter
// Connects hybrid dashboard actions with existing FIREFA navigation.

class DashboardOwnerNavigationAdapter {
  final Map<String, String> routes = {
    'open_system_health': '/owner/system-health',
    'open_sync_queue': '/owner/sync-queue',
    'open_conflict_center': '/owner/conflict-center',
    'open_backup_restore': '/owner/backup-restore',
    'open_retry_queue': '/owner/retry-queue',
  };

  String? resolve(String actionId) {
    return routes[actionId];
  }

  bool canNavigate(String actionId) {
    return routes.containsKey(actionId);
  }
}
