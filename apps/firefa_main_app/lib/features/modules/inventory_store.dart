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

class FirefaInventoryStore extends ChangeNotifier {
  FirefaInventoryStore._();
  static final FirefaInventoryStore instance = FirefaInventoryStore._();

  static const storageKey = 'firefa_inventory_v1';
  static const units = <String>['pcs', 'pack', 'botol', 'kg', 'gram', 'liter', 'ml', 'box'];

  final List<FirefaInventoryItem> _items = [];
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

  void _save() {
    final snapshot = jsonEncode({
      'version': 1,
      'nextId': _nextId,
      'items': _items.map((item) => item.toJson()).toList(),
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
