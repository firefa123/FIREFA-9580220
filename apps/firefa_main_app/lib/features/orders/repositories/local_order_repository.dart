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
  LocalOrderRepository({SharedPreferences? preferences})
      : _preferences = preferences;

  static const storageKey = 'firefa_local_orders_v1';

  SharedPreferences? _preferences;
  Future<void>? _initialization;
  bool _initialized = false;

  final Map<String, TransactionModel> _transactions = {};
  final Map<String, PaymentModel> _payments = {};
  final InMemoryOrderRepository _validator = InMemoryOrderRepository();

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

      // Validate all restored records using the same identity and transition
      // rules used by the in-memory repository before publishing the snapshot.
      for (final transaction in restoredTransactions.values) {
        await _validator.saveTransaction(transaction);
      }
      for (final payment in restoredPayments.values) {
        await _validator.savePayment(payment);
      }

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

  Future<void> _persist() async {
    final snapshot = <String, Object>{
      'version': 1,
      'transactions': _transactions.values.map((transaction) => {
        'id': transaction.id,
        'createdAt': transaction.createdAt.toIso8601String(),
        'totalAmount': transaction.totalAmount,
        'status': transaction.status.name,
        'syncStatus': transaction.syncStatus.name,
        'itemIds': transaction.itemIds,
      }).toList(),
      'payments': _payments.values.map((payment) => {
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

  @override
  Future<void> saveTransaction(TransactionModel transaction) async {
    await _ensureInitialized();
    await _validator.saveTransaction(transaction);
    _transactions[transaction.id] = transaction;
    await _persist();
  }

  @override
  Future<void> savePayment(PaymentModel payment) async {
    await _ensureInitialized();
    await _validator.savePayment(payment);
    _payments[payment.id] = payment;
    await _persist();
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
    final transaction = _transactions[transactionId];
    if (transaction == null) return;
    final updated = transaction.copyWith(syncStatus: SyncStatus.synced);
    await _validator.saveTransaction(updated);
    _transactions[transactionId] = updated;
    await _persist();
  }
}
