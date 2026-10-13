import '../models/payment_model.dart';
import '../models/transaction_model.dart';
import 'order_repository.dart';

class InMemoryOrderRepository implements OrderRepository {
  final Map<String, TransactionModel> _transactions = {};
  final Map<String, PaymentModel> _payments = {};

  @override
  Future<void> saveTransaction(TransactionModel transaction) async {
    if (transaction.id.trim().isEmpty ||
        !transaction.totalAmount.isFinite ||
        transaction.totalAmount < 0 ||
        transaction.itemIds.any((id) => id.trim().isEmpty)) {
      throw ArgumentError('Data transaksi tidak valid.');
    }

    final existing = _transactions[transaction.id];
    if (existing != null && !_sameTransaction(existing, transaction)) {
      throw StateError('ID transaksi sudah digunakan oleh data berbeda.');
    }
    _transactions[transaction.id] = transaction;
  }

  @override
  Future<void> savePayment(PaymentModel payment) async {
    if (payment.id.trim().isEmpty ||
        payment.transactionId.trim().isEmpty ||
        !payment.amount.isFinite ||
        payment.amount < 0) {
      throw ArgumentError('Data pembayaran tidak valid.');
    }
    final transaction = _transactions[payment.transactionId];
    if (transaction == null) {
      throw StateError('Transaksi pembayaran tidak ditemukan.');
    }
    if (payment.amount != transaction.totalAmount) {
      throw StateError('Nominal pembayaran tidak sama dengan total transaksi.');
    }

    final existing = _payments[payment.id];
    if (existing != null && !_samePayment(existing, payment)) {
      throw StateError('ID pembayaran sudah digunakan oleh data berbeda.');
    }
    _payments[payment.id] = payment;
  }

  bool _sameTransaction(TransactionModel a, TransactionModel b) =>
      a.id == b.id &&
      a.createdAt == b.createdAt &&
      a.totalAmount == b.totalAmount &&
      a.status == b.status &&
      a.syncStatus == b.syncStatus &&
      _sameList(a.itemIds, b.itemIds);

  bool _samePayment(PaymentModel a, PaymentModel b) =>
      a.id == b.id &&
      a.transactionId == b.transactionId &&
      a.method == b.method &&
      a.status == b.status &&
      a.amount == b.amount &&
      a.createdAt == b.createdAt;

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
