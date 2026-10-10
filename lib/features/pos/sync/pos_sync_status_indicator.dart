class PosSyncStatusIndicator {
  final String transactionId;
  final String status;
  final bool canRetry;

  const PosSyncStatusIndicator({
    required this.transactionId,
    required this.status,
    this.canRetry = false,
  });

  String get label {
    switch (status) {
      case 'SYNCED':
        return 'Synced';
      case 'SYNCING':
        return 'Syncing';
      case 'FAILED':
        return 'Failed';
      case 'PENDING':
        return 'Pending Sync';
      default:
        return 'Offline';
    }
  }
}
