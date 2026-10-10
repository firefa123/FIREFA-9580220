// FIREFA Dashboard Responsive Optimization Layer
// Prepares adaptive layout rules for Hybrid Dashboard components.

class FirefaDashboardResponsiveOptimizationLayer {
  static const layouts = {
    'desktop': 'expanded_grid',
    'tablet': 'adaptive_grid',
    'mobile': 'stacked_cards',
  };

  static const protectedComponents = [
    'system_health_card',
    'sync_status_card',
    'conflict_alert_card',
    'owner_quick_actions',
  ];

  static String resolveLayout(String screenType) {
    return layouts[screenType] ?? 'adaptive_grid';
  }
}
