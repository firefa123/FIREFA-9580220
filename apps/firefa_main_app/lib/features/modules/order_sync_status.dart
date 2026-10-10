enum FirefaOrderSyncStatus {
  localOnly,
  queued,
  syncing,
  synced,
  conflict,
  failed,
}

/// Shared order synchronization state model.
/// Keeps POS/order modules aware of hybrid sync without forcing network logic
/// into the UI layer.
class FirefaOrderSyncState {
  final String orderId;
  final FirefaOrderSyncStatus status;
  final DateTime updatedAt;
  final String? message;

  const FirefaOrderSyncState({
    required this.orderId,
    required this.status,
    required this.updatedAt,
    this.message,
  });

  bool get requiresAttention =>
      status == FirefaOrderSyncStatus.conflict ||
      status == FirefaOrderSyncStatus.failed;
}
