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
        transaction.itemIds.any((id) => id.trim().isEmpty) ||
        transaction.itemDetails.any((line) =>
            line.id.trim().isEmpty ||
            line.name.trim().isEmpty ||
            line.unitPrice < 0 ||
            line.quantity <= 0 ||
            line.quantity > 999999999 ||
            line.unitPrice != 0 && line.quantity > 999999999 ~/ line.unitPrice)) {
      throw ArgumentError('Data transaksi tidak valid.');
    }
    if (transaction.itemDetails.isNotEmpty) {
      var calculatedTotal = 0;
      for (final line in transaction.itemDetails) {
        final subtotal = line.unitPrice * line.quantity;
        if (calculatedTotal > 999999999 - subtotal) {
          throw ArgumentError('Total detail transaksi melebihi batas.');
        }
        calculatedTotal += subtotal;
      }
      if (calculatedTotal.toDouble() != transaction.totalAmount ||
          transaction.itemIds.length != transaction.itemDetails.length ||
          !_sameList(
            transaction.itemIds,
            transaction.itemDetails.map((line) => line.id).toList(),
          )) {
        throw ArgumentError('Detail item tidak sesuai dengan total transaksi.');
      }
    }

    final existing = _transactions[transaction.id];
    if (existing != null) {
      if (!_sameTransactionIdentity(existing, transaction) ||
          !_canTransitionTransaction(existing.status, transaction.status) ||
          !_canTransitionSync(existing.syncStatus, transaction.syncStatus)) {
        throw StateError('Perubahan transaksi bertentangan dengan state tersimpan.');
      }
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
    if (existing != null) {
      if (!_samePaymentIdentity(existing, payment) ||
          !_canTransitionPayment(existing.status, payment.status)) {
        throw StateError('Perubahan pembayaran bertentangan dengan state tersimpan.');
      }
    }

    // One payment attempt per transaction is the current local POS contract.
    // This prevents duplicate IDs from representing multiple successful
    // payments for the same checkout. A retry flow needs an explicit attempt
    // model rather than silently creating another payment record.
    final otherPayment = _payments.values.where(
      (stored) =>
          stored.transactionId == payment.transactionId &&
          stored.id != payment.id,
    );
    if (otherPayment.isNotEmpty) {
      throw StateError('Transaksi sudah memiliki catatan pembayaran.');
    }

    switch (payment.status) {
      case PaymentStatus.pending:
        if (transaction.status != TransactionStatus.awaitingPayment &&
            transaction.status != TransactionStatus.pending) {
          throw StateError('Status transaksi tidak mengizinkan pembayaran ini.');
        }
      case PaymentStatus.failed:
        if (transaction.status != TransactionStatus.awaitingPayment &&
            transaction.status != TransactionStatus.pending &&
            transaction.status != TransactionStatus.cancelled) {
          throw StateError('Pembayaran gagal tidak sesuai status transaksi.');
        }
      case PaymentStatus.paid:
        if (transaction.status != TransactionStatus.awaitingPayment &&
            transaction.status != TransactionStatus.paid &&
            transaction.status != TransactionStatus.completed) {
          throw StateError('Pembayaran lunas tidak sesuai status transaksi.');
        }
      case PaymentStatus.refunded:
        if (transaction.status != TransactionStatus.completed) {
          throw StateError('Refund hanya diizinkan untuk transaksi selesai.');
        }
    }

    _payments[payment.id] = payment;
  }

  bool _sameTransactionIdentity(TransactionModel a, TransactionModel b) =>
      a.id == b.id &&
      a.createdAt == b.createdAt &&
      a.totalAmount == b.totalAmount &&
      _sameList(a.itemIds, b.itemIds) &&
      _sameLineItems(a.itemDetails, b.itemDetails);

  bool _samePaymentIdentity(PaymentModel a, PaymentModel b) =>
      a.id == b.id &&
      a.transactionId == b.transactionId &&
      a.method == b.method &&
      a.amount == b.amount &&
      a.createdAt == b.createdAt;

  bool _sameLineItems(
    List<TransactionLineItem> a,
    List<TransactionLineItem> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.id != right.id ||
          left.name != right.name ||
          left.unitPrice != right.unitPrice ||
          left.quantity != right.quantity) {
        return false;
      }
    }
    return true;
  }

  bool _canTransitionTransaction(TransactionStatus from, TransactionStatus to) {
    if (from == to) return true;
    switch (from) {
      case TransactionStatus.pending:
        return to == TransactionStatus.awaitingPayment ||
            to == TransactionStatus.cancelled;
      case TransactionStatus.awaitingPayment:
        return to == TransactionStatus.paid ||
            to == TransactionStatus.cancelled;
      case TransactionStatus.paid:
        return to == TransactionStatus.completed;
      case TransactionStatus.cancelled:
      case TransactionStatus.completed:
        return false;
    }
  }

  bool _canTransitionPayment(PaymentStatus from, PaymentStatus to) {
    if (from == to) return true;
    return from == PaymentStatus.pending &&
        (to == PaymentStatus.paid || to == PaymentStatus.failed);
  }

  bool _canTransitionSync(SyncStatus from, SyncStatus to) {
    if (from == to) return true;
    return from != SyncStatus.synced && to == SyncStatus.synced;
  }

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
  Future<List<TransactionModel>> getTransactions() async {
    final result = _transactions.values.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Future<PaymentModel?> getPaymentForTransaction(String transactionId) async {
    final matching = _payments.values
        .where((payment) => payment.transactionId == transactionId)
        .toList(growable: false);
    if (matching.isEmpty) return null;
    matching.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matching.first;
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
