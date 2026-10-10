// FIREFA Hybrid Sync Health Dashboard Module
// Provides monitoring data for owner dashboard.

class SyncHealthDashboardModule {
  final int pendingQueue;
  final int failedSync;
  final String lastSuccessfulSync;
  final String connectionStatus;
  final String lastError;

  const SyncHealthDashboardModule({
    required this.pendingQueue,
    required this.failedSync,
    required this.lastSuccessfulSync,
    required this.connectionStatus,
    required this.lastError,
  });

  bool get needsAttention => failedSync > 0 || connectionStatus != 'ONLINE';

  Map<String, dynamic> toDashboardData() {
    return {
      'pendingQueue': pendingQueue,
      'failedSync': failedSync,
      'lastSuccessfulSync': lastSuccessfulSync,
      'connectionStatus': connectionStatus,
      'lastError': lastError,
      'needsAttention': needsAttention,
    };
  }
}
