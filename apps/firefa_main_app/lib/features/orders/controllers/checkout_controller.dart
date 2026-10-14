import '../models/cart_item_model.dart';
import '../models/transaction_model.dart';

/// Local checkout and transaction-state simulation.
///
/// This controller does not persist transactions or capture/refund money.
class CheckoutController {
  TransactionModel? checkout(List<CartItemModel> cartItems) {
    if (cartItems.isEmpty) return null;

    for (final item in cartItems) {
      if (item.id.trim().isEmpty) {
        throw ArgumentError.value(item.id, 'cartItems.id', 'Item ID cannot be empty.');
      }
      if (item.name.trim().isEmpty) {
        throw ArgumentError.value(item.name, 'cartItems.name', 'Item name cannot be empty.');
      }
      if (item.price < 0) {
        throw ArgumentError.value(item.price, 'cartItems.price', 'Price cannot be negative.');
      }
      if (item.quantity <= 0) {
        throw ArgumentError.value(item.quantity, 'cartItems.quantity', 'Quantity must be positive.');
      }
    }

    final total = cartItems.fold<int>(0, (sum, item) => sum + item.subtotal);

    return TransactionModel(
      id: _generateTransactionId(),
      createdAt: DateTime.now(),
      totalAmount: total.toDouble(),
      status: TransactionStatus.awaitingPayment,
      syncStatus: SyncStatus.pending,
      itemIds: List.unmodifiable(cartItems.map((item) => item.id)),
    );
  }

  TransactionModel markPaid(TransactionModel transaction) {
    if (transaction.status == TransactionStatus.paid) return transaction;
    if (transaction.status != TransactionStatus.awaitingPayment) {
      throw StateError('Only transactions awaiting payment can be marked paid.');
    }
    return transaction.copyWith(status: TransactionStatus.paid);
  }

  TransactionModel complete(TransactionModel transaction) {
    if (transaction.status == TransactionStatus.completed) return transaction;
    if (transaction.status != TransactionStatus.paid) {
      throw StateError('Only paid transactions can be completed.');
    }
    return transaction.copyWith(status: TransactionStatus.completed);
  }

  TransactionModel cancel(TransactionModel transaction) {
    if (transaction.status == TransactionStatus.cancelled) return transaction;
    if (transaction.status == TransactionStatus.paid ||
        transaction.status == TransactionStatus.completed) {
      throw StateError('Paid or completed transactions require a separate refund flow.');
    }
    return transaction.copyWith(status: TransactionStatus.cancelled);
  }

  String _generateTransactionId() {
    return 'TRX-${DateTime.now().microsecondsSinceEpoch}';
  }
}
