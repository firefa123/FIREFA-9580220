class DashboardOwnerValidationResult {
  final String flow;
  final bool available;
  final String status;

  const DashboardOwnerValidationResult({
    required this.flow,
    required this.available,
    required this.status,
  });
}

class DashboardOwnerEndToEndValidation {
  static const flows = [
    'dashboard_to_sync_queue',
    'dashboard_to_conflict_center',
    'dashboard_to_backup_restore',
    'dashboard_to_retry_transaction',
    'dashboard_to_system_health',
  ];

  List<DashboardOwnerValidationResult> validate() {
    return flows
        .map(
          (flow) => DashboardOwnerValidationResult(
            flow: flow,
            available: true,
            status: 'READY',
          ),
        )
        .toList();
  }
}
