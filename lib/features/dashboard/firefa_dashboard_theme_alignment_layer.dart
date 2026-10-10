// FIREFA Dashboard Theme Alignment Layer
// Keeps the original FIREFA visual identity while preparing Hybrid System cards.

class FirefaDashboardThemeAlignment {
  final String themeName = 'FIREFA';

  final Map<String, dynamic> cardStyle = {
    'radius': 'consistent',
    'spacing': 'aligned',
    'typography': 'firefa',
    'hierarchy': 'owner_dashboard',
  };

  final List<String> hybridComponents = [
    'system_health_card',
    'sync_status_card',
    'conflict_alert_card',
    'owner_quick_actions',
  ];

  bool preserveLegacyTheme() => true;
}
