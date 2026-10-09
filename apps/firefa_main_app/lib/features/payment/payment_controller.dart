import 'payment_transaction_model.dart';

class PaymentController {
  final List<PaymentTransaction> transactions = [];

  void addTransaction(PaymentTransaction transaction) {
    transactions.add(transaction);
  }

  List<PaymentTransaction> get completedTransactions {
    return transactions
        .where((item) => item.status == 'completed')
        .toList();
  }
}
