// FIREFA Dashboard Final UI Merge Layer
// Keeps existing baseline dashboard UI intact while preparing Hybrid section injection.

class FirefaDashboardFinalUiMerge {
  final bool preserveExistingTheme;
  final bool preserveSidebar;
  final bool preserveNavigation;

  const FirefaDashboardFinalUiMerge({
    this.preserveExistingTheme = true,
    this.preserveSidebar = true,
    this.preserveNavigation = true,
  });

  bool canMergeHybridSection() {
    return preserveExistingTheme &&
        preserveSidebar &&
        preserveNavigation;
  }

  Map<String, dynamic> buildHybridSectionConfig() {
    return {
      'systemHealth': true,
      'syncStatus': true,
      'conflictAlert': true,
      'quickActions': true,
    };
  }
}
