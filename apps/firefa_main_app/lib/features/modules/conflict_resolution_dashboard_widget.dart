class ConflictResolutionDashboardWidget {
  int pendingConflicts = 0;

  void updatePending(int count) {
    pendingConflicts = count;
  }

  bool get hasPending => pendingConflicts > 0;
}
