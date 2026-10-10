class OwnerActionCenter {
  final bool hasPendingSync;
  final bool hasInventoryConflict;
  final bool hasBackupWarning;

  const OwnerActionCenter({
    this.hasPendingSync = false,
    this.hasInventoryConflict = false,
    this.hasBackupWarning = false,
  });

  bool get requiresAttention =>
      hasPendingSync || hasInventoryConflict || hasBackupWarning;

  List<String> get availableActions {
    final actions = <String>[];

    if (hasPendingSync) {
      actions.add('RETRY_SYNC_QUEUE');
    }

    if (hasInventoryConflict) {
      actions.add('OPEN_INVENTORY_CONFLICT');
    }

    if (hasBackupWarning) {
      actions.add('CHECK_BACKUP_STATUS');
    }

    return actions;
  }
}
