// FIREFA Hybrid POS Atomic Transaction Guard
// Protects POS transaction consistency across order, payment, and inventory.

class PosAtomicTransactionGuard {
  bool canCommit({
    required bool orderReady,
    required bool paymentReady,
    required bool inventoryReady,
  }) {
    return orderReady && paymentReady && inventoryReady;
  }

  String resolveFailure({
    required bool paymentSuccess,
    required bool inventorySuccess,
  }) {
    if (!paymentSuccess) {
      return 'PAYMENT_FAILED_ORDER_PENDING';
    }

    if (!inventorySuccess) {
      return 'INVENTORY_PENDING_REVIEW';
    }

    return 'COMMITTED';
  }
}
