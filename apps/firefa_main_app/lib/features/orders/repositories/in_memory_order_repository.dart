import '../models/payment_model.dart';
import '../models/transaction_model.dart';
import 'order_repository.dart';

class InMemoryOrderRepository implements OrderRepository {
  final Map<String, TransactionModel> _transactions = {};
  final Map<String, PaymentModel> _payments = {};

  @override
  Future<void> saveTransaction(TransactionModel transaction) async {
    _transactions[transaction.id] = transaction;
  }

  @override
  Future<void> savePayment(PaymentModel payment) async {
    _payments[payment.id] = payment;
  }

  @override
  Future<TransactionModel?> getTransaction(String transactionId) async {
    return _transactions[transactionId];
  }

  @override
  Future<List<TransactionModel>> getPendingSyncTransactions() async {
    return _transactions.values
        .where((transaction) => transaction.syncStatus != SyncStatus.synced)
        .toList(growable: false);
  }

  @override
  Future<void> markTransactionSynced(String transactionId) async {
    final transaction = _transactions[transactionId];
    if (transaction == null) {
      return;
    }

    _transactions[transactionId] = transaction.copyWith(
      syncStatus: SyncStatus.synced,
    );
  }
}
