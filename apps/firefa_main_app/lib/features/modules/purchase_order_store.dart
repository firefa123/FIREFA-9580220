import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'inventory_store.dart';
import 'supplier_store.dart';

class FirefaPurchaseOrder {
  const FirefaPurchaseOrder({
    required this.id, required this.outletId, required this.supplierId,
    required this.supplierName, required this.itemId, required this.itemName,
    required this.unit, required this.quantity, required this.unitCost,
    required this.note, required this.status, required this.createdAt,
    required this.receivedAt, this.receivedQuantity = 0,
    this.receipts = const [], this.cancelledAt,
    this.followUpNote = '', this.followUpDate,
  });
  final String id, outletId, supplierId, supplierName, itemId, itemName;
  final String unit, note, status, createdAt;
  final int quantity, unitCost;
  final String? receivedAt;
  final String? cancelledAt;
  final String followUpNote;
  final String? followUpDate;
  final int receivedQuantity;
  final List<FirefaPurchaseReceipt> receipts;
  int get remainingQuantity => quantity - receivedQuantity;
  int get totalCost => quantity * unitCost;

  Map<String, dynamic> toJson() => {
    'id': id, 'outletId': outletId, 'supplierId': supplierId,
    'supplierName': supplierName, 'itemId': itemId, 'itemName': itemName,
    'unit': unit, 'quantity': quantity, 'unitCost': unitCost,
    'note': note, 'status': status, 'createdAt': createdAt,
    'receivedAt': receivedAt, 'cancelledAt': cancelledAt,
    'followUpNote': followUpNote, 'followUpDate': followUpDate,
    'receivedQuantity': receivedQuantity,
    'receipts': receipts.map((r) => r.toJson()).toList(),
  };

  factory FirefaPurchaseOrder.fromJson(Map<String, dynamic> json) =>
      FirefaPurchaseOrder(
        id: json['id'] as String,
        outletId: json['outletId'] as String,
        supplierId: json['supplierId'] as String,
        supplierName: json['supplierName'] as String,
        itemId: json['itemId'] as String,
        itemName: json['itemName'] as String,
        unit: json['unit'] as String,
        quantity: json['quantity'] as int,
        unitCost: json['unitCost'] as int,
        note: json['note'] as String,
        status: json['status'] as String,
        createdAt: json['createdAt'] as String,
        receivedAt: json['receivedAt'] as String?,
        cancelledAt: json['cancelledAt'] as String?,
        followUpNote: json['followUpNote'] as String? ?? '',
        followUpDate: json['followUpDate'] as String?,
        receivedQuantity: json['receivedQuantity'] as int? ??
            ((json['status'] == 'received') ? json['quantity'] as int : 0),
        receipts: (json['receipts'] as List<dynamic>? ?? [])
            .map((e) => FirefaPurchaseReceipt.fromJson(
                Map<String, dynamic>.from(e as Map))).toList(),
      );

  FirefaPurchaseOrder withStatus(String next, String? timestamp) =>
      FirefaPurchaseOrder(
        id: id, outletId: outletId, supplierId: supplierId,
        supplierName: supplierName, itemId: itemId, itemName: itemName,
        unit: unit, quantity: quantity, unitCost: unitCost, note: note,
        status: next, createdAt: createdAt,
        receivedAt: next == 'cancelled' ? receivedAt : timestamp,
        cancelledAt: next == 'cancelled' ? timestamp : cancelledAt,
        receivedQuantity: receivedQuantity, receipts: receipts,
        followUpNote: followUpNote, followUpDate: followUpDate,
      );

  FirefaPurchaseOrder withFollowUp(String note, String? date) =>
      FirefaPurchaseOrder(
        id: id, outletId: outletId, supplierId: supplierId,
        supplierName: supplierName, itemId: itemId, itemName: itemName,
        unit: unit, quantity: quantity, unitCost: unitCost,
        note: this.note, status: status, createdAt: createdAt,
        receivedAt: receivedAt, cancelledAt: cancelledAt,
        receivedQuantity: receivedQuantity, receipts: receipts,
        followUpNote: note, followUpDate: date,
      );

