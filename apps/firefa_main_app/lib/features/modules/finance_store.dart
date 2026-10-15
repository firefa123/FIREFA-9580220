// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'inventory_store.dart';
import 'purchase_order_store.dart';
import 'supplier_store.dart';

class FirefaPayablePayment {
  const FirefaPayablePayment({required this.id, required this.amount, required this.method, required this.note, required this.paidAt});
  final String id, method, note, paidAt;
  final int amount;
  Map<String, dynamic> toJson() => {'id': id, 'amount': amount, 'method': method, 'note': note, 'paidAt': paidAt};
  factory FirefaPayablePayment.fromJson(Map<String, dynamic> json) => FirefaPayablePayment(
    id: json['id'] as String, amount: json['amount'] as int, method: json['method'] as String,
    note: json['note'] as String? ?? '', paidAt: json['paidAt'] as String);
}

class FirefaSupplierPayable {
  const FirefaSupplierPayable({required this.id, required this.outletId, required this.supplierId, required this.supplierName,
    required this.purchaseOrderId, required this.receiptId, required this.itemName, required this.quantity,
    required this.unit, required this.unitCost, required this.createdAt, this.dueDate, this.payments = const []});
  final String id, outletId, supplierId, supplierName, purchaseOrderId, receiptId, itemName, unit, createdAt;
  final String? dueDate;
  final int quantity, unitCost;
  final List<FirefaPayablePayment> payments;
  int get amount => quantity * unitCost;
  int get paidAmount => payments.fold<int>(0, (sum, payment) => sum + payment.amount);
  int get outstanding => amount - paidAmount;
  String get status => outstanding == 0 ? 'paid' : paidAmount > 0 ? 'partial' : 'unpaid';
  Map<String, dynamic> toJson() => {'id': id, 'outletId': outletId, 'supplierId': supplierId, 'supplierName': supplierName,
    'purchaseOrderId': purchaseOrderId, 'receiptId': receiptId, 'itemName': itemName, 'quantity': quantity,
    'unit': unit, 'unitCost': unitCost, 'createdAt': createdAt, 'dueDate': dueDate,
    'payments': payments.map((p) => p.toJson()).toList()};
  factory FirefaSupplierPayable.fromJson(Map<String, dynamic> json) => FirefaSupplierPayable(
    id: json['id'] as String, outletId: json['outletId'] as String, supplierId: json['supplierId'] as String,
    supplierName: json['supplierName'] as String, purchaseOrderId: json['purchaseOrderId'] as String,
    receiptId: json['receiptId'] as String, itemName: json['itemName'] as String, quantity: json['quantity'] as int,
    unit: json['unit'] as String, unitCost: json['unitCost'] as int, createdAt: json['createdAt'] as String,
    dueDate: json['dueDate'] as String?, payments: (json['payments'] as List? ?? []).map((p) =>
      FirefaPayablePayment.fromJson(Map<String, dynamic>.from(p as Map))).toList());
  FirefaSupplierPayable withPayment(FirefaPayablePayment payment) => FirefaSupplierPayable(
    id: id, outletId: outletId, supplierId: supplierId, supplierName: supplierName, purchaseOrderId: purchaseOrderId,
    receiptId: receiptId, itemName: itemName, quantity: quantity, unit: unit, unitCost: unitCost,
    createdAt: createdAt, dueDate: dueDate, payments: [...payments, payment]);
}

class FirefaExpense {
  const FirefaExpense({required this.id, required this.outletId, required this.category, required this.amount,
    required this.method, required this.note, required this.createdAt});
  final String id, outletId, category, method, note, createdAt;
  final int amount;
  Map<String, dynamic> toJson() => {'id': id, 'outletId': outletId, 'category': category, 'amount': amount,
    'method': method, 'note': note, 'createdAt': createdAt};
  factory FirefaExpense.fromJson(Map<String, dynamic> json) => FirefaExpense(
    id: json['id'] as String, outletId: json['outletId'] as String, category: json['category'] as String,
    amount: json['amount'] as int, method: json['method'] as String, note: json['note'] as String,
    createdAt: json['createdAt'] as String);
}

