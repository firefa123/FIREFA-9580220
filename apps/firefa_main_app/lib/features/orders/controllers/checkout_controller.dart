import '../models/cart_item_model.dart';
import '../models/transaction_model.dart';

class CheckoutController {
  TransactionModel? checkout(List<CartItemModel> cartItems) {
    if (cartItems.isEmpty) {
      return null;
    }

    final total = cartItems.fold<double>(
      0,
      (sum, item) => sum + item.price * item.quantity,
    );

    return TransactionModel(
      id: _generateTransactionId(),
      createdAt: DateTime.now(),
      totalAmount: total,
      status: 'pending',
      itemIds: cartItems.map((item) => item.id).toList(),
    );
  }

  String _generateTransactionId() {
    return 'TRX-${DateTime.now().millisecondsSinceEpoch}';
  }
}
