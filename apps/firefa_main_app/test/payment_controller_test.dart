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
    verificationStatus: status == PaymentStatus.paid
        ? PaymentVerificationStatus.reported
        : status == PaymentStatus.failed
            ? PaymentVerificationStatus.failed
            : PaymentVerificationStatus.notReported,
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
      final reported = PaymentController().markPaid(payment());
      expect(reported.status, PaymentStatus.paid);
      expect(reported.verificationStatus, PaymentVerificationStatus.reported);
    });

    test('marks a reported payment verified only through explicit verification', () {
      final controller = PaymentController();
      final reported = controller.markPaid(payment());
      expect(reported.verificationStatus, PaymentVerificationStatus.reported);
      final verified = controller.markVerified(
        reported,
        verifiedBy: 'owner-1',
        verifiedAt: DateTime(2026, 10, 16, 10),
      );
      expect(verified.verificationStatus, PaymentVerificationStatus.verified);
      expect(verified.verifiedBy, 'owner-1');
      expect(verified.verifiedAt, DateTime(2026, 10, 16, 10));
      expect(identical(controller.markVerified(verified), verified), isTrue);
    });

    test('cannot verify a pending, failed, or refunded payment', () {
      final controller = PaymentController();
      expect(() => controller.markVerified(payment()), throwsStateError);
      expect(() => controller.markVerified(payment(status: PaymentStatus.failed)), throwsStateError);
      expect(() => controller.markVerified(payment(status: PaymentStatus.refunded)), throwsStateError);
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
      expect(PaymentController().markFailed(payment()).verificationStatus, PaymentVerificationStatus.failed);
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
