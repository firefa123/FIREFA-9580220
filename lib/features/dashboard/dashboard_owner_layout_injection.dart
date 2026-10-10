// FIREFA Owner Dashboard Layout Injection Layer
// Keeps existing dashboard layout intact while providing a safe
// integration point for Hybrid System cards.

class DashboardOwnerLayoutInjection {
  final bool keepExistingTheme;
  final bool keepExistingSidebar;
  final bool keepExistingNavigation;

  const DashboardOwnerLayoutInjection({
    this.keepExistingTheme = true,
    this.keepExistingSidebar = true,
    this.keepExistingNavigation = true,
  });

  List<String> get injectedSections => [
        'system_health_card',
        'sync_status_card',
        'conflict_alert_card',
        'owner_quick_actions',
      ];

  bool get isSafeInjection =>
      keepExistingTheme &&
      keepExistingSidebar &&
      keepExistingNavigation;
}
