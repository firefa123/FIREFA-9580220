import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/orders/controllers/checkout_controller.dart';
import 'package:firefa_main_app/features/orders/models/cart_item_model.dart';
import 'package:firefa_main_app/features/orders/models/transaction_model.dart';

TransactionModel transaction({
  TransactionStatus status = TransactionStatus.awaitingPayment,
}) {
  return TransactionModel(
    id: 'TRX-1',
    createdAt: DateTime(2026, 1, 1),
    totalAmount: 10000,
    status: status,
    itemIds: const ['item-1'],
  );
}

void main() {
  group('CheckoutController', () {
    test('returns null for empty cart', () {
      expect(CheckoutController().checkout([]), isNull);
    });

    test('creates transaction with calculated total and pending sync', () {
      final result = CheckoutController().checkout([
        CartItemModel(id: 'a', name: 'Tea', price: 5000, quantity: 2),
        CartItemModel(id: 'b', name: 'Cake', price: 3000),
      ]);

      expect(result, isNotNull);
      expect(result!.totalAmount, 13000);
      expect(result.status, TransactionStatus.awaitingPayment);
      expect(result.syncStatus, SyncStatus.pending);
      expect(result.itemIds, ['a', 'b']);
    });

    test('rejects blank item ID or name', () {
      expect(
        () => CheckoutController().checkout([
          CartItemModel(id: ' ', name: 'Tea', price: 1000),
        ]),
        throwsArgumentError,
      );
      expect(
        () => CheckoutController().checkout([
          CartItemModel(id: 'a', name: ' ', price: 1000),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects negative price and non-positive quantity', () {
      expect(
        () => CheckoutController().checkout([
          CartItemModel(id: 'a', name: 'Tea', price: -1),
        ]),
        throwsArgumentError,
      );
      expect(
        () => CheckoutController().checkout([
          CartItemModel(id: 'a', name: 'Tea', price: 1000, quantity: 0),
        ]),
        throwsArgumentError,
      );
    });

    test('marks awaiting-payment transaction as paid', () {
      expect(
        CheckoutController().markPaid(transaction()).status,
        TransactionStatus.paid,
      );
    });

    test('mark paid is idempotent', () {
      final paid = transaction(status: TransactionStatus.paid);
      expect(identical(CheckoutController().markPaid(paid), paid), isTrue);
    });

    test('cannot mark cancelled or completed transaction as paid', () {
      final controller = CheckoutController();
      expect(
        () => controller.markPaid(transaction(status: TransactionStatus.cancelled)),
        throwsStateError,
      );
      expect(
        () => controller.markPaid(transaction(status: TransactionStatus.completed)),
        throwsStateError,
      );
    });

    test('only paid transactions can be completed', () {
      final controller = CheckoutController();
      expect(
        controller.complete(transaction(status: TransactionStatus.paid)).status,
        TransactionStatus.completed,
      );
      expect(
        () => controller.complete(transaction()),
        throwsStateError,
      );
    });

    test('completed transaction stays completed idempotently', () {
      final completed = transaction(status: TransactionStatus.completed);
      expect(identical(CheckoutController().complete(completed), completed), isTrue);
    });

    test('cannot cancel paid or completed transactions', () {
      final controller = CheckoutController();
      expect(
        controller.cancel(transaction()).status,
        TransactionStatus.cancelled,
      );
      expect(
        () => controller.cancel(transaction(status: TransactionStatus.paid)),
        throwsStateError,
      );
      expect(
        () => controller.cancel(transaction(status: TransactionStatus.completed)),
        throwsStateError,
      );
    });

    test('cancel is idempotent', () {
      final cancelled = transaction(status: TransactionStatus.cancelled);
      expect(identical(CheckoutController().cancel(cancelled), cancelled), isTrue);
    });
  });
}
