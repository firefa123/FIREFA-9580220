import '../models/payment_model.dart';
import '../models/transaction_model.dart';

/// Creates and transitions local payment records.
///
/// This controller simulates payment state locally; it does not capture funds
/// or verify payment with a bank, QRIS provider, or payment gateway.
class PaymentController {
  PaymentModel createPayment({
    required TransactionModel transaction,
    required PaymentMethod method,
  }) {
    final transactionId = transaction.id.trim();
    if (transactionId.isEmpty) {
      throw ArgumentError.value(
        transaction.id,
        'transaction.id',
        'Transaction ID cannot be empty.',
      );
    }
    if (!transaction.totalAmount.isFinite || transaction.totalAmount <= 0) {
      throw ArgumentError.value(
        transaction.totalAmount,
        'transaction.totalAmount',
        'Payment amount must be finite and positive.',
      );
    }
    if (transaction.status == TransactionStatus.cancelled) {
      throw StateError('Cannot create a payment for a cancelled transaction.');
    }

    return PaymentModel(
      id: _generatePaymentId(),
      transactionId: transactionId,
      method: method,
      status: PaymentStatus.pending,
      amount: transaction.totalAmount,
      createdAt: DateTime.now(),
    );
  }

  PaymentModel markPaid(PaymentModel payment) {
    if (payment.status == PaymentStatus.paid) {
      return payment.verificationStatus == PaymentVerificationStatus.notReported
          ? payment.copyWith(verificationStatus: PaymentVerificationStatus.reported)
          : payment;
    }
    if (payment.status != PaymentStatus.pending) {
      throw StateError('Only pending payments can be marked as paid.');
    }
    return payment.copyWith(
      status: PaymentStatus.paid,
      verificationStatus: PaymentVerificationStatus.reported,
      verifiedAt: null,
      verifiedBy: null,
    );
  }

  PaymentModel markVerified(
    PaymentModel payment, {
    String? verifiedBy,
    DateTime? verifiedAt,
  }) {
    if (payment.verificationStatus == PaymentVerificationStatus.verified) return payment;
    if (payment.status != PaymentStatus.paid ||
        payment.verificationStatus != PaymentVerificationStatus.reported) {
      throw StateError('Only reported paid payments can be verified.');
    }
    return payment.copyWith(
      verificationStatus: PaymentVerificationStatus.verified,
      verifiedAt: verifiedAt ?? DateTime.now(),
      verifiedBy: verifiedBy,
    );
  }

  PaymentModel markFailed(PaymentModel payment) {
    if (payment.status == PaymentStatus.failed) return payment;
    if (payment.status != PaymentStatus.pending) {
      throw StateError('Only pending payments can be marked as failed.');
    }
    return payment.copyWith(
      status: PaymentStatus.failed,
      verificationStatus: PaymentVerificationStatus.failed,
    );
  }

  String _generatePaymentId() {
    return 'PAY-${DateTime.now().microsecondsSinceEpoch}';
  }
}
