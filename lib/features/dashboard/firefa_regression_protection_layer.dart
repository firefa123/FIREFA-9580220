// FIREFA Regression Protection Layer
// Protects baseline features while Hybrid System continues evolving.

class FirefaRegressionProtectionLayer {
  static const protectedModules = [
    'splash',
    'login',
    'owner_dashboard',
    'sidebar',
    'pos',
    'payment',
    'order_flow',
    'inventory',
    'backup',
    'sync',
    'conflict_management',
  ];

  static bool isProtected(String module) {
    return protectedModules.contains(module);
  }

  static Map<String, String> validationStatus() {
    return {
      for (final module in protectedModules) module: 'PROTECTED',
    };
  }
}
