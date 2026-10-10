class BackupRestoreDashboardIntegration {
  final int availableBackups;
  final DateTime? lastBackup;
  final bool restoreReady;

  const BackupRestoreDashboardIntegration({
    required this.availableBackups,
    required this.lastBackup,
    required this.restoreReady,
  });

  bool get needsAttention {
    return !restoreReady || availableBackups == 0;
  }

  String get status {
    if (needsAttention) {
      return 'ATTENTION_REQUIRED';
    }
    return 'BACKUP_HEALTHY';
  }
}
