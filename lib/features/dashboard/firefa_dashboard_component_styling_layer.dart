class FirefaDashboardComponentStylingLayer {
  const FirefaDashboardComponentStylingLayer();

  Map<String, dynamic> get componentStyle => {
        'cards': {
          'radius': 'firefa_standard',
          'spacing': 'dashboard_consistent',
          'hierarchy': 'clear',
        },
        'components': [
          'system_health_card',
          'sync_status_card',
          'conflict_alert_card',
          'owner_quick_actions',
        ],
      };
}
