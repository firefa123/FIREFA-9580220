import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/orders/controllers/receipt_controller.dart';
import 'package:firefa_main_app/features/orders/models/payment_model.dart';
import 'package:firefa_main_app/features/orders/models/transaction_model.dart';

TransactionModel transaction({
  String id = 'TRX-1',
  double amount = 15000,
  TransactionStatus status = TransactionStatus.paid,
}) {
  return TransactionModel(
    id: id,
    createdAt: DateTime(2026, 1, 1),
    totalAmount: amount,
    status: status,
    itemIds: const ['item-1'],
  );
}

PaymentModel payment({
  String transactionId = 'TRX-1',
  String id = 'PAY-1',
  double amount = 15000,
  PaymentStatus status = PaymentStatus.paid,
}) {
  return PaymentModel(
    id: id,
    transactionId: transactionId,
    method: PaymentMethod.cash,
    status: status,
    amount: amount,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('ReceiptController', () {
    test('generates receipt for matching paid transaction and payment', () {
      final receipt = ReceiptController().generate(
        transaction: transaction(),
        payment: payment(),
      );

      expect(receipt.transactionId, 'TRX-1');
      expect(receipt.paymentId, 'PAY-1');
      expect(receipt.totalAmount, 15000);
      expect(receipt.paymentMethod, 'cash');
    });

    test('allows completed transactions', () {
      final receipt = ReceiptController().generate(
        transaction: transaction(status: TransactionStatus.completed),
        payment: payment(),
      );
      expect(receipt.transactionId, 'TRX-1');
    });

    test('rejects unpaid or cancelled transactions', () {
      final controller = ReceiptController();
      for (final status in [
        TransactionStatus.pending,
        TransactionStatus.awaitingPayment,
        TransactionStatus.cancelled,
      ]) {
        expect(
          () => controller.generate(
            transaction: transaction(status: status),
            payment: payment(),
          ),
          throwsStateError,
        );
      }
    });

    test('rejects payment that is not paid', () {
      expect(
        () => ReceiptController().generate(
          transaction: transaction(),
          payment: payment(status: PaymentStatus.pending),
        ),
        throwsStateError,
      );
      expect(
        () => ReceiptController().generate(
          transaction: transaction(),
          payment: payment(status: PaymentStatus.failed),
        ),
        throwsStateError,
      );
    });

    test('rejects payment linked to another transaction', () {
      expect(
        () => ReceiptController().generate(
          transaction: transaction(),
          payment: payment(transactionId: 'TRX-OTHER'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects amount mismatch', () {
      expect(
        () => ReceiptController().generate(
          transaction: transaction(amount: 15000),
          payment: payment(amount: 12000),
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid IDs', () {
      expect(
        () => ReceiptController().generate(
          transaction: transaction(id: ' '),
          payment: payment(),
        ),
        throwsArgumentError,
      );
      expect(
        () => ReceiptController().generate(
          transaction: transaction(),
          payment: payment(id: ' '),
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid amounts', () {
      expect(
        () => ReceiptController().generate(
          transaction: transaction(amount: double.nan),
          payment: payment(amount: double.nan),
        ),
        throwsArgumentError,
      );
      expect(
        () => ReceiptController().generate(
          transaction: transaction(amount: -1),
          payment: payment(amount: -1),
        ),
        throwsArgumentError,
      );
    });
  });
}
