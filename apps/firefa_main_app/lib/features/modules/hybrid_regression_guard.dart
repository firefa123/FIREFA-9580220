/// Regression protection rules for FIREFA hybrid modules.
///
/// This guard documents protected domains that must remain stable while
/// extending offline sync and conflict management capabilities.
class FirefaHybridRegressionGuard {
  static const protectedFlows = <String>[
    'splash_welcome',
    'login',
    'owner_dashboard',
    'sidebar_navigation',
    'pos_transaction',
    'payment_flow',
    'order_flow',
    'table_management',
    'menu_management',
    'inventory_management',
    'settings',
  ];

  static const hybridFlows = <String>[
    'offline_storage',
    'outbox_queue',
    'backup_restore',
    'conflict_management',
    'sync_health_monitoring',
  ];

  static bool isProtected(String flow) =>
      protectedFlows.contains(flow);

  static bool requiresRegressionCheck(String flow) =>
      protectedFlows.contains(flow) || hybridFlows.contains(flow);
}
