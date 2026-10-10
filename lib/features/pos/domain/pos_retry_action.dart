class PosRetryAction {
  final String transactionId;
  final bool canRetry;
  final int retryCount;

  const PosRetryAction({
    required this.transactionId,
    required this.canRetry,
    required this.retryCount,
  });

  bool execute() {
    if (!canRetry) {
      return false;
    }
    return true;
  }
}
