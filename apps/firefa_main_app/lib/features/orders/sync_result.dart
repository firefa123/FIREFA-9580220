class SyncResult {
  final bool success;
  final int syncedCount;
  final String message;

  const SyncResult({
    required this.success,
    required this.syncedCount,
    required this.message,
  });
}
