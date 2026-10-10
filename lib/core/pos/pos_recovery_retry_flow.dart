class PosRecoveryRetryFlow {
  final String transactionId;
  final String status;
  final int retryCount;

  const PosRecoveryRetryFlow({
    required this.transactionId,
    required this.status,
    required this.retryCount,
  });

  bool get canRetry => status == 'FAILED' || status == 'PENDING';

  PosRecoveryRetryFlow retry() {
    return PosRecoveryRetryFlow(
      transactionId: transactionId,
      status: 'RETRY_QUEUED',
      retryCount: retryCount + 1,
    );
  }
}
