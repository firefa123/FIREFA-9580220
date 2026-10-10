// FIREFA Owner Dashboard Existing UI Connector
// Connects Hybrid dashboard components with existing owner dashboard safely.

class OwnerDashboardExistingUIConnector {
  final String healthCard;
  final String syncCard;
  final String conflictCard;
  final String actionCenter;

  OwnerDashboardExistingUIConnector({
    required this.healthCard,
    required this.syncCard,
    required this.conflictCard,
    required this.actionCenter,
  });

  Map<String, dynamic> buildDashboardExtension() {
    return {
      'health': healthCard,
      'sync': syncCard,
      'conflict': conflictCard,
      'actions': actionCenter,
      'preserveExistingTheme': true,
    };
  }
}
