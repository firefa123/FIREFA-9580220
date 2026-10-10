class ConflictDashboardAlertCard {
  final int pendingCount;

  ConflictDashboardAlertCard({this.pendingCount = 0});

  bool get hasAlert => pendingCount > 0;
}