  FirefaPurchaseOrder withReceipt(FirefaPurchaseReceipt receipt) {
    final total = receivedQuantity + receipt.quantity;
    return FirefaPurchaseOrder(
      id: id, outletId: outletId, supplierId: supplierId,
      supplierName: supplierName, itemId: itemId, itemName: itemName,
      unit: unit, quantity: quantity, unitCost: unitCost, note: note,
      status: total == quantity ? 'received' : 'partial',
      createdAt: createdAt, receivedAt: receipt.receivedAt,
      cancelledAt: cancelledAt,
      receivedQuantity: total, receipts: [...receipts, receipt],
      followUpNote: followUpNote, followUpDate: followUpDate,
    );
  }
}

class FirefaPurchaseReceipt {
  const FirefaPurchaseReceipt({
    required this.id, required this.quantity, required this.receivedAt,
  });
  final String id, receivedAt;
  final int quantity;
  Map<String, dynamic> toJson() => {
    'id': id, 'quantity': quantity, 'receivedAt': receivedAt,
  };
  factory FirefaPurchaseReceipt.fromJson(Map<String, dynamic> json) =>
      FirefaPurchaseReceipt(
        id: json['id'] as String,
        quantity: json['quantity'] as int,
        receivedAt: json['receivedAt'] as String,
      );
}

class FirefaPurchaseOrderStore extends ChangeNotifier {
  FirefaPurchaseOrderStore._();
  static final FirefaPurchaseOrderStore instance = FirefaPurchaseOrderStore._();
  static const storageKey = 'firefa_purchase_orders_v1';
  final List<FirefaPurchaseOrder> _orders = [];
  Future<void>? _initializing;
  Future<void> _pendingSave = Future<void>.value();
  bool _initialized = false;
  int _nextId = 1;

  Future<void> initialize() => _initializing ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final records = (decoded['orders'] as List<dynamic>)
            .map((e) => FirefaPurchaseOrder.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
        _orders..clear()..addAll(records);
        _nextId = decoded['nextId'] as int;
      }
      _initialized = true;
      notifyListeners();
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  List<FirefaPurchaseOrder> forOutlet(String outletId) {
    if (!_initialized) throw StateError('Purchase Orders belum diinisialisasi');
    return List.unmodifiable(
      _orders.where((po) => po.outletId == outletId).toList().reversed,
    );
  }

  bool create({
    required String outletId, required String supplierId,
    required String itemId, required int quantity,
    required int unitCost, required String note,
  }) {
    if (!_initialized || quantity <= 0 || quantity > 999999999 ||
        unitCost < 0 || unitCost > 999999999 ||
        note.trim().length > 200) {
      return false;
    }
    final suppliers = FirefaSupplierStore.instance.forOutlet(outletId);
    final inventory = FirefaInventoryStore.instance.forOutlet(outletId);
    final matches = suppliers.where((s) => s.id == supplierId && s.isActive);
    final items = inventory.where((item) => item.id == itemId);
    if (matches.isEmpty || items.isEmpty) {
      return false;
    }
    final supplier = matches.first;
    final item = items.first;
    _orders.add(FirefaPurchaseOrder(
      id: 'po-${_nextId++}', outletId: outletId,
      supplierId: supplier.id, supplierName: supplier.name,
      itemId: item.id, itemName: item.name, unit: item.unit,
      quantity: quantity, unitCost: unitCost, note: note.trim(),
      status: 'ordered', createdAt: DateTime.now().toIso8601String(),
      receivedAt: null,
    ));
    notifyListeners();
    _save();
    return true;
  }

