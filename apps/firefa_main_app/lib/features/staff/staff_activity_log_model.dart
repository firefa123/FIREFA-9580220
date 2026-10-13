class StaffActivityLog {
  final String staffId;
  final String action;
  final DateTime createdAt;

  const StaffActivityLog({
    required this.staffId,
    required this.action,
    required this.createdAt,
  });
}
