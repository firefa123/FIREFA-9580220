import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/orders/controllers/checkout_controller.dart';
import 'package:firefa_main_app/features/orders/controllers/payment_controller.dart';
import 'package:firefa_main_app/features/orders/controllers/receipt_controller.dart';
import 'package:firefa_main_app/features/orders/models/cart_item_model.dart';
import 'package:firefa_main_app/features/orders/models/payment_model.dart';

void main() {
  test('receipt requires matching paid transaction and payment', () {
    final checkout = CheckoutController();
    final paymentController = PaymentController();
    final receipts = ReceiptController();
    final transaction = checkout.checkout([
      CartItemModel(id: 'coffee', name: 'Coffee', price: 15000),
    ])!;
    final payment = paymentController.createPayment(
      transaction: transaction,
      method: PaymentMethod.qris,
    );
    final paidPayment = paymentController.markPaid(payment);
    final paidTransaction = checkout.markPaid(transaction);

    expect(
      () => receipts.generate(transaction: transaction, payment: paidPayment),
      throwsA(isA<StateError>()),
    );
    expect(
      () => receipts.generate(transaction: paidTransaction, payment: payment),
      throwsA(isA<StateError>()),
    );

    final receipt = receipts.generate(
      transaction: paidTransaction,
      payment: paidPayment,
    );
    expect(receipt.transactionId, transaction.id);
    expect(receipt.paymentId, paidPayment.id);
    expect(receipt.totalAmount, 15000);
    expect(receipt.paymentMethod, 'qris');
  });

  test('receipt rejects mismatched IDs and payment amounts', () {
    final checkout = CheckoutController();
    final paymentController = PaymentController();
    final receipts = ReceiptController();
    final awaiting = checkout.checkout([
      CartItemModel(id: 'coffee', name: 'Coffee', price: 15000),
    ])!;
    final transaction = checkout.markPaid(awaiting);
    final payment = paymentController.markPaid(paymentController.createPayment(
      transaction: awaiting,
      method: PaymentMethod.cash,
    ));

    expect(
      () => receipts.generate(
        transaction: transaction,
        payment: payment.copyWith(transactionId: 'another-transaction'),
      ),
      throwsArgumentError,
    );
    expect(
      () => receipts.generate(
        transaction: transaction,
        payment: payment.copyWith(amount: 12000),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => receipts.generate(
        transaction: transaction,
        payment: payment.copyWith(id: ' '),
      ),
      throwsArgumentError,
    );
  });
}
