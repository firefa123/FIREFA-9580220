import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirefaInventoryItem {
  const FirefaInventoryItem({
    required this.id,
    required this.outletId,
    required this.name,
    required this.unit,
    required this.stock,
    required this.minimumStock,
  });

  final String id;
  final String outletId;
  final String name;
  final String unit;
  final int stock;
  final int minimumStock;

  bool get isOutOfStock => stock == 0;
  bool get isLowStock => stock > 0 && stock <= minimumStock;

  Map<String, dynamic> toJson() => {
    'id': id,
    'outletId': outletId,
    'name': name,
    'unit': unit,
    'stock': stock,
    'minimumStock': minimumStock,
  };

  factory FirefaInventoryItem.fromJson(Map<String, dynamic> json) =>
      FirefaInventoryItem(
        id: json['id'] as String,
        outletId: json['outletId'] as String,
        name: json['name'] as String,
        unit: json['unit'] as String,
        stock: json['stock'] as int,
        minimumStock: json['minimumStock'] as int,
      );
}

class FirefaStockMovement {
  const FirefaStockMovement({required this.id, required this.outletId, required this.itemId, required this.itemName, required this.type, required this.before, required this.after, required this.note, required this.timestamp});
  final String id, outletId, itemId, itemName, type, note, timestamp;
  final int before, after;
  int get change => after - before;
  Map<String,dynamic> toJson() => {'id':id,'outletId':outletId,'itemId':itemId,'itemName':itemName,'type':type,'before':before,'after':after,'note':note,'timestamp':timestamp};
  factory FirefaStockMovement.fromJson(Map<String,dynamic> j) => FirefaStockMovement(id:j['id'] as String,outletId:j['outletId'] as String,itemId:j['itemId'] as String,itemName:j['itemName'] as String,type:j['type'] as String,before:j['before'] as int,after:j['after'] as int,note:j['note'] as String,timestamp:j['timestamp'] as String);
}

class FirefaStockOpname {
  const FirefaStockOpname({
    required this.id, required this.outletId, required this.itemId,
    required this.itemName, required this.systemStock, required this.physicalStock,
    required this.note, required this.createdAt, required this.status,
    required this.resolvedAt,
  });
  final String id, outletId, itemId, itemName, note, createdAt, status;
  final String? resolvedAt;
  final int systemStock, physicalStock;
  int get difference => physicalStock - systemStock;
  Map<String, dynamic> toJson() => {
    'id': id, 'outletId': outletId, 'itemId': itemId,
    'itemName': itemName, 'systemStock': systemStock,
    'physicalStock': physicalStock, 'note': note,
    'createdAt': createdAt, 'status': status, 'resolvedAt': resolvedAt,
  };
  factory FirefaStockOpname.fromJson(Map<String, dynamic> json) =>
    FirefaStockOpname(
      id: json['id'] as String, outletId: json['outletId'] as String,
      itemId: json['itemId'] as String, itemName: json['itemName'] as String,
      systemStock: json['systemStock'] as int,
      physicalStock: json['physicalStock'] as int,
      note: json['note'] as String, createdAt: json['createdAt'] as String,
      status: json['status'] as String, resolvedAt: json['resolvedAt'] as String?,
    );
}


class FirefaRecipeLine {
  const FirefaRecipeLine({required this.outletId, required this.menuId, required this.ingredientId, required this.quantity});
  final String outletId, menuId, ingredientId;
  final int quantity;
  Map<String, dynamic> toJson() => {'outletId': outletId, 'menuId': menuId, 'ingredientId': ingredientId, 'quantity': quantity};
  factory FirefaRecipeLine.fromJson(Map<String, dynamic> json) => FirefaRecipeLine(
    outletId: json['outletId'] as String, menuId: json['menuId'] as String,
    ingredientId: json['ingredientId'] as String, quantity: json['quantity'] as int);
}

class FirefaInventoryStore extends ChangeNotifier {
  FirefaInventoryStore._();
  static final FirefaInventoryStore instance = FirefaInventoryStore._();

