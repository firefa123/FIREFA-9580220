import '../models/payment_model.dart';
import '../models/receipt_model.dart';
import '../models/transaction_model.dart';

/// Generates a local receipt after validating transaction/payment consistency.
///
/// This is a local receipt record, not a fiscal receipt or proof of settlement
/// from an external payment provider.
class ReceiptController {
  ReceiptModel generate({
    required TransactionModel transaction,
    required PaymentModel payment,
  }) {
    if (transaction.id.trim().isEmpty || payment.id.trim().isEmpty) {
      throw ArgumentError('Transaction and payment IDs cannot be empty.');
    }
    if (transaction.status != TransactionStatus.paid &&
        transaction.status != TransactionStatus.completed) {
      throw StateError('Receipt requires a paid or completed transaction.');
    }
    if (payment.status != PaymentStatus.paid) {
      throw StateError('Receipt can only be generated for paid payments.');
    }
    if (payment.transactionId.trim() != transaction.id.trim()) {
      throw ArgumentError('Payment does not belong to this transaction.');
    }
    if (!transaction.totalAmount.isFinite ||
        transaction.totalAmount < 0 ||
        !payment.amount.isFinite ||
        payment.amount < 0) {
      throw ArgumentError('Transaction and payment amounts must be valid.');
    }
    if (payment.amount != transaction.totalAmount) {
      throw ArgumentError('Payment amount does not match transaction total.');
    }

    return ReceiptModel(
      transactionId: transaction.id.trim(),
      paymentId: payment.id.trim(),
      issuedAt: DateTime.now(),
      totalAmount: transaction.totalAmount,
      paymentMethod: payment.method.name,
    );
  }
}
