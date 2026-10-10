// FIREFA Hybrid System
// POS Outbox Sync Integration

class PosOutboxSyncIntegration {
  final String transactionId;
  final String syncStatus;
  final bool idempotencyChecked;

  const PosOutboxSyncIntegration({
    required this.transactionId,
    required this.syncStatus,
    required this.idempotencyChecked,
  });

  bool canSync() {
    return idempotencyChecked && syncStatus != 'COMPLETED';
  }

  String queueStatus() {
    if (canSync()) {
      return 'QUEUED_FOR_SYNC';
    }
    return 'SKIPPED';
  }
}
