import '../models/payment_model.dart';
import '../models/transaction_model.dart';
import 'order_repository.dart';

/// In-memory repository for local POS/testing flows; not durable storage.
class InMemoryOrderRepository implements OrderRepository {
  final Map<String, TransactionModel> _transactions = {};
  final Map<String, PaymentModel> _payments = {};

  @override
  Future<void> saveTransaction(TransactionModel transaction) async {
    final id = transaction.id.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(transaction.id, 'transaction.id', 'Transaction ID cannot be empty.');
    }
    if (!transaction.totalAmount.isFinite || transaction.totalAmount < 0) {
      throw ArgumentError.value(transaction.totalAmount, 'transaction.totalAmount', 'Total must be finite and non-negative.');
    }

    _transactions[id] = transaction.copyWith(
      id: id,
      itemIds: List.unmodifiable(transaction.itemIds),
    );
  }

  @override
  Future<void> savePayment(PaymentModel payment) async {
    final id = payment.id.trim();
    final transactionId = payment.transactionId.trim();
    if (id.isEmpty || transactionId.isEmpty) {
      throw ArgumentError('Payment ID and transaction ID cannot be empty.');
    }
    if (!payment.amount.isFinite || payment.amount < 0) {
      throw ArgumentError.value(payment.amount, 'payment.amount', 'Amount must be finite and non-negative.');
    }
    _payments[id] = payment.copyWith(
      id: id,
      transactionId: transactionId,
    );
  }

  @override
  Future<TransactionModel?> getTransaction(String transactionId) async {
    return _transactions[transactionId.trim()];
  }

  @override
  Future<List<TransactionModel>> getPendingSyncTransactions() async {
    return List.unmodifiable(_transactions.values.where(
      (transaction) => transaction.syncStatus != SyncStatus.synced,
    ));
  }

  @override
  Future<void> markTransactionSynced(String transactionId) async {
    final id = transactionId.trim();
    final transaction = _transactions[id];
    if (transaction == null) return;

    _transactions[id] = transaction.copyWith(syncStatus: SyncStatus.synced);
  }
}
