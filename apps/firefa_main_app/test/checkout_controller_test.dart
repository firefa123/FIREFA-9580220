import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/orders/controllers/checkout_controller.dart';
import 'package:firefa_main_app/features/orders/controllers/payment_controller.dart';
import 'package:firefa_main_app/features/orders/models/payment_model.dart';
import 'package:firefa_main_app/features/orders/models/cart_item_model.dart';
import 'package:firefa_main_app/features/orders/models/transaction_model.dart';

void main() {
  test('checkout rejects invalid cart rows and unsafe totals', () {
    final controller = CheckoutController();

    expect(controller.checkout([]), isNull);
    expect(controller.checkout([
      CartItemModel(id: 'coffee', name: 'Coffee', price: -1),
    ]), isNull);
    expect(controller.checkout([
      CartItemModel(id: 'coffee', name: 'Coffee', price: 1000, quantity: 0),
    ]), isNull);
    expect(controller.checkout([
      CartItemModel(id: 'coffee', name: 'Coffee', price: 999999999, quantity: 2),
    ]), isNull);
    expect(controller.checkout([
      CartItemModel(id: ' ', name: 'Coffee', price: 1000),
    ]), isNull);
  });

  test('transaction transitions cannot skip payment or revive terminal states', () {
    final controller = CheckoutController();
    final awaiting = controller.checkout([
      CartItemModel(id: 'coffee', name: 'Coffee', price: 1000),
    ])!;

    expect(controller.complete(awaiting).status, TransactionStatus.awaitingPayment);
    final paid = controller.markPaid(awaiting);
    expect(paid.status, TransactionStatus.paid);
    expect(controller.markPaid(paid).status, TransactionStatus.paid);
    expect(controller.cancel(paid).status, TransactionStatus.paid);
    final completed = controller.complete(paid);
    expect(completed.status, TransactionStatus.completed);
    expect(controller.cancel(completed).status, TransactionStatus.completed);

    final cancelled = controller.cancel(awaiting);
    expect(cancelled.status, TransactionStatus.cancelled);
    expect(controller.markPaid(cancelled).status, TransactionStatus.cancelled);
    expect(controller.complete(cancelled).status, TransactionStatus.cancelled);
  });

  test('payment creation and terminal transitions are guarded', () {
    final checkout = CheckoutController();
    final payments = PaymentController();
    final transaction = checkout.checkout([
      CartItemModel(id: 'coffee', name: 'Coffee', price: 1500),
    ])!;
    final first = payments.createPayment(
      transaction: transaction,
      method: PaymentMethod.qris,
    );
    final second = payments.createPayment(
      transaction: transaction,
      method: PaymentMethod.qris,
    );

    expect(first.id, isNot(second.id));
    expect(first.amount, 1500);
    expect(first.status, PaymentStatus.pending);
    expect(payments.markPaid(first).status, PaymentStatus.paid);
    final paid = payments.markPaid(first);
    expect(payments.markFailed(paid).status, PaymentStatus.paid);
    final failed = payments.markFailed(first);
    expect(failed.status, PaymentStatus.failed);
    expect(payments.markPaid(failed).status, PaymentStatus.failed);

    expect(
      () => payments.createPayment(
        transaction: checkout.cancel(transaction),
        method: PaymentMethod.cash,
      ),
      throwsArgumentError,
    );
  });

  test('checkout calculates total and generates distinct transaction IDs', () {
    final controller = CheckoutController();
    final cart = [
      CartItemModel(id: 'coffee', name: 'Coffee', price: 12000, quantity: 2),
      CartItemModel(id: 'tea', name: 'Tea', price: 5000, quantity: 1),
    ];

    final first = controller.checkout(cart)!;
    final second = controller.checkout(cart)!;

    expect(first.totalAmount, 29000);
    expect(first.status, TransactionStatus.awaitingPayment);
    expect(first.syncStatus, SyncStatus.pending);
    expect(first.itemIds, ['coffee', 'tea']);
    expect(first.id, isNot(second.id));
  });
}
