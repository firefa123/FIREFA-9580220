// FIREFA Dashboard Owner Hybrid Rendering Layer
// Provides rendering configuration for Hybrid Control Center components.

class DashboardOwnerHybridRenderingLayer {
  final bool enabled;
  final List<String> components;

  const DashboardOwnerHybridRenderingLayer({
    required this.enabled,
    required this.components,
  });

  factory DashboardOwnerHybridRenderingLayer.defaultConfig() {
    return const DashboardOwnerHybridRenderingLayer(
      enabled: true,
      components: [
        'system_health_card',
        'sync_status_card',
        'conflict_alert_card',
        'owner_quick_actions',
      ],
    );
  }
}
