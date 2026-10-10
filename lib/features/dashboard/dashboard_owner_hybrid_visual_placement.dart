// FIREFA Dashboard Owner Hybrid Visual Placement Layer
// Keeps baseline UI intact while defining final Hybrid card placement.

class DashboardOwnerHybridVisualPlacement {
  final String sectionTitle = 'FIREFA Hybrid Control Center';

  final List<String> cards = const [
    'System Health',
    'Sync Status',
    'Conflict Alert',
    'Owner Quick Actions',
  ];

  Map<String, dynamic> getPlacement() {
    return {
      'position': 'dashboard_secondary_section',
      'preserve_existing_widgets': true,
      'preserve_theme': true,
      'cards': cards,
    };
  }
}