class FirefaConsignmentBatch {
  const FirefaConsignmentBatch({required this.id, required this.outletId, required this.supplierId,
    required this.supplierName, required this.itemId, required this.itemName, required this.unit,
    required this.receivedQuantity, required this.unitCost, required this.createdAt,
    this.soldQuantity = 0, this.returnedQuantity = 0, this.settledAmount = 0});
  final String id, outletId, supplierId, supplierName, itemId, itemName, unit, createdAt;
  final int receivedQuantity, unitCost, soldQuantity, returnedQuantity, settledAmount;
  int get remainingQuantity => receivedQuantity - soldQuantity - returnedQuantity;
  int get amountDue => soldQuantity * unitCost - settledAmount;
  Map<String, dynamic> toJson() => {'id': id, 'outletId': outletId, 'supplierId': supplierId, 'supplierName': supplierName,
    'itemId': itemId, 'itemName': itemName, 'unit': unit, 'receivedQuantity': receivedQuantity,
    'unitCost': unitCost, 'createdAt': createdAt, 'soldQuantity': soldQuantity, 'returnedQuantity': returnedQuantity,
    'settledAmount': settledAmount};
  factory FirefaConsignmentBatch.fromJson(Map<String, dynamic> json) => FirefaConsignmentBatch(
    id: json['id'] as String, outletId: json['outletId'] as String, supplierId: json['supplierId'] as String,
    supplierName: json['supplierName'] as String, itemId: json['itemId'] as String, itemName: json['itemName'] as String,
    unit: json['unit'] as String, receivedQuantity: json['receivedQuantity'] as int, unitCost: json['unitCost'] as int,
    createdAt: json['createdAt'] as String, soldQuantity: json['soldQuantity'] as int? ?? 0,
    returnedQuantity: json['returnedQuantity'] as int? ?? 0, settledAmount: json['settledAmount'] as int? ?? 0);
  FirefaConsignmentBatch copy({int? soldQuantity, int? returnedQuantity, int? settledAmount}) => FirefaConsignmentBatch(
    id: id, outletId: outletId, supplierId: supplierId, supplierName: supplierName, itemId: itemId,
    itemName: itemName, unit: unit, receivedQuantity: receivedQuantity, unitCost: unitCost, createdAt: createdAt,
    soldQuantity: soldQuantity ?? this.soldQuantity, returnedQuantity: returnedQuantity ?? this.returnedQuantity,
    settledAmount: settledAmount ?? this.settledAmount);
}

class FirefaFinanceStore extends ChangeNotifier {
  FirefaFinanceStore._();
  static final FirefaFinanceStore instance = FirefaFinanceStore._();
  static const storageKey = 'firefa_finance_stage5_v1';
  final List<FirefaSupplierPayable> _payables = [];
  final List<FirefaExpense> _expenses = [];
  final List<FirefaConsignmentBatch> _consignments = [];
  Future<void> _pendingSave = Future<void>.value();
  Future<void>? _initializing;
  bool _initialized = false;
  int _nextPayableId = 1, _nextExpenseId = 1, _nextConsignmentId = 1, _nextPaymentId = 1;

