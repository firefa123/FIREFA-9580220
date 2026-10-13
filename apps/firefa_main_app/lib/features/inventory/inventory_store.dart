import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InventoryCatalogItem {
  final String id;
  final String name;
  final String unit;
  final double minimumStock;
  const InventoryCatalogItem({required this.id, required this.name, required this.unit, this.minimumStock = 0});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'unit': unit, 'minimumStock': minimumStock};
  factory InventoryCatalogItem.fromJson(Map<String, dynamic> json) => InventoryCatalogItem(
    id: json['id'] as String, name: json['name'] as String, unit: json['unit'] as String,
    minimumStock: (json['minimumStock'] as num?)?.toDouble() ?? 0,
  );


}

class InventoryMovement {
  final String id, outletId, itemId, type;
  final double quantity;
  final String? referenceOutletId;
  final String? referenceOrderId;
  final DateTime createdAt;
  const InventoryMovement({required this.id, required this.outletId, required this.itemId, required this.type,
    required this.quantity, required this.createdAt, this.referenceOutletId, this.referenceOrderId});
  Map<String, dynamic> toJson() => {'id': id, 'outletId': outletId, 'itemId': itemId, 'type': type,
    'quantity': quantity, 'referenceOutletId': referenceOutletId, 'referenceOrderId': referenceOrderId, 'createdAt': createdAt.toUtc().toIso8601String()};
  factory InventoryMovement.fromJson(Map<String, dynamic> json) => InventoryMovement(
    id: json['id'] as String, outletId: json['outletId'] as String, itemId: json['itemId'] as String,
    type: json['type'] as String, quantity: (json['quantity'] as num).toDouble(),
    referenceOutletId: json['referenceOutletId'] as String?, referenceOrderId: json['referenceOrderId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String));
}

/// Local-first inventory ledger with outlet-scoped quantities and persisted movements.
class InventoryStore extends ChangeNotifier {
  InventoryStore({this.storageKey = 'firefa_inventory_domain_v1'});
  final String storageKey;
  final Map<String, InventoryCatalogItem> _items = {};
  final Map<String, double> _stock = {};
  final List<InventoryMovement> _movements = [];
  final Set<String> _processedOrderIds = {};
  bool _initialized = false;
  int _nextMovementId = 1;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (data['version'] != 1) throw const FormatException('Versi inventory tidak didukung.');
      final items = (data['items'] as List).map((v) => InventoryCatalogItem.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      final stock = Map<String, dynamic>.from(data['stock'] as Map);
      final movements = (data['movements'] as List).map((v) => InventoryMovement.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      for (final item in items) {
        _validateItem(item);
        if (_items.containsKey(item.id)) throw const FormatException('ID item duplikat.');
        _items[item.id] = item;
      }
      for (final entry in stock.entries) {
        final quantity = (entry.value as num).toDouble();
        if (!quantity.isFinite || quantity < 0) throw const FormatException('Stok tersimpan tidak valid.');
        _stock[entry.key] = quantity;
      }
      _movements.addAll(movements);
      final savedProcessedIds =
          (data['processedOrderIds'] as List? ?? const []).cast<String>();
      for (final savedId in savedProcessedIds) {
        if (savedId.contains('\u0000')) {
          _processedOrderIds.add(savedId);
          continue;
        }
        // Migrate v1 order-only markers to outlet-scoped identities using the
        // durable consumption ledger. Keep an unresolvable legacy marker as a
        // compatibility fallback rather than silently allowing a duplicate.
        final matchingOutlets = movements
            .where((movement) =>
                movement.type == 'order_consumption' &&
                movement.referenceOrderId == savedId)
            .map((movement) => movement.outletId)
            .toSet();
        if (matchingOutlets.isEmpty) {
          _processedOrderIds.add(savedId);
        } else {
          _processedOrderIds.addAll(
            matchingOutlets.map((outlet) => _orderKey(outlet, savedId)),
          );
        }
      }
      _nextMovementId = data['nextMovementId'] as int;
    }
    _initialized = true;
    notifyListeners();
  }

  void _ready() {
    if (!_initialized) {
      throw StateError('InventoryStore belum diinisialisasi.');
    }
  }
  String _key(String outlet, String item) => '$outlet::$item';
  String _orderKey(String outlet, String orderId) => '$outlet\u0000$orderId';
  void _validateItem(InventoryCatalogItem item) {
    if (item.id.trim().isEmpty || item.name.trim().isEmpty || item.unit.trim().isEmpty ||
        !item.minimumStock.isFinite || item.minimumStock < 0) {
      throw ArgumentError('Data item inventory tidak valid.');
    }
  }
  void _validateMovement(String outlet, String item, double quantity) {
    if (outlet.trim().isEmpty) throw ArgumentError('Outlet wajib diisi.');
    if (!_items.containsKey(item)) throw StateError('Item inventory tidak ditemukan.');
    if (!quantity.isFinite || quantity <= 0) throw ArgumentError('Kuantitas harus lebih besar dari nol.');
  }
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode({'version': 1, 'nextMovementId': _nextMovementId,
      'items': _items.values.map((v) => v.toJson()).toList(), 'stock': _stock,
      'movements': _movements.map((v) => v.toJson()).toList(), 'processedOrderIds': _processedOrderIds.toList()});
    if (!await prefs.setString(storageKey, raw)) throw StateError('Gagal menyimpan inventory.');
  }
  List<InventoryCatalogItem> get items { _ready(); return List.unmodifiable(_items.values); }
  double stockFor(String outletId, String itemId) { _ready(); return _stock[_key(outletId, itemId)] ?? 0; }
  List<InventoryMovement> movementsForOutlet(String outletId) {
    _ready();
    return List.unmodifiable(_movements.where((m) => m.outletId == outletId || m.referenceOutletId == outletId));
  }
  List<InventoryCatalogItem> lowStockItems(String outletId) {
    _ready();
    return _items.values.where((item) => stockFor(outletId, item.id) <= item.minimumStock).toList(growable: false);
  }
  Future<void> addItem(InventoryCatalogItem item) async {
    _ready(); _validateItem(item);
    if (_items.containsKey(item.id)) throw StateError('ID item inventory sudah digunakan.');
    _items[item.id] = item;
    try { await _persist(); } catch (_) { _items.remove(item.id); rethrow; }
    notifyListeners();
  }
  Future<void> receiveStock({required String outletId, required String itemId, required double quantity}) async {
    _ready(); _validateMovement(outletId, itemId, quantity);
    final key = _key(outletId, itemId), old = _stock[_key(outletId, itemId)] ?? 0, next = _nextMovementId;
    final movement = InventoryMovement(id: 'INV-${_nextMovementId++}', outletId: outletId, itemId: itemId,
      type: 'stock_in', quantity: quantity, createdAt: DateTime.now().toUtc());
    _stock[key] = old + quantity; _movements.add(movement);
    try { await _persist(); } catch (_) { _stock[key] = old; _movements.remove(movement); _nextMovementId = next; rethrow; }
    notifyListeners();
  }
  Future<void> issueStock({required String outletId, required String itemId, required double quantity}) async {
    _ready(); _validateMovement(outletId, itemId, quantity);
    final key = _key(outletId, itemId), old = _stock[_key(outletId, itemId)] ?? 0, next = _nextMovementId;
    if (quantity > old) throw StateError('Stok tidak mencukupi.');
    final movement = InventoryMovement(id: 'INV-${_nextMovementId++}', outletId: outletId, itemId: itemId,
      type: 'stock_out', quantity: quantity, createdAt: DateTime.now().toUtc());
    _stock[key] = old - quantity; _movements.add(movement);
    try { await _persist(); } catch (_) { _stock[key] = old; _movements.remove(movement); _nextMovementId = next; rethrow; }
    notifyListeners();
  }
  Future<void> transferStock({required String fromOutletId, required String toOutletId, required String itemId, required double quantity}) async {
    _ready();
    if (fromOutletId.trim().isEmpty || toOutletId.trim().isEmpty || fromOutletId == toOutletId) {
      throw ArgumentError('Outlet asal dan tujuan harus berbeda.');
    }
    _validateMovement(fromOutletId, itemId, quantity);
    final fromKey = _key(fromOutletId, itemId), toKey = _key(toOutletId, itemId);
    final from = _stock[fromKey] ?? 0, to = _stock[toKey] ?? 0, next = _nextMovementId;
    if (quantity > from) throw StateError('Stok outlet asal tidak mencukupi.');
    final now = DateTime.now().toUtc();
    final out = InventoryMovement(id: 'INV-${_nextMovementId++}', outletId: fromOutletId,
      itemId: itemId, type: 'transfer_out', quantity: quantity, referenceOutletId: toOutletId, createdAt: now);
    final incoming = InventoryMovement(id: 'INV-${_nextMovementId++}', outletId: toOutletId,
      itemId: itemId, type: 'transfer_in', quantity: quantity, referenceOutletId: fromOutletId, createdAt: now);
    _stock[fromKey] = from - quantity; _stock[toKey] = to + quantity; _movements.addAll([out, incoming]);
    try { await _persist(); } catch (_) {
      _stock[fromKey] = from; _stock[toKey] = to; _movements.remove(out); _movements.remove(incoming); _nextMovementId = next; rethrow;
    }
    notifyListeners();
  }
  /// Deducts a complete recipe requirement set once per order ID.
  /// All quantities are validated before any stock is changed.
  Future<bool> consumeOrderIngredients({
    required String orderId,
    required String outletId,
    required Map<String, double> ingredientQuantities,
  }) async {
    _ready();
    if (orderId.trim().isEmpty || outletId.trim().isEmpty) {
      throw ArgumentError('Order ID dan outlet wajib diisi.');
    }
    final processedKey = _orderKey(outletId, orderId);
    if (_processedOrderIds.contains(processedKey) || _processedOrderIds.contains(orderId)) return false;
    if (ingredientQuantities.isEmpty) {
      throw ArgumentError('Kebutuhan bahan pesanan tidak boleh kosong.');
    }
    final requirements = <String, double>{};
    for (final entry in ingredientQuantities.entries) {
      _validateMovement(outletId, entry.key, entry.value);
      requirements[entry.key] = (requirements[entry.key] ?? 0) + entry.value;
    }
    for (final entry in requirements.entries) {
      if (stockFor(outletId, entry.key) < entry.value) {
        throw StateError('Stok tidak mencukupi untuk item ${entry.key}.');
      }
    }
    final oldNext = _nextMovementId;
    final oldStock = <String, double>{};
    final created = <InventoryMovement>[];
    final now = DateTime.now().toUtc();
    for (final entry in requirements.entries) {
      final key = _key(outletId, entry.key);
      oldStock[key] = _stock[key] ?? 0;
      _stock[key] = oldStock[key]! - entry.value;
      created.add(InventoryMovement(
        id: 'INV-${_nextMovementId++}',
        outletId: outletId,
        itemId: entry.key,
        type: 'order_consumption',
        quantity: entry.value,
        referenceOrderId: orderId,
        createdAt: now,
      ));
    }
    _movements.addAll(created);
    _processedOrderIds.add(processedKey);
    try {
      await _persist();
    } catch (_) {
      oldStock.forEach((key, value) => _stock[key] = value);
      _movements.removeWhere((movement) => created.contains(movement));
      _processedOrderIds.remove(processedKey);
      _nextMovementId = oldNext;
      rethrow;
    }
    notifyListeners();
    return true;
  }

  bool isOrderProcessed(String orderId, {String? outletId}) {
    _ready();
    if (outletId != null) {
      return _processedOrderIds.contains(_orderKey(outletId, orderId)) ||
          _processedOrderIds.contains(orderId);
    }
    return _processedOrderIds.contains(orderId) ||
        _processedOrderIds.any(
          (key) => key.endsWith('\u0000$orderId'),
        );
  }

}
