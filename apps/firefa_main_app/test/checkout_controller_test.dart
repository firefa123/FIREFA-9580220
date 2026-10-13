import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/orders/controllers/checkout_controller.dart';
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
