// FIREFA Final UI Refinement Preparation
// Keeps the original baseline UI structure protected while preparing
// Hybrid System visual refinement.

class FirefaFinalUIRefinementPreparation {
  static const protectedComponents = [
    'splash',
    'login',
    'firefa_theme',
    'owner_dashboard',
    'sidebar',
    'pos',
    'payment_flow',
    'order_flow',
    'inventory',
    'settings',
  ];

  static const refinementTargets = [
    'hybrid_control_center_spacing',
    'dashboard_card_consistency',
    'theme_alignment',
    'responsive_layout',
  ];

  bool isBaselineProtected(String component) {
    return protectedComponents.contains(component);
  }
}
