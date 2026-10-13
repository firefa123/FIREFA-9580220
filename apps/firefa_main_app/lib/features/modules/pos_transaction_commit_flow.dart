/// Coordinates POS transaction completion with hybrid modules.
///
/// This layer keeps transaction orchestration separate from payment and
/// inventory services. It prepares a safe commit flow without directly
/// mutating existing POS data.
class FirefaPosTransactionCommitFlow {
  const FirefaPosTransactionCommitFlow();

  TransactionCommitPlan createPlan({
    required String orderId,
    required String paymentId,
    required List<String> inventoryMovementIds,
  }) {
    return TransactionCommitPlan(
      orderId: orderId,
      paymentId: paymentId,
      inventoryMovementIds: inventoryMovementIds,
      status: TransactionCommitStatus.ready,
    );
  }
}

class TransactionCommitPlan {
  final String orderId;
  final String paymentId;
  final List<String> inventoryMovementIds;
  final TransactionCommitStatus status;

  const TransactionCommitPlan({
    required this.orderId,
    required this.paymentId,
    required this.inventoryMovementIds,
    required this.status,
  });
}

enum TransactionCommitStatus {
  ready,
  committed,
  failed,
}
