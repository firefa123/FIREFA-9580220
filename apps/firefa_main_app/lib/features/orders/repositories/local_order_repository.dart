import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/payment_model.dart';
import '../models/transaction_model.dart';
import 'in_memory_order_repository.dart';
import 'order_repository.dart';

/// Durable local order storage. The transaction and payment records are saved
/// together in one versioned SharedPreferences snapshot. This is local
/// persistence only; it does not claim transactional disk guarantees or cloud
/// synchronization.
class LocalOrderRepository implements OrderRepository {
  LocalOrderRepository({SharedPreferences? preferences}) {
    _preferences = preferences;
  }

  static const storageKey = 'firefa_local_orders_v1';

  SharedPreferences? _preferences;
  Future<void>? _initialization;
  bool _initialized = false;

  final Map<String, TransactionModel> _transactions = {};
  final Map<String, PaymentModel> _payments = {};
  Future<void> _writeTail = Future<void>.value();

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initialization ??= _load();
  }

  Future<void> _load() async {
    try {
      _preferences ??= await SharedPreferences.getInstance();
      final raw = _preferences!.getString(storageKey);
      final restoredTransactions = <String, TransactionModel>{};
      final restoredPayments = <String, PaymentModel>{};

      if (raw != null && raw.isNotEmpty) {
        final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (decoded['version'] != 1 ||
            decoded['transactions'] is! List ||
            decoded['payments'] is! List) {
          throw const FormatException('Snapshot order lokal tidak valid.');
        }

        for (final entry in decoded['transactions'] as List) {
          final json = Map<String, dynamic>.from(entry as Map);
          final id = json['id'];
          final statusName = json['status'];
          final syncName = json['syncStatus'];
          if (id is! String ||
              statusName is! String ||
              syncName is! String ||
              json['createdAt'] is! String ||
              json['totalAmount'] is! num ||
              json['itemIds'] is! List) {
            throw const FormatException('Data transaksi lokal tidak valid.');
          }
          final status = TransactionStatus.values
              .where((value) => value.name == statusName)
              .firstOrNull;
          final syncStatus = SyncStatus.values
              .where((value) => value.name == syncName)
              .firstOrNull;
          final createdAt = DateTime.tryParse(json['createdAt'] as String);
          if (status == null || syncStatus == null || createdAt == null) {
            throw const FormatException('Status transaksi lokal tidak valid.');
          }
          final transaction = TransactionModel(
            id: id,
            createdAt: createdAt,
            totalAmount: (json['totalAmount'] as num).toDouble(),
            status: status,
            syncStatus: syncStatus,
            itemIds: (json['itemIds'] as List).cast<String>(),
          );
          if (restoredTransactions.containsKey(id)) {
            throw const FormatException('ID transaksi lokal duplikat.');
          }
          restoredTransactions[id] = transaction;
        }

        for (final entry in decoded['payments'] as List) {
          final json = Map<String, dynamic>.from(entry as Map);
          final id = json['id'];
          final transactionId = json['transactionId'];
          final methodName = json['method'];
          final statusName = json['status'];
          if (id is! String ||
              transactionId is! String ||
              methodName is! String ||
              statusName is! String ||
              json['createdAt'] is! String ||
              json['amount'] is! num) {
            throw const FormatException('Data pembayaran lokal tidak valid.');
          }
          final method = PaymentMethod.values
              .where((value) => value.name == methodName)
              .firstOrNull;
          final status = PaymentStatus.values
              .where((value) => value.name == statusName)
              .firstOrNull;
          final createdAt = DateTime.tryParse(json['createdAt'] as String);
          if (method == null || status == null || createdAt == null) {
            throw const FormatException('Status pembayaran lokal tidak valid.');
          }
          final payment = PaymentModel(
            id: id,
            transactionId: transactionId,
            method: method,
            status: status,
            amount: (json['amount'] as num).toDouble(),
            createdAt: createdAt,
          );
          if (restoredPayments.containsKey(id)) {
            throw const FormatException('ID pembayaran lokal duplikat.');
          }
          restoredPayments[id] = payment;
        }
      }

      // Validate the complete candidate snapshot before publishing any state.
      await _validateSnapshot(restoredTransactions, restoredPayments);

      _transactions
        ..clear()
        ..addAll(restoredTransactions);
      _payments
        ..clear()
        ..addAll(restoredPayments);
      _initialized = true;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _ensureInitialized() => initialize();

  Future<void> _persist(
    Map<String, TransactionModel> transactions,
    Map<String, PaymentModel> payments,
  ) async {
    final snapshot = <String, Object>{
      'version': 1,
      'transactions': transactions.values.map((transaction) => {
        'id': transaction.id,
        'createdAt': transaction.createdAt.toIso8601String(),
        'totalAmount': transaction.totalAmount,
        'status': transaction.status.name,
        'syncStatus': transaction.syncStatus.name,
        'itemIds': transaction.itemIds,
      }).toList(),
      'payments': payments.values.map((payment) => {
        'id': payment.id,
        'transactionId': payment.transactionId,
        'method': payment.method.name,
        'status': payment.status.name,
        'amount': payment.amount,
        'createdAt': payment.createdAt.toIso8601String(),
      }).toList(),
    };
    final saved = await _preferences!.setString(storageKey, jsonEncode(snapshot));
    if (!saved) throw StateError('Snapshot order lokal gagal disimpan.');
  }

  Future<void> _validateSnapshot(
    Map<String, TransactionModel> transactions,
    Map<String, PaymentModel> payments,
  ) async {
    final validator = InMemoryOrderRepository();
    for (final transaction in transactions.values) {
      await validator.saveTransaction(transaction);
    }
    for (final payment in payments.values) {
      await validator.savePayment(payment);
    }
  }

  bool _sameTransactionIdentity(TransactionModel a, TransactionModel b) =>
      a.id == b.id &&
      a.createdAt == b.createdAt &&
      a.totalAmount == b.totalAmount &&
      _sameList(a.itemIds, b.itemIds);

  bool _samePaymentIdentity(PaymentModel a, PaymentModel b) =>
      a.id == b.id &&
      a.transactionId == b.transactionId &&
      a.method == b.method &&
      a.amount == b.amount &&
      a.createdAt == b.createdAt;

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
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

  bool _canTransitionPayment(PaymentStatus from, PaymentStatus to) =>
      from == to ||
      (from == PaymentStatus.pending &&
          (to == PaymentStatus.paid || to == PaymentStatus.failed));

  bool _canTransitionSync(SyncStatus from, SyncStatus to) =>
      from == to || (from != SyncStatus.synced && to == SyncStatus.synced);

  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeTail = _writeTail.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _publish(
    Map<String, TransactionModel> transactions,
    Map<String, PaymentModel> payments,
  ) {
    _transactions
      ..clear()
      ..addAll(transactions);
    _payments
      ..clear()
      ..addAll(payments);
  }

  @override
  Future<void> saveTransaction(TransactionModel transaction) async {
    await _ensureInitialized();
    await _serialize(() async {
      final existing = _transactions[transaction.id];
      if (existing != null &&
          (!_sameTransactionIdentity(existing, transaction) ||
              !_canTransitionTransaction(existing.status, transaction.status) ||
              !_canTransitionSync(existing.syncStatus, transaction.syncStatus))) {
        throw StateError('Perubahan transaksi bertentangan dengan state tersimpan.');
      }
      final nextTransactions = Map<String, TransactionModel>.from(_transactions)
        ..[transaction.id] = transaction;
      final nextPayments = Map<String, PaymentModel>.from(_payments);
      await _validateSnapshot(nextTransactions, nextPayments);
      await _persist(nextTransactions, nextPayments);
      _publish(nextTransactions, nextPayments);
    });
  }

  @override
  Future<void> savePayment(PaymentModel payment) async {
    await _ensureInitialized();
    await _serialize(() async {
      final existing = _payments[payment.id];
      if (existing != null &&
          (!_samePaymentIdentity(existing, payment) ||
              !_canTransitionPayment(existing.status, payment.status))) {
        throw StateError('Perubahan pembayaran bertentangan dengan state tersimpan.');
      }
      final nextTransactions = Map<String, TransactionModel>.from(_transactions);
      final nextPayments = Map<String, PaymentModel>.from(_payments)
        ..[payment.id] = payment;
      await _validateSnapshot(nextTransactions, nextPayments);
      await _persist(nextTransactions, nextPayments);
      _publish(nextTransactions, nextPayments);
    });
  }

  @override
  Future<TransactionModel?> getTransaction(String transactionId) async {
    await _ensureInitialized();
    return _transactions[transactionId];
  }

  @override
  Future<List<TransactionModel>> getPendingSyncTransactions() async {
    await _ensureInitialized();
    return _transactions.values
        .where((transaction) => transaction.syncStatus != SyncStatus.synced)
        .toList(growable: false);
  }

  @override
  Future<void> markTransactionSynced(String transactionId) async {
    await _ensureInitialized();
    await _serialize(() async {
      final transaction = _transactions[transactionId];
      if (transaction == null) return;
      final nextTransactions = Map<String, TransactionModel>.from(_transactions)
        ..[transactionId] = transaction.copyWith(syncStatus: SyncStatus.synced);
      final nextPayments = Map<String, PaymentModel>.from(_payments);
      await _validateSnapshot(nextTransactions, nextPayments);
      await _persist(nextTransactions, nextPayments);
      _publish(nextTransactions, nextPayments);
    });
  }
}
