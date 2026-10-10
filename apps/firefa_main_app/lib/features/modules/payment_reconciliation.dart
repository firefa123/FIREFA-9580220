/// Hybrid payment reconciliation layer.
///
/// This module compares local and server payment states without directly
/// modifying transactions. Any mismatch is returned for conflict handling.
enum FirefaPaymentMatchStatus {
  matched,
  amountMismatch,
  statusMismatch,
  missingOnServer,
  duplicateDetected,
}

class FirefaPaymentReconciliationResult {
  final String paymentId;
  final FirefaPaymentMatchStatus status;
  final double localAmount;
  final double serverAmount;
  final DateTime checkedAt;

  const FirefaPaymentReconciliationResult({
    required this.paymentId,
    required this.status,
    required this.localAmount,
    required this.serverAmount,
    required this.checkedAt,
  });
}

class FirefaPaymentReconciliation {
  const FirefaPaymentReconciliation();

  FirefaPaymentReconciliationResult compare({
    required String paymentId,
    required double localAmount,
    required double serverAmount,
    required bool serverExists,
    required bool duplicate,
  }) {
    final status = duplicate
        ? FirefaPaymentMatchStatus.duplicateDetected
        : !serverExists
            ? FirefaPaymentMatchStatus.missingOnServer
            : localAmount != serverAmount
                ? FirefaPaymentMatchStatus.amountMismatch
                : FirefaPaymentMatchStatus.matched;

    return FirefaPaymentReconciliationResult(
      paymentId: paymentId,
      status: status,
      localAmount: localAmount,
      serverAmount: serverAmount,
      checkedAt: DateTime.now().toUtc(),
    );
  }
}
