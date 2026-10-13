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
    String? localStatus,
    String? serverStatus,
  }) {
    if (paymentId.trim().isEmpty) {
      throw ArgumentError.value(paymentId, 'paymentId', 'Tidak boleh kosong');
    }
    if (!localAmount.isFinite || !serverAmount.isFinite ||
        localAmount < 0 || serverAmount < 0) {
      throw ArgumentError('Nominal pembayaran harus finite dan tidak negatif.');
    }

    final status = duplicate
        ? FirefaPaymentMatchStatus.duplicateDetected
        : !serverExists
            ? FirefaPaymentMatchStatus.missingOnServer
            : localStatus != null &&
                    serverStatus != null &&
                    localStatus != serverStatus
                ? FirefaPaymentMatchStatus.statusMismatch
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
