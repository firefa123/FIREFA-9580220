/// Hybrid payment protection layer.
/// Keeps payment decisions safe when devices work offline.
/// This layer only validates state and does not charge or refund automatically.
enum FirefaPaymentSyncStatus {
  localPending,
  queued,
  syncing,
  completed,
  conflict,
  failed,
}

class FirefaPaymentSyncGuard {
  const FirefaPaymentSyncGuard();

  bool canRetry(FirefaPaymentSyncStatus status) {
    return status == FirefaPaymentSyncStatus.failed ||
        status == FirefaPaymentSyncStatus.queued;
  }

  bool requiresReview(FirefaPaymentSyncStatus status) {
    return status == FirefaPaymentSyncStatus.conflict;
  }

  bool preventDuplicateSubmission({
    required String paymentId,
    required Set<String> processedPaymentIds,
  }) {
    return processedPaymentIds.contains(paymentId);
  }
}
