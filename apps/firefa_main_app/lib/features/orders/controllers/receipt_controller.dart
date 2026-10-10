import '../models/payment_model.dart';
import '../models/receipt_model.dart';
import '../models/transaction_model.dart';

class ReceiptController {
  ReceiptModel generate({
    required TransactionModel transaction,
    required PaymentModel payment,
  }) {
    if (payment.status != PaymentStatus.paid) {
      throw StateError('Receipt can only be generated for paid transactions.');
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
