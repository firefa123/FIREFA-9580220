// FIREFA Dashboard Interaction Visual Layer
// Provides UI interaction states for Hybrid Dashboard components.

class DashboardInteractionVisualState {
  final String component;
  final String state;

  const DashboardInteractionVisualState({
    required this.component,
    required this.state,
  });
}

class FirefaDashboardInteractionVisualLayer {
  static const states = [
    'normal',
    'hover',
    'pressed',
    'loading',
    'success',
    'warning',
    'error',
  ];

  static DashboardInteractionVisualState resolve(
    String component,
    String state,
  ) {
    return DashboardInteractionVisualState(
      component: component,
      state: states.contains(state) ? state : 'normal',
    );
  }
}
