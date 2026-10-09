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

class FirefaInventoryStore extends ChangeNotifier {
  FirefaInventoryStore._();
  static final FirefaInventoryStore instance = FirefaInventoryStore._();

  static const storageKey = 'firefa_inventory_v1';
  static const units = <String>['pcs', 'pack', 'botol', 'kg', 'gram', 'liter', 'ml', 'box'];

  final List<FirefaInventoryItem> _items = [];
  final List<FirefaStockMovement> _movements = [];
  int _nextMovementId = 1;
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
