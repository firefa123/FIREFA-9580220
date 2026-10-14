import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/orders/controllers/payment_controller.dart';
import 'package:firefa_main_app/features/orders/models/payment_model.dart';
import 'package:firefa_main_app/features/orders/models/transaction_model.dart';

TransactionModel transaction({
  String id = 'TRX-1',
  double totalAmount = 15000,
  TransactionStatus status = TransactionStatus.awaitingPayment,
}) {
  return TransactionModel(
    id: id,
    createdAt: DateTime(2026, 1, 1),
    totalAmount: totalAmount,
    status: status,
    itemIds: const ['item-1'],
  );
}

PaymentModel payment({PaymentStatus status = PaymentStatus.pending}) {
  return PaymentModel(
    id: 'PAY-1',
    transactionId: 'TRX-1',
    method: PaymentMethod.cash,
    status: status,
    amount: 15000,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('PaymentController', () {
    test('creates a pending payment from transaction details', () {
      final controller = PaymentController();
      final result = controller.createPayment(
        transaction: transaction(),
        method: PaymentMethod.qris,
      );

      expect(result.id, startsWith('PAY-'));
      expect(result.transactionId, 'TRX-1');
      expect(result.method, PaymentMethod.qris);
      expect(result.status, PaymentStatus.pending);
      expect(result.amount, 15000);
    });

    test('rejects blank transaction ID', () {
      expect(
        () => PaymentController().createPayment(
          transaction: transaction(id: ' '),
          method: PaymentMethod.cash,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid amounts', () {
      for (final amount in <double>[-1, double.nan, double.infinity]) {
        expect(
          () => PaymentController().createPayment(
            transaction: transaction(totalAmount: amount),
            method: PaymentMethod.cash,
          ),
          throwsArgumentError,
        );
      }
    });

    test('rejects payment for cancelled transaction', () {
      expect(
        () => PaymentController().createPayment(
          transaction: transaction(status: TransactionStatus.cancelled),
          method: PaymentMethod.cash,
        ),
        throwsStateError,
      );
    });

    test('marks pending payment as paid', () {
      expect(
        PaymentController().markPaid(payment()).status,
        PaymentStatus.paid,
      );
    });

    test('marking paid twice is idempotent', () {
      final controller = PaymentController();
      final paid = payment(status: PaymentStatus.paid);
      expect(identical(controller.markPaid(paid), paid), isTrue);
    });

    test('cannot mark failed or refunded payment as paid', () {
      final controller = PaymentController();
      expect(
        () => controller.markPaid(payment(status: PaymentStatus.failed)),
        throwsStateError,
      );
      expect(
        () => controller.markPaid(payment(status: PaymentStatus.refunded)),
        throwsStateError,
      );
    });

    test('marks pending payment as failed', () {
      expect(
        PaymentController().markFailed(payment()).status,
        PaymentStatus.failed,
      );
    });

    test('marking failed twice is idempotent', () {
      final controller = PaymentController();
      final failed = payment(status: PaymentStatus.failed);
      expect(identical(controller.markFailed(failed), failed), isTrue);
    });

    test('cannot mark paid or refunded payment as failed', () {
      final controller = PaymentController();
      expect(
        () => controller.markFailed(payment(status: PaymentStatus.paid)),
        throwsStateError,
      );
      expect(
        () => controller.markFailed(payment(status: PaymentStatus.refunded)),
        throwsStateError,
      );
    });
  });
}
