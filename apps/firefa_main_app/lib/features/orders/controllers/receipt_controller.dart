import '../models/payment_model.dart';
import '../models/receipt_model.dart';
import '../models/transaction_model.dart';

class ReceiptController {
  ReceiptModel generate({
    required TransactionModel transaction,
    required PaymentModel payment,
  }) {
    if (transaction.id.trim().isEmpty ||
        payment.id.trim().isEmpty ||
        payment.transactionId != transaction.id) {
      throw ArgumentError('Identitas transaksi dan pembayaran tidak cocok.');
    }
    if (transaction.status != TransactionStatus.paid &&
        transaction.status != TransactionStatus.completed) {
      throw StateError('Receipt requires a paid transaction.');
    }
    if (payment.status != PaymentStatus.paid) {
      throw StateError('Receipt can only be generated for paid payments.');
    }
    if (!transaction.totalAmount.isFinite ||
        transaction.totalAmount < 0 ||
        !payment.amount.isFinite ||
        payment.amount < 0 ||
        payment.amount != transaction.totalAmount) {
      throw StateError('Transaction and payment amounts do not match.');
    }

    return ReceiptModel(
      transactionId: transaction.id,
      paymentId: payment.id,
      issuedAt: DateTime.now(),
      totalAmount: transaction.totalAmount,
      paymentMethod: payment.method.name,
    );
  }
}
