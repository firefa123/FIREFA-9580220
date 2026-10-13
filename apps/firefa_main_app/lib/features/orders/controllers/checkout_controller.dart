import 'dart:math';

import '../models/cart_item_model.dart';
import '../models/transaction_model.dart';

class CheckoutController {
  final Random _random = Random.secure();

  TransactionModel? checkout(List<CartItemModel> cartItems) {
    if (cartItems.isEmpty ||
        cartItems.any((item) =>
            item.id.trim().isEmpty ||
            item.name.trim().isEmpty ||
            item.price < 0 ||
            item.price > 999999999 ||
            item.quantity <= 0 ||
            item.quantity > 999999999)) {
      return null;
    }

    var total = 0;
    for (final item in cartItems) {
      if (item.price != 0 &&
          item.quantity > 999999999 ~/ item.price) {
        return null;
      }
      final lineTotal = item.price * item.quantity;
      if (total > 999999999 - lineTotal) return null;
      total += lineTotal;
    }

    return TransactionModel(
      id: _generateTransactionId(),
      createdAt: DateTime.now(),
      totalAmount: total.toDouble(),
      status: TransactionStatus.awaitingPayment,
      syncStatus: SyncStatus.pending,
      itemIds: List.unmodifiable(cartItems.map((item) => item.id)),
      itemDetails: List.unmodifiable(
        cartItems.map(
          (item) => TransactionLineItem(
            id: item.id,
            name: item.name,
            unitPrice: item.price,
            quantity: item.quantity,
          ),
        ),
      ),
    );
  }

  TransactionModel markPaid(TransactionModel transaction) {
    if (transaction.status == TransactionStatus.paid ||
        transaction.status != TransactionStatus.awaitingPayment) {
      return transaction;
    }
    return transaction.copyWith(status: TransactionStatus.paid);
  }

  TransactionModel complete(TransactionModel transaction) {
    if (transaction.status == TransactionStatus.completed) return transaction;
    if (transaction.status != TransactionStatus.paid) return transaction;
    return transaction.copyWith(status: TransactionStatus.completed);
  }

  TransactionModel cancel(TransactionModel transaction) {
    if (transaction.status == TransactionStatus.cancelled) return transaction;
    if (transaction.status != TransactionStatus.pending &&
        transaction.status != TransactionStatus.awaitingPayment) {
      return transaction;
    }
    return transaction.copyWith(status: TransactionStatus.cancelled);
  }

  String _generateTransactionId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final nonce = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'TRX-${DateTime.now().microsecondsSinceEpoch}-$nonce';
  }
}
