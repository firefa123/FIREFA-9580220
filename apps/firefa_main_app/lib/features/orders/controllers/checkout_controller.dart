import '../models/cart_item_model.dart';
import '../models/transaction_model.dart';

class CheckoutController {
  TransactionModel? checkout(List<CartItemModel> cartItems) {
    if (cartItems.isEmpty) {
      return null;
    }

    final total = cartItems.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );

    return TransactionModel(
      id: _generateTransactionId(),
      createdAt: DateTime.now(),
      totalAmount: total,
      status: TransactionStatus.awaitingPayment,
      syncStatus: SyncStatus.pending,
      itemIds: cartItems.map((item) => item.id).toList(),
    );
  }

  TransactionModel markPaid(TransactionModel transaction) {
    return transaction.copyWith(status: TransactionStatus.paid);
  }

  TransactionModel complete(TransactionModel transaction) {
    return transaction.copyWith(status: TransactionStatus.completed);
  }

  TransactionModel cancel(TransactionModel transaction) {
    return transaction.copyWith(status: TransactionStatus.cancelled);
  }

  String _generateTransactionId() {
    return 'TRX-${DateTime.now().millisecondsSinceEpoch}';
  }
}