  Future<void> initialize() => _initializing ??= _load();
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        _payables..clear()..addAll((data['payables'] as List? ?? []).map((e) => FirefaSupplierPayable.fromJson(Map<String, dynamic>.from(e as Map))));
        _expenses..clear()..addAll((data['expenses'] as List? ?? []).map((e) => FirefaExpense.fromJson(Map<String, dynamic>.from(e as Map))));
        _consignments..clear()..addAll((data['consignments'] as List? ?? []).map((e) => FirefaConsignmentBatch.fromJson(Map<String, dynamic>.from(e as Map))));
        _nextPayableId = data['nextPayableId'] as int? ?? 1;
        _nextExpenseId = data['nextExpenseId'] as int? ?? 1;
        _nextConsignmentId = data['nextConsignmentId'] as int? ?? 1;
        _nextPaymentId = data['nextPaymentId'] as int? ?? 1;
      }
      _initialized = true; notifyListeners();
    } catch (_) { _initializing = null; rethrow; }
  }
  void _ensureReady() { if (!_initialized) throw StateError('Finance store belum diinisialisasi.'); }
  List<FirefaSupplierPayable> payablesForOutlet(String outletId) { _ensureReady(); return List.unmodifiable(_payables.where((p) => p.outletId == outletId).toList().reversed); }
  List<FirefaExpense> expensesForOutlet(String outletId) { _ensureReady(); return List.unmodifiable(_expenses.where((e) => e.outletId == outletId).toList().reversed); }
  List<FirefaConsignmentBatch> consignmentsForOutlet(String outletId) { _ensureReady(); return List.unmodifiable(_consignments.where((c) => c.outletId == outletId).toList().reversed); }
  int outstandingPayables(String outletId) => payablesForOutlet(outletId).fold(0, (sum, p) => sum + p.outstanding);
  int totalExpenses(String outletId, {DateTime? from, DateTime? until}) => expensesForOutlet(outletId).where((e) {
    final date = DateTime.parse(e.createdAt);
    return (from == null || !date.isBefore(from)) && (until == null || !date.isAfter(until));
  }).fold(0, (sum, e) => sum + e.amount);
  int consignmentDue(String outletId) => consignmentsForOutlet(outletId).fold(0, (sum, c) => sum + c.amountDue);

  Future<int> syncPurchaseReceipts(String outletId) async {
    _ensureReady();
    final orders = FirefaPurchaseOrderStore.instance.forOutlet(outletId);
    final known = _payables.where((p) => p.outletId == outletId).map((p) => p.receiptId).toSet();
    var added = 0;
    for (final po in orders) {
      for (final receipt in po.receipts) {
        if (known.contains(receipt.id)) continue;
        _payables.add(FirefaSupplierPayable(id: 'AP-${_nextPayableId++}', outletId: outletId,
          supplierId: po.supplierId, supplierName: po.supplierName, purchaseOrderId: po.id,
          receiptId: receipt.id, itemName: po.itemName, quantity: receipt.quantity, unit: po.unit,
          unitCost: po.unitCost, createdAt: receipt.receivedAt));
        known.add(receipt.id); added++;
      }
    }
    if (added > 0) { notifyListeners(); _save(); await waitForPendingSave(); }
    return added;
  }

  bool recordPayablePayment({required String outletId, required String payableId, required int amount,
    required String method, String note = ''}) {
    _ensureReady();
    if (amount <= 0 || amount > 999999999999 || note.trim().length > 200 ||
        !const ['Cash', 'Transfer', 'QRIS', 'Bank'].contains(method)) return false;
    final index = _payables.indexWhere((p) => p.outletId == outletId && p.id == payableId);
    if (index < 0 || amount > _payables[index].outstanding) return false;
    final payment = FirefaPayablePayment(id: 'APP-${_nextPaymentId++}', amount: amount, method: method,
      note: note.trim(), paidAt: DateTime.now().toIso8601String());
    _payables[index] = _payables[index].withPayment(payment);
    notifyListeners(); _save(); return true;
  }

  bool addExpense({required String outletId, required String category, required int amount,
    required String method, required String note}) {
    _ensureReady();
    if (outletId.trim().isEmpty || category.trim().isEmpty || category.trim().length > 60 ||
        amount <= 0 || amount > 999999999999 || note.trim().length > 200 ||
        !const ['Cash', 'Transfer', 'QRIS', 'Bank'].contains(method)) return false;
    _expenses.add(FirefaExpense(id: 'EXP-${_nextExpenseId++}', outletId: outletId, category: category.trim(),
      amount: amount, method: method, note: note.trim(), createdAt: DateTime.now().toIso8601String()));
    notifyListeners(); _save(); return true;
  }

  Future<bool> receiveConsignment({required String outletId, required String supplierId,
    required String itemId, required int quantity, required int unitCost}) async {
    _ensureReady();
    if (quantity <= 0 || quantity > 999999999 || unitCost < 0 || unitCost > 999999999) return false;
    final supplier = FirefaSupplierStore.instance.forOutlet(outletId).where((s) => s.id == supplierId && s.isActive);
    final item = FirefaInventoryStore.instance.forOutlet(outletId).where((i) => i.id == itemId);
    if (supplier.isEmpty || item.isEmpty || item.first.stock > 999999999 - quantity) return false;
    final stock = FirefaInventoryStore.instance;
    if (!stock.adjust(outletId: outletId, id: itemId, type: 'in', amount: quantity, note: 'Penerimaan konsinyasi dari ${supplier.first.name}')) return false;
    try { await stock.waitForPendingSave(); } catch (_) {
      stock.adjust(outletId: outletId, id: itemId, type: 'out', amount: quantity, note: 'Rollback konsinyasi gagal tersimpan');
      await stock.waitForPendingSave(); return false;
    }
    _consignments.add(FirefaConsignmentBatch(id: 'CON-${_nextConsignmentId++}', outletId: outletId,
      supplierId: supplier.first.id, supplierName: supplier.first.name, itemId: item.first.id,
      itemName: item.first.name, unit: item.first.unit, receivedQuantity: quantity, unitCost: unitCost,
      createdAt: DateTime.now().toIso8601String()));
    notifyListeners(); _save();
    try { await waitForPendingSave(); return true; } catch (_) {
      final batch = _consignments.removeLast();
      stock.adjust(outletId: outletId, id: batch.itemId, type: 'out', amount: quantity, note: 'Rollback pencatatan konsinyasi');
      await stock.waitForPendingSave(); _save(); return false;
    }
  }

  bool recordConsignmentSale({required String outletId, required String batchId, required int quantity}) {
    _ensureReady();
    final index = _consignments.indexWhere((c) => c.outletId == outletId && c.id == batchId);
    if (index < 0 || quantity <= 0 || quantity > _consignments[index].remainingQuantity) return false;
    _consignments[index] = _consignments[index].copy(soldQuantity: _consignments[index].soldQuantity + quantity);
    notifyListeners(); _save(); return true;
  }

  Future<bool> returnConsignment({required String outletId, required String batchId, required int quantity}) async {
    _ensureReady();
    final index = _consignments.indexWhere((c) => c.outletId == outletId && c.id == batchId);
    if (index < 0 || quantity <= 0 || quantity > _consignments[index].remainingQuantity) return false;
    final batch = _consignments[index];
    if (!FirefaInventoryStore.instance.adjust(outletId: outletId, id: batch.itemId, type: 'out',
      amount: quantity, note: 'Retur konsinyasi ${batch.id} ke ${batch.supplierName}')) return false;
    try { await FirefaInventoryStore.instance.waitForPendingSave(); } catch (_) { return false; }
    _consignments[index] = batch.copy(returnedQuantity: batch.returnedQuantity + quantity);
    notifyListeners(); _save(); return true;
  }

  bool settleConsignment({required String outletId, required String batchId, required int amount}) {
    _ensureReady();
    final index = _consignments.indexWhere((c) => c.outletId == outletId && c.id == batchId);
    if (index < 0 || amount <= 0 || amount > _consignments[index].amountDue) return false;
    _consignments[index] = _consignments[index].copy(settledAmount: _consignments[index].settledAmount + amount);
    notifyListeners(); _save(); return true;
  }

  Map<String, dynamic> exportLocalSnapshot() {
    _ensureReady();
    return {'version': 1, 'nextPayableId': _nextPayableId, 'nextExpenseId': _nextExpenseId,
      'nextConsignmentId': _nextConsignmentId, 'nextPaymentId': _nextPaymentId,
      'payables': _payables.map((p) => p.toJson()).toList(), 'expenses': _expenses.map((e) => e.toJson()).toList(),
      'consignments': _consignments.map((c) => c.toJson()).toList()};
  }
  void validateLocalSnapshot(Map<String, dynamic> snapshot) {
    if (snapshot['version'] != 1 || snapshot['payables'] is! List || snapshot['expenses'] is! List || snapshot['consignments'] is! List) {
      throw const FormatException('Snapshot keuangan tidak valid.');
    }
    for (final e in snapshot['payables'] as List) { FirefaSupplierPayable.fromJson(Map<String, dynamic>.from(e as Map)); }
    for (final e in snapshot['expenses'] as List) { FirefaExpense.fromJson(Map<String, dynamic>.from(e as Map)); }
    for (final e in snapshot['consignments'] as List) { FirefaConsignmentBatch.fromJson(Map<String, dynamic>.from(e as Map)); }
  }
  Future<void> restoreLocalSnapshot(Map<String, dynamic> snapshot) async {
    validateLocalSnapshot(snapshot);
    final payables = (snapshot['payables'] as List).map((e) => FirefaSupplierPayable.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final expenses = (snapshot['expenses'] as List).map((e) => FirefaExpense.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final consignments = (snapshot['consignments'] as List).map((e) => FirefaConsignmentBatch.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    _payables..clear()..addAll(payables); _expenses..clear()..addAll(expenses); _consignments..clear()..addAll(consignments);
    _nextPayableId = snapshot['nextPayableId'] as int? ?? 1; _nextExpenseId = snapshot['nextExpenseId'] as int? ?? 1;
    _nextConsignmentId = snapshot['nextConsignmentId'] as int? ?? 1; _nextPaymentId = snapshot['nextPaymentId'] as int? ?? 1;
    notifyListeners(); _save(); await waitForPendingSave();
  }
  void _save() {
    final snapshot = jsonEncode(exportLocalSnapshot());
    _pendingSave = _pendingSave.catchError((Object e) { debugPrint('Finance save sebelumnya gagal: $e'); }).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, snapshot)) throw StateError('Gagal menyimpan data keuangan lokal.');
    });
    unawaited(_pendingSave.catchError((Object e) { debugPrint('Finance save gagal: $e'); }));
  }
  Future<void> waitForPendingSave() => _pendingSave;
}
