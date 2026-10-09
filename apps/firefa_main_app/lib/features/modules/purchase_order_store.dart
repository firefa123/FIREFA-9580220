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
    required this.receivedAt,
  });
  final String id, outletId, supplierId, supplierName, itemId, itemName;
  final String unit, note, status, createdAt;
  final int quantity, unitCost;
  final String? receivedAt;
  int get totalCost => quantity * unitCost;

  Map<String, dynamic> toJson() => {
    'id': id, 'outletId': outletId, 'supplierId': supplierId,
    'supplierName': supplierName, 'itemId': itemId, 'itemName': itemName,
    'unit': unit, 'quantity': quantity, 'unitCost': unitCost,
    'note': note, 'status': status, 'createdAt': createdAt,
    'receivedAt': receivedAt,
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
      );

  FirefaPurchaseOrder withStatus(String next, String? timestamp) =>
      FirefaPurchaseOrder(
        id: id, outletId: outletId, supplierId: supplierId,
        supplierName: supplierName, itemId: itemId, itemName: itemName,
        unit: unit, quantity: quantity, unitCost: unitCost, note: note,
        status: next, createdAt: createdAt, receivedAt: timestamp,
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
    if (matches.isEmpty || items.isEmpty) return false;
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

  bool cancel({required String outletId, required String orderId}) {
    if (!_initialized) return false;
    final index = _orders.indexWhere((po) =>
        po.outletId == outletId && po.id == orderId && po.status == 'ordered');
    if (index < 0) return false;
    _orders[index] = _orders[index].withStatus('cancelled', null);
    notifyListeners();
    _save();
    return true;
  }

  bool receive({required String outletId, required String orderId}) {
    if (!_initialized) return false;
    final index = _orders.indexWhere((po) =>
        po.outletId == outletId && po.id == orderId && po.status == 'ordered');
    if (index < 0) return false;
    final order = _orders[index];
    final inventory = FirefaInventoryStore.instance;
    final items = inventory.forOutlet(outletId)
        .where((item) => item.id == order.itemId);
    if (items.isEmpty || items.first.unit != order.unit ||
        items.first.stock + order.quantity > 999999999) {
      return false;
    }
    final success = inventory.adjust(
      outletId: outletId, id: order.itemId, type: 'in',
      amount: order.quantity, note: 'Penerimaan PO ${order.id}',
    );
    if (!success) return false;
    _orders[index] = order.withStatus(
      'received', DateTime.now().toIso8601String(),
    );
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