  bool setFollowUp({
    required String outletId, required String orderId,
    required String note, String? date,
  }) {
    if (!_initialized || note.trim().length > 200 ||
        (date != null && (DateTime.tryParse(date) == null ||
            !RegExp(r'^\\d{4}-\\d{2}-\\d{2}
    if (!_initialized) {
      return false;
    }
    final index = _orders.indexWhere((po) =>
        po.outletId == outletId && po.id == orderId && (po.status == 'ordered' || po.status == 'partial'));
    if (index < 0) {
      return false;
    }
    _orders[index] = _orders[index].withStatus('cancelled', DateTime.now().toIso8601String());
    notifyListeners();
    _save();
    return true;
  }

  bool receive({
    required String outletId, required String orderId, int? quantity,
  }) {
    if (!_initialized) {
      return false;
    }
    final index = _orders.indexWhere((po) =>
        po.outletId == outletId && po.id == orderId &&
        (po.status == 'ordered' || po.status == 'partial'));
    if (index < 0) {
      return false;
    }
    final order = _orders[index];
    final amount = quantity ?? order.remainingQuantity;
    if (amount <= 0 || amount > order.remainingQuantity) {
      return false;
    }
    final inventory = FirefaInventoryStore.instance;
    final items = inventory.forOutlet(outletId)
        .where((item) => item.id == order.itemId);
    if (items.isEmpty || items.first.unit != order.unit ||
        items.first.stock + amount > 999999999) {
      return false;
    }
    final receipt = FirefaPurchaseReceipt(
      id: '${order.id}-receipt-${order.receipts.length + 1}',
      quantity: amount, receivedAt: DateTime.now().toIso8601String(),
    );
    final success = inventory.adjust(
      outletId: outletId, id: order.itemId, type: 'in',
      amount: amount, note: 'Penerimaan PO ${order.id} / ${receipt.id}',
    );
    if (!success) {
      return false;
    }
    _orders[index] = order.withReceipt(receipt);
    notifyListeners();
    _save();
    return true;
  }

  void _save() {
    final snapshot = jsonEncode({
      'version': 1, 'nextId': _nextId,
      'orders': _orders.map((po) => po.toJson()).toList(),
    });
    _pendingSave = _pendingSave.catchError((Object error) {
      debugPrint('PO save sebelumnya gagal: $error');
    }).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, snapshot)) {
        throw StateError('Gagal menyimpan purchase order lokal');
      }
    });
    unawaited(_pendingSave.catchError((Object error) {
      debugPrint('PO save gagal: $error');
    }));
  }

  Future<void> waitForPendingSave() => _pendingSave;
}
).hasMatch(date)))) {
      return false;
    }
    final index = _orders.indexWhere((po) =>
        po.outletId == outletId && po.id == orderId &&
        (po.status == 'ordered' || po.status == 'partial'));
    if (index < 0) return false;
    _orders[index] = _orders[index].withFollowUp(note.trim(), date);
    notifyListeners();
    _save();
    return true;
  }

  bool cancel({required String outletId, required String orderId}) {
    if (!_initialized) {
      return false;
    }
    final index = _orders.indexWhere((po) =>
        po.outletId == outletId && po.id == orderId && (po.status == 'ordered' || po.status == 'partial'));
    if (index < 0) {
      return false;
    }
    _orders[index] = _orders[index].withStatus('cancelled', DateTime.now().toIso8601String());
    notifyListeners();
    _save();
    return true;
  }

  bool receive({
    required String outletId, required String orderId, int? quantity,
  }) {
    if (!_initialized) {
      return false;
    }
    final index = _orders.indexWhere((po) =>
        po.outletId == outletId && po.id == orderId &&
        (po.status == 'ordered' || po.status == 'partial'));
    if (index < 0) {
      return false;
    }
    final order = _orders[index];
    final amount = quantity ?? order.remainingQuantity;
    if (amount <= 0 || amount > order.remainingQuantity) {
      return false;
    }
    final inventory = FirefaInventoryStore.instance;
    final items = inventory.forOutlet(outletId)
        .where((item) => item.id == order.itemId);
    if (items.isEmpty || items.first.unit != order.unit ||
        items.first.stock + amount > 999999999) {
      return false;
    }
    final receipt = FirefaPurchaseReceipt(
      id: '${order.id}-receipt-${order.receipts.length + 1}',
      quantity: amount, receivedAt: DateTime.now().toIso8601String(),
    );
    final success = inventory.adjust(
      outletId: outletId, id: order.itemId, type: 'in',
      amount: amount, note: 'Penerimaan PO ${order.id} / ${receipt.id}',
    );
    if (!success) {
      return false;
    }
    _orders[index] = order.withReceipt(receipt);
    notifyListeners();
    _save();
    return true;
  }

  void _save() {
    final snapshot = jsonEncode({
      'version': 1, 'nextId': _nextId,
      'orders': _orders.map((po) => po.toJson()).toList(),
    });
    _pendingSave = _pendingSave.catchError((Object error) {
      debugPrint('PO save sebelumnya gagal: $error');
    }).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, snapshot)) {
        throw StateError('Gagal menyimpan purchase order lokal');
      }
    });
    unawaited(_pendingSave.catchError((Object error) {
      debugPrint('PO save gagal: $error');
    }));
  }

  Future<void> waitForPendingSave() => _pendingSave;
}
