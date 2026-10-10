import '../models/payment_model.dart';
import '../models/transaction_model.dart';

class PaymentController {
  PaymentModel createPayment({
    required TransactionModel transaction,
    required PaymentMethod method,
  }) {
    return PaymentModel(
      id: _generatePaymentId(),
      transactionId: transaction.id,
      method: method,
      status: PaymentStatus.pending,
      amount: transaction.totalAmount,
      createdAt: DateTime.now(),
    );
  }

  PaymentModel markPaid(PaymentModel payment) {
    return payment.copyWith(status: PaymentStatus.paid);
  }

  PaymentModel markFailed(PaymentModel payment) {
    return payment.copyWith(status: PaymentStatus.failed);
  }

  String _generatePaymentId() {
    return 'PAY-${DateTime.now().millisecondsSinceEpoch}';
  }
}
