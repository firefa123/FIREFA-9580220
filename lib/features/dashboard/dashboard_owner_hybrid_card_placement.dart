class DashboardOwnerHybridCardPlacement {
  final List<String> sections = [
    'system_health_card',
    'sync_status_card',
    'conflict_alert_card',
    'owner_quick_actions',
  ];

  List<String> getPlacementOrder() {
    return sections;
  }

  bool shouldPreserveLegacyDashboard() {
    return true;
  }
}
