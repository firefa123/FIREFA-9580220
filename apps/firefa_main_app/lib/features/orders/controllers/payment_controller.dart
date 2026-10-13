import 'dart:math';

import '../models/payment_model.dart';
import '../models/transaction_model.dart';

class PaymentController {
  final Random _random = Random.secure();

  PaymentModel createPayment({
    required TransactionModel transaction,
    required PaymentMethod method,
  }) {
    if (transaction.id.trim().isEmpty ||
        transaction.status != TransactionStatus.awaitingPayment ||
        !transaction.totalAmount.isFinite ||
        transaction.totalAmount < 0) {
      throw ArgumentError('Transaksi tidak valid untuk membuat pembayaran.');
    }

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
    if (payment.status != PaymentStatus.pending) return payment;
    return payment.copyWith(status: PaymentStatus.paid);
  }

  PaymentModel markFailed(PaymentModel payment) {
    if (payment.status != PaymentStatus.pending) return payment;
    return payment.copyWith(status: PaymentStatus.failed);
  }

  String _generatePaymentId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final nonce = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'PAY-${DateTime.now().microsecondsSinceEpoch}-$nonce';
  }
}