  static const storageKey = 'firefa_inventory_v1';
  static const units = <String>['pcs', 'pack', 'botol', 'kg', 'gram', 'liter', 'ml', 'box'];

  final List<FirefaInventoryItem> _items = [];
  final List<FirefaStockMovement> _movements = [];
  int _nextMovementId = 1;
  final List<FirefaStockOpname> _opnames = [];
  final List<FirefaRecipeLine> _recipes = [];
  final Set<String> _processedOrderIds = {};
  final Set<String> _reversedOrderIds = {};
  int _nextOpnameId = 1;
  Future<void> _pendingSave = Future<void>.value();
  Future<void>? _initializing;
  bool _initialized = false;
  int _nextId = 1;

  Future<void> initialize() => _initializing ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final restored = (decoded['items'] as List<dynamic>)
            .map((entry) => FirefaInventoryItem.fromJson(
                Map<String, dynamic>.from(entry as Map)))
            .toList();
        _items..clear()..addAll(restored);
        _nextId = decoded['nextId'] as int;
        _movements..clear()..addAll((decoded['movements'] as List<dynamic>? ?? []).map((entry) => FirefaStockMovement.fromJson(Map<String,dynamic>.from(entry as Map))));
        _nextMovementId = decoded['nextMovementId'] as int? ?? 1;
        _opnames..clear()..addAll((decoded['opnames'] as List<dynamic>? ?? []).map((entry) => FirefaStockOpname.fromJson(Map<String, dynamic>.from(entry as Map))));
        _nextOpnameId = decoded['nextOpnameId'] as int? ?? 1;
        _recipes..clear()..addAll((decoded['recipes'] as List<dynamic>? ?? []).map((entry) => FirefaRecipeLine.fromJson(Map<String, dynamic>.from(entry as Map))));
        _processedOrderIds..clear()..addAll((decoded['processedOrderIds'] as List<dynamic>? ?? []).whereType<String>());
        _reversedOrderIds..clear()..addAll((decoded['reversedOrderIds'] as List<dynamic>? ?? []).whereType<String>());
      }
      _initialized = true;
      notifyListeners();
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  List<FirefaInventoryItem> forOutlet(String outletId) {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    return List.unmodifiable(_items.where((item) => item.outletId == outletId));
  }

  bool add({
    required String outletId,
    required String name,
    required String unit,
    required int stock,
    required int minimumStock,
  }) {
    if (!_initialized) return false;
    final normalized = name.trim();
    if (outletId.trim().isEmpty ||
        normalized.isEmpty ||
        normalized.length > 80 ||
        !units.contains(unit) ||
        stock < 0 || stock > 999999999 ||
        minimumStock < 0 || minimumStock > 999999999 ||
        _items.any((item) => item.outletId == outletId &&
            item.name.toLowerCase() == normalized.toLowerCase())) {
      return false;
    }

    _items.add(FirefaInventoryItem(
      id: 'inventory-${_nextId++}',
      outletId: outletId,
      name: normalized,
      unit: unit,
      stock: stock,
      minimumStock: minimumStock,
    ));
    notifyListeners();
    _save();
    return true;
  }


  List<FirefaRecipeLine> recipesForOutlet(String outletId) {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    return List.unmodifiable(_recipes.where((line) => line.outletId == outletId));
  }

  bool addRecipeLine({required String outletId, required String menuId, required String ingredientId, required int quantity}) {
    if (!_initialized || outletId.trim().isEmpty || menuId.trim().isEmpty || quantity <= 0 || quantity > 999999999 || _index(outletId, ingredientId) < 0) return false;
    final index = _recipes.indexWhere((line) => line.outletId == outletId && line.menuId == menuId && line.ingredientId == ingredientId);
    final line = FirefaRecipeLine(outletId: outletId, menuId: menuId, ingredientId: ingredientId, quantity: quantity);
    if (index >= 0) { _recipes[index] = line; } else { _recipes.add(line); }
    notifyListeners();
    _save();
    return true;
  }

  bool removeRecipeLine({required String outletId, required String menuId, required String ingredientId}) {
    if (!_initialized) return false;
    final before = _recipes.length;
    _recipes.removeWhere((line) => line.outletId == outletId && line.menuId == menuId && line.ingredientId == ingredientId);
    if (_recipes.length == before) return false;
    notifyListeners();
    _save();
    return true;
  }

  bool validateOrderStock({required String outletId, required List<({String menuId, int quantity})> menuLines}) {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    final recipes = _recipes.where((line) => line.outletId == outletId).toList();
    if (recipes.isEmpty) return false;
    final requiredQuantities = <String, int>{};
    for (final menu in menuLines) {
      if (menu.quantity <= 0 || menu.quantity > 999999999) {
        throw StateError('Kuantitas pesanan tidak valid.');
      }
      final lines = recipes.where((line) => line.menuId == menu.menuId).toList();
      if (lines.isEmpty) throw StateError('Resep belum diatur untuk menu ${menu.menuId}. Checkout dibatalkan agar stok tidak salah.');
      for (final line in lines) {
        // Bound multiplication and accumulation before computing them so a
        // malformed quantity cannot overflow and pass the stock check.
        if (line.quantity > 999999999 ~/ menu.quantity) {
          throw StateError('Kebutuhan stok untuk menu ${menu.menuId} terlalu besar.');
        }
        final required = line.quantity * menu.quantity;
        final current = requiredQuantities[line.ingredientId] ?? 0;
        if (current > 999999999 - required) {
          throw StateError('Total kebutuhan bahan melebihi batas yang didukung.');
        }
        requiredQuantities[line.ingredientId] = current + required;
      }
    }
    for (final entry in requiredQuantities.entries) {
      final index = _index(outletId, entry.key);
      if (index < 0) throw StateError('Bahan resep tidak ditemukan di outlet ini.');
      if (_items[index].stock < entry.value) throw StateError('Stok ${_items[index].name} tidak cukup. Dibutuhkan ${entry.value}, tersedia ${_items[index].stock}.');
    }
    return true;
  }

  Future<bool> consumeOrderStock({required String orderId, required String outletId, required List<({String menuId, int quantity})> menuLines}) async {
    if (orderId.trim().isEmpty) throw ArgumentError('ID order wajib diisi.');
    if (_processedOrderIds.contains(orderId)) return false;
    if (!validateOrderStock(outletId: outletId, menuLines: menuLines)) return false;
    final requiredQuantities = <String, int>{};
    final recipes = _recipes.where((line) => line.outletId == outletId).toList();
    for (final menu in menuLines) {
      for (final line in recipes.where((line) => line.menuId == menu.menuId)) {
        requiredQuantities[line.ingredientId] = (requiredQuantities[line.ingredientId] ?? 0) + line.quantity * menu.quantity;
      }
    }
    for (final entry in requiredQuantities.entries) {
      final index = _index(outletId, entry.key);
      if (index < 0 || _items[index].stock < entry.value) throw StateError('Stok berubah sebelum pesanan diproses. Silakan coba lagi.');
    }
    for (final entry in requiredQuantities.entries) {
      final index = _index(outletId, entry.key);
      final old = _items[index];
      final after = old.stock - entry.value;
      _items[index] = FirefaInventoryItem(id: old.id, outletId: old.outletId, name: old.name, unit: old.unit, stock: after, minimumStock: old.minimumStock);
      _movements.add(FirefaStockMovement(id: 'movement-${_nextMovementId++}', outletId: outletId, itemId: old.id, itemName: old.name, type: 'out', before: old.stock, after: after, note: 'POS order $orderId', timestamp: DateTime.now().toIso8601String()));
    }
    _processedOrderIds.add(orderId);
    notifyListeners();
    _save();
    await waitForPendingSave();
    return true;
  }

  /// Restores the exact quantities consumed by a cancelled POS order.
  /// Uses the movement ledger rather than current recipes, which may have changed.
  /// A reversal is recorded by order ID so repeated cancellation cannot add stock twice.
  Future<bool> restoreCancelledOrderStock({
    required String orderId,
    required String outletId,
  }) async {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    if (orderId.trim().isEmpty || outletId.trim().isEmpty) {
      throw ArgumentError('Order dan outlet wajib diisi.');
    }
    if (_reversedOrderIds.contains(orderId)) return false;
    if (!_processedOrderIds.contains(orderId)) return false;

    final sourceMovements = _movements.where((movement) =>
      movement.outletId == outletId &&
      movement.type == 'out' &&
      movement.note == 'POS order $orderId'
    ).toList();
    if (sourceMovements.isEmpty) {
      throw StateError('Riwayat pemakaian stok untuk order $orderId tidak ditemukan.');
    }

    final restorations = <({int index, int quantity})>[];
    for (final movement in sourceMovements) {
      final index = _index(outletId, movement.itemId);
      final quantity = movement.before - movement.after;
      if (index < 0 || quantity <= 0 ||
          _items[index].stock > 999999999 - quantity) {
        throw StateError('Stok tidak dapat dipulihkan dengan aman untuk ${movement.itemName}.');
      }
      restorations.add((index: index, quantity: quantity));
    }

    for (final restoration in restorations) {
      final old = _items[restoration.index];
      final after = old.stock + restoration.quantity;
      _items[restoration.index] = FirefaInventoryItem(
        id: old.id,
        outletId: old.outletId,
        name: old.name,
        unit: old.unit,
        stock: after,
        minimumStock: old.minimumStock,
      );
      _movements.add(FirefaStockMovement(
        id: 'movement-${_nextMovementId++}',
        outletId: outletId,
        itemId: old.id,
        itemName: old.name,
        type: 'in',
        before: old.stock,
        after: after,
        note: 'Pembatalan POS order $orderId',
        timestamp: DateTime.now().toIso8601String(),
      ));
    }
    _reversedOrderIds.add(orderId);
    notifyListeners();
    _save();
    await waitForPendingSave();
    return true;
  }

  bool isOrderStockProcessed(String orderId) => _processedOrderIds.contains(orderId);
  bool isOrderStockReversed(String orderId) => _reversedOrderIds.contains(orderId);

  List<FirefaStockMovement> historyForOutlet(String outletId) {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    return List.unmodifiable(_movements.where((m) => m.outletId == outletId).toList().reversed);
  }

  int _index(String outletId, String id) => _items.indexWhere((item) => item.outletId == outletId && item.id == id);

  bool update({required String outletId, required String id, required String name, required String unit, required int minimumStock}) {
    if (!_initialized) return false;
    final index = _index(outletId, id);
    final normalized = name.trim();
    if (index < 0 || normalized.isEmpty || normalized.length > 80 || !units.contains(unit) ||
        minimumStock < 0 || minimumStock > 999999999 ||
        _items.any((item) => item.outletId == outletId && item.id != id && item.name.toLowerCase() == normalized.toLowerCase())) {
      return false;
    }
    final old = _items[index];
    _items[index] = FirefaInventoryItem(id: old.id, outletId: old.outletId, name: normalized, unit: unit, stock: old.stock, minimumStock: minimumStock);
    notifyListeners();
    _save();
    return true;
  }

  bool adjust({required String outletId, required String id, required String type, required int amount, required String note}) {
    if (!_initialized) return false;
    final index = _index(outletId, id);
    if (index < 0 || !['in','out','correction'].contains(type) || amount < 0 || amount > 999999999 || note.trim().length > 200) return false;
    if (type != 'correction' && amount == 0) return false;
    final old = _items[index];
    final after = type == 'in' ? old.stock + amount : type == 'out' ? old.stock - amount : amount;
    if (after < 0 || after > 999999999 || after == old.stock) return false;
    _items[index] = FirefaInventoryItem(id: old.id, outletId: old.outletId, name: old.name, unit: old.unit, stock: after, minimumStock: old.minimumStock);
    _movements.add(FirefaStockMovement(id: 'movement-${_nextMovementId++}', outletId: outletId, itemId: id, itemName: old.name, type: type, before: old.stock, after: after, note: note.trim(), timestamp: DateTime.now().toIso8601String()));
    notifyListeners();
    _save();
    return true;
  }

  List<FirefaStockOpname> opnamesForOutlet(String outletId) {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    return List.unmodifiable(_opnames.where((record) => record.outletId == outletId).toList().reversed);
  }

  bool createOpname({
    required String outletId, required String itemId,
    required int physicalStock, required String note,
  }) {
    if (!_initialized || physicalStock < 0 || physicalStock > 999999999 ||
        note.trim().length > 200) { return false; }
    final index = _index(outletId, itemId);
    if (index < 0 || _opnames.any((record) => record.outletId == outletId &&
        record.itemId == itemId && record.status == 'pending')) { return false; }
    final item = _items[index];
    _opnames.add(FirefaStockOpname(
      id: 'opname-${_nextOpnameId++}', outletId: outletId,
      itemId: item.id, itemName: item.name, systemStock: item.stock,
      physicalStock: physicalStock, note: note.trim(),
      createdAt: DateTime.now().toIso8601String(),
      status: 'pending', resolvedAt: null,
    ));
    notifyListeners();
    _save();
    return true;
  }

  bool resolveOpname({
    required String outletId, required String opnameId,
    required bool approve,
  }) {
    if (!_initialized) return false;
    final recordIndex = _opnames.indexWhere((record) =>
        record.id == opnameId && record.outletId == outletId &&
        record.status == 'pending');
    if (recordIndex < 0) return false;
    final record = _opnames[recordIndex];
    final itemIndex = _index(outletId, record.itemId);
    if (approve && (itemIndex < 0 ||
        _items[itemIndex].stock != record.systemStock)) { return false; }
    if (approve && record.difference != 0) {
      final success = adjust(
        outletId: outletId, id: record.itemId, type: 'correction',
        amount: record.physicalStock,
        note: 'Stock opname ${record.id}: ${record.note}',
      );
      if (!success) return false;
    }
    _opnames[recordIndex] = FirefaStockOpname(
      id: record.id, outletId: record.outletId, itemId: record.itemId,
      itemName: record.itemName, systemStock: record.systemStock,
      physicalStock: record.physicalStock, note: record.note,
      createdAt: record.createdAt,
      status: approve ? 'approved' : 'rejected',
      resolvedAt: DateTime.now().toIso8601String(),
    );
    notifyListeners();
    _save();
    return true;
  }

  bool remove(String outletId, String id) {
    if (!_initialized) return false;
    final index = _index(outletId, id);
    if (index < 0) return false;
    _items.removeAt(index);
    notifyListeners();
    _save();
    return true;
  }

  void _save() {
    final snapshot = jsonEncode({
      'version': 1,
      'nextId': _nextId,
      'items': _items.map((item) => item.toJson()).toList(),
      'nextMovementId': _nextMovementId,
      'movements': _movements.map((m) => m.toJson()).toList(),
      'nextOpnameId': _nextOpnameId,
      'opnames': _opnames.map((record) => record.toJson()).toList(),
      'recipes': _recipes.map((line) => line.toJson()).toList(),
      'processedOrderIds': _processedOrderIds.toList(),
      'reversedOrderIds': _reversedOrderIds.toList(),
    });
    _pendingSave = _pendingSave.catchError((Object error) {
      debugPrint('Inventory save sebelumnya gagal: $error');
    }).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, snapshot)) {
        throw StateError('Gagal menyimpan inventory lokal');
      }
    });
    unawaited(_pendingSave.catchError((Object error) {
      debugPrint('Inventory save gagal: $error');
    }));
  }

  Future<void> waitForPendingSave() => _pendingSave;
}
