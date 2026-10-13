import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/orders/controllers/checkout_controller.dart';
import 'package:firefa_main_app/features/orders/controllers/payment_controller.dart';
import 'package:firefa_main_app/features/orders/controllers/receipt_controller.dart';
import 'package:firefa_main_app/features/orders/models/cart_item_model.dart';
import 'package:firefa_main_app/features/orders/models/payment_model.dart';
import 'package:firefa_main_app/features/orders/models/transaction_model.dart';
import 'package:firefa_main_app/features/orders/repositories/in_memory_order_repository.dart';

void main() {
  test('checkout to receipt persists a consistent local transaction flow', () async {
    final checkout = CheckoutController();
    final paymentController = PaymentController();
    final receiptController = ReceiptController();
    final repository = InMemoryOrderRepository();

    final transaction = checkout.checkout([
      CartItemModel(id: 'coffee', name: 'Coffee', price: 15000, quantity: 2),
      CartItemModel(id: 'tea', name: 'Tea', price: 5000),
    ])!;
    expect(transaction.totalAmount, 35000);
    expect(transaction.itemDetails, hasLength(2));
    expect(transaction.itemDetails.first.name, 'Coffee');
    expect(transaction.itemDetails.first.unitPrice, 15000);
    expect(transaction.itemDetails.first.quantity, 2);
    expect(transaction.itemDetails.last.subtotal, 5000);
    await repository.saveTransaction(transaction);

    final pendingPayment = paymentController.createPayment(
      transaction: transaction,
      method: PaymentMethod.qris,
    );
    await repository.savePayment(pendingPayment);

    final paidPayment = paymentController.markPaid(pendingPayment);
    final paidTransaction = checkout.markPaid(transaction);
    final receipt = receiptController.generate(
      transaction: paidTransaction,
      payment: paidPayment,
    );

    await repository.savePayment(paidPayment);
    await repository.saveTransaction(paidTransaction);
    final completed = checkout.complete(paidTransaction);
    await repository.saveTransaction(completed);

    // Repeating the exact writes is idempotent; conflicting writes are rejected.
    await repository.savePayment(paidPayment);
    await repository.saveTransaction(completed);

    expect((await repository.getTransaction(transaction.id))!.status,
        TransactionStatus.completed);
    expect(receipt.transactionId, transaction.id);
    expect(receipt.paymentId, paidPayment.id);
    expect(receipt.totalAmount, 35000);
    expect(receipt.paymentMethod, 'qris');
    expect(await repository.getPendingSyncTransactions(), hasLength(1));
  });

  test('local repository never accepts a receipt for a mismatched payment', () async {
    final checkout = CheckoutController();
    final paymentController = PaymentController();
    final repository = InMemoryOrderRepository();
    final transaction = checkout.checkout([
      CartItemModel(id: 'meal', name: 'Meal', price: 12000),
    ])!;
    await repository.saveTransaction(transaction);

    final payment = paymentController.createPayment(
      transaction: transaction,
      method: PaymentMethod.cash,
    );
    await expectLater(
      repository.savePayment(payment.copyWith(transactionId: 'other')),
      throwsStateError,
    );
    expect(await repository.getTransaction(transaction.id), isNotNull);
  });
  test('repository rejects a second payment attempt for the same transaction', () async {
    final checkout = CheckoutController();
    final paymentController = PaymentController();
    final repository = InMemoryOrderRepository();
    final transaction = checkout.checkout([
      CartItemModel(id: 'meal', name: 'Meal', price: 12000),
    ])!;
    await repository.saveTransaction(transaction);

    final firstPayment = paymentController.createPayment(
      transaction: transaction,
      method: PaymentMethod.cash,
    );
    await repository.savePayment(firstPayment);

    final secondPayment = paymentController.createPayment(
      transaction: transaction,
      method: PaymentMethod.qris,
    );
    await expectLater(repository.savePayment(secondPayment), throwsStateError);
    expect((await repository.getPaymentForTransaction(transaction.id))!.id,
        firstPayment.id);
  });

  test('paid payment cannot be attached to a cancelled transaction', () async {
    final checkout = CheckoutController();
    final paymentController = PaymentController();
    final repository = InMemoryOrderRepository();
    final transaction = checkout.checkout([
      CartItemModel(id: 'meal', name: 'Meal', price: 12000),
    ])!;
    await repository.saveTransaction(transaction);

    final pendingPayment = paymentController.createPayment(
      transaction: transaction,
      method: PaymentMethod.cash,
    );
    final cancelled = checkout.cancel(transaction);
    await repository.saveTransaction(cancelled);

    await expectLater(
      repository.savePayment(
        paymentController.markPaid(pendingPayment),
      ),
      throwsStateError,
    );
    expect(await repository.getPaymentForTransaction(transaction.id), isNull);
  });

}
