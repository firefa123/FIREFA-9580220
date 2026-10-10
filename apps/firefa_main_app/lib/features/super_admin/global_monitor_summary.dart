class GlobalMonitorSummary {
  final int outlets;
  final int activeUsers;
  final int pendingSync;

  const GlobalMonitorSummary({
    required this.outlets,
    required this.activeUsers,
    required this.pendingSync,
  });
}
