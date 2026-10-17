// ignore_for_file: prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_models.dart';

class FirefaInventoryItem {
  const FirefaInventoryItem({
    required this.id,
    required this.outletId,
    required this.name,
    required this.unit,
    required this.stock,
    required this.minimumStock,
    this.unitCost = 0,
    this.isPreparedIngredient = false,
  });

  final String id;
  final String outletId;
  final String name;
  final String unit;
  final int stock;
  final int minimumStock;
  final double unitCost;
  final bool isPreparedIngredient;

  bool get isOutOfStock => stock == 0;
  bool get isLowStock => stock > 0 && stock <= minimumStock;

  Map<String, dynamic> toJson() => {
    'id': id,
    'outletId': outletId,
    'name': name,
    'unit': unit,
    'stock': stock,
    'minimumStock': minimumStock,
    'unitCost': unitCost,
    'isPreparedIngredient': isPreparedIngredient,
  };

  factory FirefaInventoryItem.fromJson(Map<String, dynamic> json) =>
      FirefaInventoryItem(
        id: json['id'] as String,
        outletId: json['outletId'] as String,
        name: json['name'] as String,
        unit: json['unit'] as String,
        stock: json['stock'] as int,
        minimumStock: json['minimumStock'] as int,
        unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0,
        isPreparedIngredient: json['isPreparedIngredient'] as bool? ?? false,
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

class FirefaPrepRecipeLine {
  const FirefaPrepRecipeLine({required this.outletId, required this.preparedItemId, required this.ingredientId, required this.quantity});
  final String outletId, preparedItemId, ingredientId;
  final int quantity;
  Map<String, dynamic> toJson() => {'outletId': outletId, 'preparedItemId': preparedItemId, 'ingredientId': ingredientId, 'quantity': quantity};
  factory FirefaPrepRecipeLine.fromJson(Map<String, dynamic> json) => FirefaPrepRecipeLine(
    outletId: json['outletId'] as String, preparedItemId: json['preparedItemId'] as String,
    ingredientId: json['ingredientId'] as String, quantity: json['quantity'] as int);
}

class FirefaInventoryStore extends ChangeNotifier {
  FirefaInventoryStore._();
  @visibleForTesting
  factory FirefaInventoryStore.forTesting() => FirefaInventoryStore._();
  static final FirefaInventoryStore instance = FirefaInventoryStore._();

  static const storageKey = 'firefa_inventory_v1';
  static const units = <String>['pcs', 'pack', 'botol', 'kg', 'gram', 'liter', 'ml', 'box'];

  final List<FirefaInventoryItem> _items = [];
  final List<FirefaStockMovement> _movements = [];
  int _nextMovementId = 1;
  final List<FirefaStockOpname> _opnames = [];
  final List<FirefaRecipeLine> _recipes = [];
  final List<FirefaPrepRecipeLine> _prepRecipes = [];
  final Map<String, int> _preparedYields = {};
  final Set<String> _processedOrderIds = {};
  final Set<String> _reversedOrderIds = {};
  final Set<String> _processedTransferIds = {};
  final Map<String, Map<String, dynamic>> _pendingOrderConsumptions = {};
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
      var snapshot = <String, dynamic>{
        'version': 1,
        'nextId': 1,
        'items': <dynamic>[],
        'nextMovementId': 1,
        'movements': <dynamic>[],
        'nextOpnameId': 1,
        'opnames': <dynamic>[],
        'recipes': <dynamic>[],
        'prepRecipes': <dynamic>[],
        'preparedYields': <String, dynamic>{},
        'processedOrderIds': <dynamic>[],
        'reversedOrderIds': <dynamic>[],
        'processedTransferIds': <dynamic>[],
        'pendingOrderConsumptions': <String, dynamic>{},
      };
      if (raw != null && raw.isNotEmpty) {
        snapshot = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
      _validateSnapshotData(snapshot);

      // Parse and validate everything into temporary values before replacing
      // the in-memory state. A corrupt persisted snapshot must be recoverable.
      final items = (snapshot['items'] as List<dynamic>)
          .map((entry) => FirefaInventoryItem.fromJson(
              Map<String, dynamic>.from(entry as Map)))
          .toList();
      final movements = (snapshot['movements'] as List<dynamic>? ?? [])
          .map((entry) => FirefaStockMovement.fromJson(
              Map<String, dynamic>.from(entry as Map)))
          .toList();
      final opnames = (snapshot['opnames'] as List<dynamic>? ?? [])
          .map((entry) => FirefaStockOpname.fromJson(
              Map<String, dynamic>.from(entry as Map)))
          .toList();
      final recipes = (snapshot['recipes'] as List<dynamic>? ?? [])
          .map((entry) => FirefaRecipeLine.fromJson(
              Map<String, dynamic>.from(entry as Map)))
          .toList();
      final prepRecipes = (snapshot['prepRecipes'] as List<dynamic>? ?? [])
          .map((entry) => FirefaPrepRecipeLine.fromJson(
              Map<String, dynamic>.from(entry as Map)))
          .toList();
      final preparedYields = Map<String, dynamic>.from(
        snapshot['preparedYields'] as Map? ?? const {},
      ).map((key, value) => MapEntry(key, value as int));
      final processedOrderIds =
          (snapshot['processedOrderIds'] as List<dynamic>? ?? []).cast<String>();
      final reversedOrderIds =
          (snapshot['reversedOrderIds'] as List<dynamic>? ?? []).cast<String>();
      final processedTransferIds =
          (snapshot['processedTransferIds'] as List<dynamic>? ?? []).cast<String>();
      final pendingOrderConsumptions = Map<String, Map<String, dynamic>>.from(
        Map<String, dynamic>.from(snapshot['pendingOrderConsumptions'] as Map? ?? const {}).map(
          (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
        ),
      );

      _items..clear()..addAll(items);
      _movements..clear()..addAll(movements);
      _opnames..clear()..addAll(opnames);
      _recipes..clear()..addAll(recipes);
      _prepRecipes..clear()..addAll(prepRecipes);
      _preparedYields..clear()..addAll(preparedYields);
      _processedOrderIds..clear()..addAll(processedOrderIds);
      _reversedOrderIds..clear()..addAll(reversedOrderIds);
      _processedTransferIds..clear()..addAll(processedTransferIds);
      _pendingOrderConsumptions..clear()..addAll(pendingOrderConsumptions);
      _nextId = snapshot['nextId'] as int;
      _nextMovementId = (snapshot['nextMovementId'] as int?) ?? 1;
      _nextOpnameId = (snapshot['nextOpnameId'] as int?) ?? 1;
      _initialized = true;
      notifyListeners();
    } catch (error) {
      _items.clear();
      _movements.clear();
      _opnames.clear();
      _recipes.clear();
      _prepRecipes.clear();
      _preparedYields.clear();
      _processedOrderIds.clear();
      _reversedOrderIds.clear();
      _processedTransferIds.clear();
      _pendingOrderConsumptions.clear();
      _nextId = 1;
      _nextMovementId = 1;
      _nextOpnameId = 1;
      _initialized = false;
      _initializing = null;
      if (error is FormatException) rethrow;
      throw FormatException('Snapshot inventory tidak valid: $error');
    }
  }

  void _validateSnapshotData(Map<String, dynamic> snapshot) {
    if (snapshot['version'] != 1 ||
        snapshot['items'] is! List ||
        snapshot['nextId'] is! int ||
        (snapshot['nextId'] as int) < 1 ||
        (snapshot['nextMovementId'] != null &&
            (snapshot['nextMovementId'] is! int ||
             (snapshot['nextMovementId'] as int) < 1)) ||
        (snapshot['nextOpnameId'] != null &&
            (snapshot['nextOpnameId'] is! int ||
             (snapshot['nextOpnameId'] as int) < 1)) ||
        (snapshot['movements'] != null && snapshot['movements'] is! List) ||
        (snapshot['opnames'] != null && snapshot['opnames'] is! List) ||
        (snapshot['recipes'] != null && snapshot['recipes'] is! List) ||
        (snapshot['prepRecipes'] != null && snapshot['prepRecipes'] is! List) ||
        (snapshot['preparedYields'] != null && snapshot['preparedYields'] is! Map) ||
        (snapshot['processedOrderIds'] != null && snapshot['processedOrderIds'] is! List) ||
        (snapshot['reversedOrderIds'] != null && snapshot['reversedOrderIds'] is! List) ||
        (snapshot['processedTransferIds'] != null && snapshot['processedTransferIds'] is! List) ||
        (snapshot['pendingOrderConsumptions'] != null && snapshot['pendingOrderConsumptions'] is! Map)) {
      throw const FormatException('Struktur snapshot inventory tidak valid.');
    }

    try {
      final items = (snapshot['items'] as List)
          .map((entry) => FirefaInventoryItem.fromJson(
              Map<String, dynamic>.from(entry as Map)))
          .toList();
      final itemsByKey = <String, FirefaInventoryItem>{};
      var maximumItemSequence = 0;
      for (final item in items) {
        final match = RegExp(r'^inventory-(\d+)$').firstMatch(item.id);
        final sequence = int.tryParse(match?.group(1) ?? '');
        if (item.id.trim().isEmpty ||
            item.outletId.trim().isEmpty ||
            item.name.trim().isEmpty ||
            item.name.length > 80 ||
            !units.contains(item.unit) ||
            item.stock < 0 || item.stock > 999999999 ||
            item.minimumStock < 0 || item.minimumStock > 999999999 ||
            !item.unitCost.isFinite || item.unitCost < 0 ||
            item.unitCost > 999999999999 ||
            itemsByKey.containsKey('${item.outletId}::${item.id}')) {
          throw const FormatException('Data item inventory tidak valid.');
        }
        itemsByKey['${item.outletId}::${item.id}'] = item;
        if (sequence != null && sequence > maximumItemSequence) {
          maximumItemSequence = sequence;
        }
      }
      if ((snapshot['nextId'] as int) <= maximumItemSequence) {
        throw const FormatException('Counter item inventory akan menggunakan ulang ID.');
      }

      final movements = (snapshot['movements'] as List<dynamic>? ?? [])
          .map((entry) => FirefaStockMovement.fromJson(
              Map<String, dynamic>.from(entry as Map)))
          .toList();
      var maximumMovementSequence = 0;
      final movementIds = <String>{};
      for (final movement in movements) {
        final match = RegExp(r'^movement-(\d+)$').firstMatch(movement.id);
        final sequence = int.tryParse(match?.group(1) ?? '');
        final item = itemsByKey['${movement.outletId}::${movement.itemId}'];
        final directionIsValid = switch (movement.type) {
          'in' => movement.after > movement.before,
          'out' => movement.after < movement.before,
          'correction' => movement.after != movement.before,
          _ => false,
        };
        if (sequence == null || sequence < 1 ||
            !movementIds.add(movement.id) ||
            movement.outletId.trim().isEmpty ||
            movement.itemId.trim().isEmpty ||
            item == null ||
            movement.itemName != item.name ||
            movement.before < 0 || movement.after < 0 ||
            movement.before > 999999999 || movement.after > 999999999 ||
            !directionIsValid ||
            movement.note.trim().length > 200) {
          throw const FormatException('Data pergerakan stok tidak valid.');
        }
        try { DateTime.parse(movement.timestamp); } catch (_) {
          throw const FormatException('Waktu pergerakan stok tidak valid.');
        }
        if (sequence > maximumMovementSequence) maximumMovementSequence = sequence;
      }
      if (((snapshot['nextMovementId'] as int?) ?? 1) <= maximumMovementSequence) {
        throw const FormatException('Counter pergerakan stok akan menggunakan ulang ID.');
      }

      final opnames = (snapshot['opnames'] as List<dynamic>? ?? [])
          .map((entry) => FirefaStockOpname.fromJson(
              Map<String, dynamic>.from(entry as Map)))
          .toList();
      var maximumOpnameSequence = 0;
      final opnameIds = <String>{};
      for (final opname in opnames) {
        final match = RegExp(r'^opname-(\d+)$').firstMatch(opname.id);
        final sequence = int.tryParse(match?.group(1) ?? '');
        if (sequence == null || sequence < 1 ||
            !opnameIds.add(opname.id) ||
            opname.outletId.trim().isEmpty ||
            itemsByKey['${opname.outletId}::${opname.itemId}'] == null ||
            opname.systemStock < 0 || opname.physicalStock < 0 ||
            opname.systemStock > 999999999 || opname.physicalStock > 999999999 ||
            !['pending', 'approved', 'rejected'].contains(opname.status) ||
            (opname.status == 'pending' && opname.resolvedAt != null) ||
            (opname.status != 'pending' && opname.resolvedAt == null) ||
            opname.note.trim().length > 200) {
          throw const FormatException('Data stock opname tidak valid.');
        }
        try {
          DateTime.parse(opname.createdAt);
          if (opname.resolvedAt != null) DateTime.parse(opname.resolvedAt!);
        } catch (_) {
          throw const FormatException('Waktu stock opname tidak valid.');
        }
        if (sequence > maximumOpnameSequence) maximumOpnameSequence = sequence;
      }
      if (((snapshot['nextOpnameId'] as int?) ?? 1) <= maximumOpnameSequence) {
        throw const FormatException('Counter stock opname akan menggunakan ulang ID.');
      }

      final recipes = (snapshot['recipes'] as List<dynamic>? ?? [])
          .map((entry) => FirefaRecipeLine.fromJson(
              Map<String, dynamic>.from(entry as Map)))
          .toList();
      for (final recipe in recipes) {
        if (recipe.outletId.trim().isEmpty || recipe.menuId.trim().isEmpty ||
            recipe.quantity <= 0 || recipe.quantity > 999999999 ||
            itemsByKey['${recipe.outletId}::${recipe.ingredientId}'] == null) {
          throw const FormatException('Resep menu inventory tidak valid.');
        }
      }

      final prepRecipes = (snapshot['prepRecipes'] as List<dynamic>? ?? [])
          .map((entry) => FirefaPrepRecipeLine.fromJson(
              Map<String, dynamic>.from(entry as Map)))
          .toList();
      for (final recipe in prepRecipes) {
        final target = itemsByKey['${recipe.outletId}::${recipe.preparedItemId}'];
        if (recipe.outletId.trim().isEmpty || recipe.quantity <= 0 ||
            recipe.quantity > 999999999 || target == null ||
            !target.isPreparedIngredient ||
            itemsByKey['${recipe.outletId}::${recipe.ingredientId}'] == null ||
            recipe.preparedItemId == recipe.ingredientId) {
          throw const FormatException('Resep bahan olahan tidak valid.');
        }
      }

      final yields = Map<String, dynamic>.from(
        snapshot['preparedYields'] as Map? ?? const {},
      );
      for (final entry in yields.entries) {
        if (entry.value is! int || (entry.value as int) <= 0 ||
            (entry.value as int) > 999999999) {
          throw const FormatException('Hasil produksi bahan olahan tidak valid.');
        }
        final parts = entry.key.split('::');
        if (parts.length != 2) {
          throw const FormatException('Referensi hasil produksi tidak valid.');
        }
        final item = itemsByKey['${parts[0]}::${parts[1]}'];
        if (item == null || !item.isPreparedIngredient) {
          throw const FormatException('Referensi hasil produksi tidak valid.');
        }
      }

      final processedValues = snapshot['processedOrderIds'] as List? ?? const [];
      final reversedValues = snapshot['reversedOrderIds'] as List? ?? const [];
      final transferValues = snapshot['processedTransferIds'] as List? ?? const [];
      if (processedValues.any((value) => value is! String || value.trim().isEmpty) ||
          reversedValues.any((value) => value is! String || value.trim().isEmpty) ||
          transferValues.any((value) => value is! String || value.trim().isEmpty) ||
          transferValues.toSet().length != transferValues.length ||
          !processedValues.toSet().containsAll(reversedValues)) {
        throw const FormatException('Riwayat konsumsi stok tidak valid.');
      }
      final intents = Map<String, dynamic>.from(
        snapshot['pendingOrderConsumptions'] as Map? ?? const {},
      );
      for (final entry in intents.entries) {
        final intent = Map<String, dynamic>.from(entry.value as Map);
        final outletId = intent['outletId'];
        final orderId = intent['orderId'];
        final lines = intent['menuLines'];
        final ingredientQuantities = intent['ingredientQuantities'];
        if (outletId is! String || outletId.trim().isEmpty ||
            orderId is! String || orderId.trim().isEmpty ||
            entry.key != jsonEncode([outletId, orderId]) ||
            lines is! List || lines.isEmpty ||
            ingredientQuantities is! Map) {
          throw const FormatException('Jurnal pemakaian stok tidak valid.');
        }
        for (final rawLine in lines) {
          if (rawLine is! Map) {
            throw const FormatException('Baris jurnal pemakaian stok tidak valid.');
          }
          final line = Map<String, dynamic>.from(rawLine);
          if (line['menuId'] is! String ||
              (line['menuId'] as String).trim().isEmpty ||
              line['quantity'] is! int ||
              (line['quantity'] as int) < 1 ||
              (line['quantity'] as int) > 999999999) {
            throw const FormatException('Baris jurnal pemakaian stok tidak valid.');
          }
        }
        for (final entry in Map<String, dynamic>.from(ingredientQuantities).entries) {
          if (entry.key.trim().isEmpty || entry.value is! int ||
              (entry.value as int) < 1 || (entry.value as int) > 999999999) {
            throw const FormatException('Kuantitas bahan pada jurnal stok tidak valid.');
          }
        }
      }
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Data snapshot inventory tidak valid: $error');
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
    double unitCost = 0,
    bool isPreparedIngredient = false,
  }) {
    if (!_initialized) return false;
    final normalized = name.trim();
    if (outletId.trim().isEmpty ||
        normalized.isEmpty ||
        normalized.length > 80 ||
        !units.contains(unit) ||
        stock < 0 || stock > 999999999 ||
        minimumStock < 0 || minimumStock > 999999999 ||
        !unitCost.isFinite || unitCost < 0 || unitCost > 999999999999 ||
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
      unitCost: unitCost,
      isPreparedIngredient: isPreparedIngredient,
    ));
    notifyListeners();
    _save();
    return true;
  }


  bool setUnitCost({required String outletId, required String id, required double unitCost}) {
    if (!_initialized || !unitCost.isFinite || unitCost < 0 || unitCost > 999999999999) return false;
    final index = _index(outletId, id);
    if (index < 0) return false;
    final old = _items[index];
    _items[index] = FirefaInventoryItem(id: old.id, outletId: old.outletId, name: old.name, unit: old.unit,
      stock: old.stock, minimumStock: old.minimumStock, unitCost: unitCost, isPreparedIngredient: old.isPreparedIngredient);
    notifyListeners(); _save(); return true;
  }

  bool setPreparedIngredient({required String outletId, required String id, required bool prepared}) {
    if (!_initialized) return false;
    if (!prepared && _prepRecipes.any((line) => line.outletId == outletId && line.preparedItemId == id)) return false;
    final index = _index(outletId, id);
    if (index < 0) return false;
    final old = _items[index];
    _items[index] = FirefaInventoryItem(id: old.id, outletId: old.outletId, name: old.name, unit: old.unit,
      stock: old.stock, minimumStock: old.minimumStock, unitCost: old.unitCost, isPreparedIngredient: prepared);
    notifyListeners(); _save(); return true;
  }

  static double convertQuantity({required double quantity, required String fromUnit, required String toUnit}) {
    if (!quantity.isFinite || quantity < 0) throw ArgumentError('Kuantitas konversi tidak valid.');
    final from = fromUnit.trim().toLowerCase(), to = toUnit.trim().toLowerCase();
    if (from == to) return quantity;
    const mass = <String, double>{'kg': 1000, 'gram': 1, 'g': 1};
    const volume = <String, double>{'liter': 1000, 'l': 1000, 'ml': 1};
    if (mass.containsKey(from) && mass.containsKey(to)) return quantity * mass[from]! / mass[to]!;
    if (volume.containsKey(from) && volume.containsKey(to)) return quantity * volume[from]! / volume[to]!;
    throw ArgumentError('Satuan tidak kompatibel atau belum memiliki faktor konversi.');
  }

  bool adjustConverted({required String outletId, required String id, required String type, required double amount, required String inputUnit, required String note}) {
    final index = _index(outletId, id);
    if (!_initialized || index < 0 || !amount.isFinite || amount < 0) return false;
    final converted = convertQuantity(quantity: amount, fromUnit: inputUnit, toUnit: _items[index].unit);
    final rounded = converted.round();
    if ((converted - rounded).abs() > 0.0000001) throw ArgumentError('Hasil konversi pecahan. Gunakan satuan stok terkecil seperti gram atau ml.');
    return adjust(outletId: outletId, id: id, type: type, amount: rounded,
      note: note + ' (input ' + amount.toString() + ' ' + inputUnit + ' -> ' + rounded.toString() + ' ' + _items[index].unit + ')');
  }

  /// Awaits local persistence before the UI reports a stock change as saved.
  Future<bool> adjustConvertedAndPersist({
    required String outletId,
    required String id,
    required String type,
    required double amount,
    required String inputUnit,
    required String note,
  }) async {
    final changed = adjustConverted(
      outletId: outletId,
      id: id,
      type: type,
      amount: amount,
      inputUnit: inputUnit,
      note: note,
    );
    if (changed) await waitForPendingSave();
    return changed;
  }

  List<FirefaPrepRecipeLine> preparedRecipesForOutlet(String outletId) {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    return List.unmodifiable(_prepRecipes.where((line) => line.outletId == outletId));
  }

  String _preparedKey(String outletId, String itemId) => outletId + '::' + itemId;

  bool addPreparedRecipeLine({required String outletId, required String preparedItemId, required String ingredientId, required int quantity, required int outputQuantity}) {
    if (!_initialized || quantity <= 0 || quantity > 999999999 || outputQuantity <= 0 || outputQuantity > 999999999 || preparedItemId == ingredientId) return false;
    final target = _index(outletId, preparedItemId), ingredient = _index(outletId, ingredientId);
    if (target < 0 || ingredient < 0 || !_items[target].isPreparedIngredient) return false;
    final existing = _prepRecipes.indexWhere((line) => line.outletId == outletId && line.preparedItemId == preparedItemId && line.ingredientId == ingredientId);
    final line = FirefaPrepRecipeLine(outletId: outletId, preparedItemId: preparedItemId, ingredientId: ingredientId, quantity: quantity);
    if (existing >= 0) _prepRecipes[existing] = line; else _prepRecipes.add(line);
    _preparedYields[_preparedKey(outletId, preparedItemId)] = outputQuantity;
    notifyListeners(); _save(); return true;
  }

  Future<bool> producePreparedIngredient({required String outletId, required String preparedItemId, required int batches}) async {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    if (batches <= 0 || batches > 999999) throw ArgumentError('Jumlah batch harus positif.');
    final targetIndex = _index(outletId, preparedItemId);
    if (targetIndex < 0 || !_items[targetIndex].isPreparedIngredient) throw StateError('Pilih item yang ditandai sebagai bahan olahan.');
    final recipe = _prepRecipes.where((line) => line.outletId == outletId && line.preparedItemId == preparedItemId).toList();
    final yieldPerBatch = _preparedYields[_preparedKey(outletId, preparedItemId)] ?? 0;
    if (recipe.isEmpty || yieldPerBatch <= 0) throw StateError('Resep atau hasil produksi bahan olahan belum diatur.');
    final required = <String, int>{};
    for (final line in recipe) {
      if (line.quantity > 999999999 ~/ batches) throw StateError('Kebutuhan bahan terlalu besar.');
      final qty = line.quantity * batches, current = required[line.ingredientId] ?? 0;
      if (current > 999999999 - qty) throw StateError('Total bahan terlalu besar.');
      required[line.ingredientId] = current + qty;
    }
    for (final entry in required.entries) {
      final index = _index(outletId, entry.key);
      if (index < 0 || _items[index].stock < entry.value) throw StateError('Stok bahan tidak cukup: ' + (index < 0 ? entry.key : _items[index].name));
    }
    if (yieldPerBatch > 999999999 ~/ batches) throw StateError('Hasil produksi terlalu besar.');
    final output = yieldPerBatch * batches;
    final target = _items[targetIndex];
    if (target.stock > 999999999 - output) throw StateError('Stok hasil produksi melebihi batas.');
    final totalCost = required.entries.fold<double>(0, (sum, entry) => sum + entry.value * _items[_index(outletId, entry.key)].unitCost);
    final now = DateTime.now().toIso8601String();
    final oldItems = List<FirefaInventoryItem>.from(_items), oldMovements = List<FirefaStockMovement>.from(_movements);
    final oldNextMovementId = _nextMovementId;
    try {
      for (final entry in required.entries) {
        final index = _index(outletId, entry.key), old = _items[index], after = old.stock - entry.value;
        _items[index] = FirefaInventoryItem(id: old.id, outletId: old.outletId, name: old.name, unit: old.unit, stock: after,
          minimumStock: old.minimumStock, unitCost: old.unitCost, isPreparedIngredient: old.isPreparedIngredient);
        _movements.add(FirefaStockMovement(id: 'movement-' + (_nextMovementId++).toString(), outletId: outletId, itemId: old.id,
          itemName: old.name, type: 'out', before: old.stock, after: after, note: 'Produksi ' + preparedItemId + ' (' + batches.toString() + ' batch)', timestamp: now));
      }
      final refreshed = _items[_index(outletId, preparedItemId)], afterTarget = refreshed.stock + output;
      _items[_index(outletId, preparedItemId)] = FirefaInventoryItem(id: refreshed.id, outletId: refreshed.outletId, name: refreshed.name, unit: refreshed.unit,
        stock: afterTarget, minimumStock: refreshed.minimumStock, unitCost: (refreshed.stock * refreshed.unitCost + totalCost) / afterTarget, isPreparedIngredient: true);
      _movements.add(FirefaStockMovement(id: 'movement-' + (_nextMovementId++).toString(), outletId: outletId, itemId: refreshed.id,
        itemName: refreshed.name, type: 'in', before: refreshed.stock, after: afterTarget, note: 'Hasil produksi (' + batches.toString() + ' batch)', timestamp: now));
      notifyListeners(); _save(); await waitForPendingSave(); return true;
    } catch (_) {
      _items..clear()..addAll(oldItems); _movements..clear()..addAll(oldMovements);
      _nextMovementId = oldNextMovementId; notifyListeners(); _save(); rethrow;
    }
  }

  double hppForMenu({required String outletId, required String menuId}) {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    return _recipes.where((line) => line.outletId == outletId && line.menuId == menuId).fold<double>(0, (total, line) {
      final index = _index(outletId, line.ingredientId);
      return total + (index < 0 ? 0 : line.quantity * _items[index].unitCost);
    });
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
    if (menuLines.isEmpty) {
      throw StateError('Pesanan tidak memiliki item menu untuk validasi stok.');
    }
    final requiredQuantities = <String, int>{};
    for (final menu in menuLines) {
      if (menu.menuId.trim().isEmpty) {
        throw StateError('ID menu wajib diisi untuk validasi stok.');
      }
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

  /// Persist the exact recipe quantities before a POS order is created.
  /// Startup recovery uses this journal if the app stops before stock deduction.
  Future<bool> prepareOrderStockConsumption({
    required String orderId,
    required String outletId,
    required List<({String menuId, int quantity})> menuLines,
  }) async {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    if (orderId.trim().isEmpty || outletId.trim().isEmpty || menuLines.isEmpty ||
        menuLines.any((line) => line.menuId.trim().isEmpty || line.quantity <= 0)) {
      throw ArgumentError('Intent pemakaian stok tidak valid.');
    }
    final key = _orderStockKey(outletId, orderId);
    if (_containsOrderMarker(_processedOrderIds, outletId, orderId,
        legacyNote: 'POS order $orderId')) return false;
    if (!validateOrderStock(outletId: outletId, menuLines: menuLines)) return false;
    final serializedLines = menuLines.map((line) => <String, dynamic>{
      'menuId': line.menuId,
      'quantity': line.quantity,
    }).toList();
    final requiredIngredients = <String, int>{};
    for (final menu in menuLines) {
      for (final recipe in _recipes.where((line) =>
          line.outletId == outletId && line.menuId == menu.menuId)) {
        final quantity = recipe.quantity * menu.quantity;
        final current = requiredIngredients[recipe.ingredientId] ?? 0;
        if (current > 999999999 - quantity) {
          throw StateError('Total kebutuhan bahan melebihi batas.');
        }
        requiredIngredients[recipe.ingredientId] = current + quantity;
      }
    }
    final serializedIngredients = <String, int>{
      for (final entry in requiredIngredients.entries) entry.key: entry.value,
    };
    final existing = _pendingOrderConsumptions[key];
    if (existing != null) {
      if (jsonEncode(existing['menuLines']) != jsonEncode(serializedLines) ||
          jsonEncode(existing['ingredientQuantities']) != jsonEncode(serializedIngredients)) {
        throw StateError('Intent pemakaian stok order memiliki payload berbeda.');
      }
      return true;
    }
    _pendingOrderConsumptions[key] = {
      'orderId': orderId,
      'outletId': outletId,
      'menuLines': serializedLines,
      'ingredientQuantities': serializedIngredients,
    };
    notifyListeners();
    _save();
    await waitForPendingSave();
    return true;
  }

  /// Remove an intent only when checkout was abandoned before an order existed.
  Future<void> discardOrderStockIntent({
    required String orderId,
    required String outletId,
  }) async {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    if (_pendingOrderConsumptions.remove(_orderStockKey(outletId, orderId)) != null) {
      notifyListeners();
      _save();
      await waitForPendingSave();
    }
  }

  /// Resume interrupted checkouts from their durable journal. Orders which
  /// were never committed or were cancelled discard the intent; active orders
  /// consume the exact recipe lines captured before order creation.
  Future<int> recoverPendingOrderStock(Iterable<FirefaOrder> orders) async {
    if (!_initialized) await initialize();
    final ordersByKey = <String, FirefaOrder>{
      for (final order in orders) _orderStockKey(order.outletId, order.id): order,
    };
    var recovered = 0;
    final intents = Map<String, Map<String, dynamic>>.from(_pendingOrderConsumptions);
    for (final entry in intents.entries) {
      final intent = entry.value;
      final outletId = intent['outletId'] as String;
      final orderId = intent['orderId'] as String;
      final order = ordersByKey[entry.key];
      if (order == null || order.status == FirefaOrderStatus.cancelled ||
          _containsOrderMarker(_processedOrderIds, outletId, orderId,
              legacyNote: 'POS order $orderId')) {
        _pendingOrderConsumptions.remove(entry.key);
        continue;
      }
      final rawLines = intent['menuLines'];
      if (rawLines is! List) {
        throw const FormatException('Jurnal pemakaian stok tidak valid.');
      }
      final lines = rawLines.map((value) {
        final line = Map<String, dynamic>.from(value as Map);
        return (menuId: line['menuId'] as String, quantity: line['quantity'] as int);
      }).toList();
      try {
        if (await consumeOrderStock(
          orderId: orderId, outletId: outletId, menuLines: lines,
        )) {
          recovered++;
        } else if (_containsOrderMarker(_processedOrderIds, outletId, orderId,
            legacyNote: 'POS order $orderId')) {
          _pendingOrderConsumptions.remove(entry.key);
        }
      } catch (error) {
        debugPrint('FIREFA: pemulihan pemakaian stok order $orderId tertunda: $error');
      }
    }
    if (intents.isNotEmpty) {
      notifyListeners();
      _save();
      await waitForPendingSave();
    }
    return recovered;
  }

  Future<bool> consumeOrderStock({
    required String orderId,
    required String outletId,
    required List<({String menuId, int quantity})> menuLines,
  }) async {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    if (orderId.trim().isEmpty || outletId.trim().isEmpty) {
      throw ArgumentError('ID order dan outlet wajib diisi.');
    }
    if (_containsOrderMarker(_processedOrderIds, outletId, orderId,
        legacyNote: 'POS order $orderId')) return false;
    final intentKey = _orderStockKey(outletId, orderId);
    final preparedIntent = _pendingOrderConsumptions[intentKey];
    final requiredQuantities = <String, int>{};
    if (preparedIntent != null) {
      final expectedLines = (preparedIntent['menuLines'] as List).map((value) {
        final line = Map<String, dynamic>.from(value as Map);
        return {'menuId': line['menuId'], 'quantity': line['quantity']};
      }).toList();
      final suppliedLines = menuLines.map((line) => {
        'menuId': line.menuId, 'quantity': line.quantity,
      }).toList();
      if (jsonEncode(expectedLines) != jsonEncode(suppliedLines)) {
        throw StateError('Kuantitas checkout berbeda dari intent stok yang tersimpan.');
      }
      requiredQuantities.addAll(Map<String, int>.from(
        Map<String, dynamic>.from(preparedIntent['ingredientQuantities'] as Map)
            .map((key, value) => MapEntry(key, value as int)),
      ));
    } else {
      if (!validateOrderStock(outletId: outletId, menuLines: menuLines)) return false;
      final recipes = _recipes.where((line) => line.outletId == outletId).toList();
      for (final menu in menuLines) {
        for (final line in recipes.where((line) => line.menuId == menu.menuId)) {
          final needed = line.quantity * menu.quantity;
          final current = requiredQuantities[line.ingredientId] ?? 0;
          if (current > 999999999 - needed) {
            throw StateError('Total kebutuhan bahan melebihi batas.');
          }
          requiredQuantities[line.ingredientId] = current + needed;
        }
      }
    }
    for (final entry in requiredQuantities.entries) {
      final index = _index(outletId, entry.key);
      if (index < 0 || _items[index].stock < entry.value) {
        throw StateError('Stok berubah sebelum pesanan diproses. Silakan coba lagi.');
      }
    }

    final oldItems = List<FirefaInventoryItem>.from(_items);
    final oldMovements = List<FirefaStockMovement>.from(_movements);
    final oldProcessed = Set<String>.from(_processedOrderIds);
    final oldPendingIntents = Map<String, Map<String, dynamic>>.from(_pendingOrderConsumptions);
    final oldNextMovementId = _nextMovementId;
    try {
      final timestamp = DateTime.now().toIso8601String();
      for (final entry in requiredQuantities.entries) {
        final index = _index(outletId, entry.key);
        final old = _items[index];
        final after = old.stock - entry.value;
        _items[index] = FirefaInventoryItem(
          id: old.id, outletId: old.outletId, name: old.name,
          unit: old.unit, stock: after, minimumStock: old.minimumStock,
          unitCost: old.unitCost, isPreparedIngredient: old.isPreparedIngredient,
        );
        _movements.add(FirefaStockMovement(
          id: 'movement-${_nextMovementId++}', outletId: outletId,
          itemId: old.id, itemName: old.name, type: 'out',
          before: old.stock, after: after,
          note: 'POS order $orderId', timestamp: timestamp,
        ));
      }
      _processedOrderIds.add(_orderStockKey(outletId, orderId));
      _pendingOrderConsumptions.remove(intentKey);
      notifyListeners();
      _save();
      await waitForPendingSave();
      return true;
    } catch (_) {
      _items..clear()..addAll(oldItems);
      _movements..clear()..addAll(oldMovements);
      _processedOrderIds..clear()..addAll(oldProcessed);
      _pendingOrderConsumptions..clear()..addAll(oldPendingIntents);
      _nextMovementId = oldNextMovementId;
      notifyListeners();
      _save();
      await waitForPendingSave();
      rethrow;
    }
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
    if (_containsOrderMarker(_reversedOrderIds, outletId, orderId,
        legacyNote: 'Pembatalan POS order $orderId')) return false;
    final processedForOutlet = _containsOrderMarker(_processedOrderIds, outletId,
        orderId, legacyNote: 'POS order $orderId');
    if (!processedForOutlet) {
      final processedElsewhere = _processedOrderIds.contains(orderId) ||
          _hasScopedMarkerForOrder(_processedOrderIds, orderId);
      if (processedElsewhere) throw StateError('Stok order $orderId diproses di outlet lain.');
      return false;
    }
    final sourceMovements = _movements.where((movement) =>
      movement.outletId == outletId && movement.type == 'out' &&
      movement.note == 'POS order $orderId').toList();
    if (sourceMovements.isEmpty) {
      throw StateError('Riwayat pemakaian stok untuk order $orderId tidak ditemukan.');
    }
    final restorations = <({int index, int quantity})>[];
    for (final movement in sourceMovements) {
      final index = _index(outletId, movement.itemId);
      final quantity = movement.before - movement.after;
      if (index < 0 || quantity <= 0 || _items[index].stock > 999999999 - quantity) {
        throw StateError('Stok tidak dapat dipulihkan dengan aman untuk ${movement.itemName}.');
      }
      restorations.add((index: index, quantity: quantity));
    }
    final oldItems = List<FirefaInventoryItem>.from(_items);
    final oldMovements = List<FirefaStockMovement>.from(_movements);
    final oldReversed = Set<String>.from(_reversedOrderIds);
    final oldNextMovementId = _nextMovementId;
    try {
      final timestamp = DateTime.now().toIso8601String();
      for (final restoration in restorations) {
        final old = _items[restoration.index];
        final after = old.stock + restoration.quantity;
        _items[restoration.index] = FirefaInventoryItem(
          id: old.id, outletId: old.outletId, name: old.name,
          unit: old.unit, stock: after, minimumStock: old.minimumStock,
          unitCost: old.unitCost, isPreparedIngredient: old.isPreparedIngredient,
        );
        _movements.add(FirefaStockMovement(
          id: 'movement-${_nextMovementId++}', outletId: outletId,
          itemId: old.id, itemName: old.name, type: 'in',
          before: old.stock, after: after,
          note: 'Pembatalan POS order $orderId', timestamp: timestamp,
        ));
      }
      _reversedOrderIds.add(_orderStockKey(outletId, orderId));
      notifyListeners();
      _save();
      await waitForPendingSave();
      return true;
    } catch (_) {
      _items..clear()..addAll(oldItems);
      _movements..clear()..addAll(oldMovements);
      _reversedOrderIds..clear()..addAll(oldReversed);
      _nextMovementId = oldNextMovementId;
      notifyListeners();
      _save();
      await waitForPendingSave();
      rethrow;
    }
  }

  String _orderStockKey(String outletId, String orderId) =>
      jsonEncode([outletId, orderId]);

  /// New markers are outlet-scoped because local order IDs restart per outlet.
  /// Legacy raw IDs are still recognized conservatively for backward compatibility.
  bool _containsOrderMarker(
    Set<String> markers,
    String outletId,
    String orderId, {
    required String legacyNote,
  }) {
    if (markers.contains(_orderStockKey(outletId, orderId))) return true;
    if (!markers.contains(orderId)) return false;

    // Legacy records stored only the order ID. If their matching movement exists,
    // scope the marker to that movement's outlet. If no movement exists, preserve
    // the old marker conservatively rather than risk consuming/restoring twice.
    final hasScopedMovement = _movements.any((movement) =>
        movement.outletId == outletId && movement.note == legacyNote);
    final hasAnyMatchingMovement =
        _movements.any((movement) => movement.note == legacyNote);
    return hasScopedMovement || !hasAnyMatchingMovement;
  }

  bool isOrderStockProcessed(String orderId, {String? outletId}) {
    if (outletId != null) {
      return _containsOrderMarker(_processedOrderIds, outletId, orderId,
          legacyNote: 'POS order $orderId');
    }
    return _processedOrderIds.contains(orderId) ||
        _hasScopedMarkerForOrder(_processedOrderIds, orderId);
  }

  bool isOrderStockReversed(String orderId, {String? outletId}) {
    if (outletId != null) {
      return _containsOrderMarker(_reversedOrderIds, outletId, orderId,
          legacyNote: 'Pembatalan POS order $orderId');
    }
    return _reversedOrderIds.contains(orderId) ||
        _hasScopedMarkerForOrder(_reversedOrderIds, orderId);
  }

  bool _hasScopedMarkerForOrder(Set<String> markers, String orderId) {
    for (final marker in markers) {
      if (marker.startsWith('[')) {
        try {
          final decoded = jsonDecode(marker);
          if (decoded is List && decoded.length == 2 &&
              decoded[1] == orderId) {
            return true;
          }
        } catch (_) {
          // Other marker formats are legacy values, not scoped keys.
        }
      }
    }
    return false;
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
    _items[index] = FirefaInventoryItem(id: old.id, outletId: old.outletId, name: normalized, unit: unit, stock: old.stock, minimumStock: minimumStock, unitCost: old.unitCost, isPreparedIngredient: old.isPreparedIngredient);
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
    _items[index] = FirefaInventoryItem(id: old.id, outletId: old.outletId, name: old.name, unit: old.unit, stock: after, minimumStock: old.minimumStock, unitCost: old.unitCost, isPreparedIngredient: old.isPreparedIngredient);
    _movements.add(FirefaStockMovement(id: 'movement-${_nextMovementId++}', outletId: outletId, itemId: id, itemName: old.name, type: type, before: old.stock, after: after, note: note.trim(), timestamp: DateTime.now().toIso8601String()));
    notifyListeners();
    _save();
    return true;
  }

  /// Transfers stock between outlets as one local transaction.
  /// Reusing a transfer ID never applies the stock delta twice.
  Future<bool> transferStock({
    required String transferId,
    required String sourceOutletId,
    required String sourceItemId,
    required String targetOutletId,
    required String targetItemId,
    required int quantity,
    String note = '',
  }) async {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    final normalizedTransferId = transferId.trim();
    if (normalizedTransferId.isEmpty || normalizedTransferId.length > 120 || sourceOutletId.trim().isEmpty ||
        targetOutletId.trim().isEmpty || sourceOutletId == targetOutletId ||
        quantity <= 0 || quantity > 999999999 || note.trim().length > 160) {
      throw ArgumentError('Permintaan transfer stok tidak valid.');
    }
    if (_processedTransferIds.contains(normalizedTransferId)) return false;
    final sourceIndex = _index(sourceOutletId, sourceItemId);
    final targetIndex = _index(targetOutletId, targetItemId);
    if (sourceIndex < 0 || targetIndex < 0) {
      throw StateError('Barang sumber atau tujuan tidak ditemukan.');
    }
    final source = _items[sourceIndex];
    final target = _items[targetIndex];
    if (source.unit != target.unit) {
      throw StateError('Satuan barang sumber dan tujuan harus sama.');
    }
    if (source.stock < quantity) throw StateError('Stok sumber tidak cukup.');
    if (target.stock > 999999999 - quantity) {
      throw StateError('Stok tujuan melebihi batas yang didukung.');
    }

    final oldItems = List<FirefaInventoryItem>.from(_items);
    final oldMovements = List<FirefaStockMovement>.from(_movements);
    final oldTransfers = Set<String>.from(_processedTransferIds);
    final oldNextMovementId = _nextMovementId;
    try {
      final now = DateTime.now().toIso8601String();
      _items[sourceIndex] = FirefaInventoryItem(
        id: source.id, outletId: source.outletId, name: source.name,
        unit: source.unit, stock: source.stock - quantity,
        minimumStock: source.minimumStock, unitCost: source.unitCost,
        isPreparedIngredient: source.isPreparedIngredient,
      );
      _items[targetIndex] = FirefaInventoryItem(
        id: target.id, outletId: target.outletId, name: target.name,
        unit: target.unit, stock: target.stock + quantity,
        minimumStock: target.minimumStock, unitCost: source.unitCost,
        isPreparedIngredient: target.isPreparedIngredient,
      );
      final suffix = note.trim().isEmpty ? '' : ': ${note.trim()}';
      _movements
        ..add(FirefaStockMovement(
          id: 'movement-${_nextMovementId++}', outletId: sourceOutletId,
          itemId: source.id, itemName: source.name, type: 'out',
          before: source.stock, after: source.stock - quantity,
          note: 'Transfer $normalizedTransferId ke $targetOutletId$suffix', timestamp: now,
        ))
        ..add(FirefaStockMovement(
          id: 'movement-${_nextMovementId++}', outletId: targetOutletId,
          itemId: target.id, itemName: target.name, type: 'in',
          before: target.stock, after: target.stock + quantity,
          note: 'Transfer $normalizedTransferId dari $sourceOutletId$suffix', timestamp: now,
        ));
      _processedTransferIds.add(normalizedTransferId);
      notifyListeners();
      _save();
      await waitForPendingSave();
      return true;
    } catch (_) {
      _items..clear()..addAll(oldItems);
      _movements..clear()..addAll(oldMovements);
      _processedTransferIds..clear()..addAll(oldTransfers);
      _nextMovementId = oldNextMovementId;
      notifyListeners();
      _save();
      await waitForPendingSave();
      rethrow;
    }
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

  Future<bool> resolveOpname({
    required String outletId,
    required String opnameId,
    required bool approve,
  }) async {
    if (!_initialized) return false;
    final recordIndex = _opnames.indexWhere((record) =>
        record.id == opnameId && record.outletId == outletId &&
        record.status == 'pending');
    if (recordIndex < 0) return false;
    final record = _opnames[recordIndex];
    final itemIndex = _index(outletId, record.itemId);
    if (approve && (itemIndex < 0 ||
        _items[itemIndex].stock != record.systemStock)) return false;

    final oldItems = List<FirefaInventoryItem>.from(_items);
    final oldMovements = List<FirefaStockMovement>.from(_movements);
    final oldOpnames = List<FirefaStockOpname>.from(_opnames);
    final oldNextMovementId = _nextMovementId;
    try {
      if (approve && record.difference != 0) {
        final old = _items[itemIndex];
        _items[itemIndex] = FirefaInventoryItem(
          id: old.id, outletId: old.outletId, name: old.name,
          unit: old.unit, stock: record.physicalStock,
          minimumStock: old.minimumStock, unitCost: old.unitCost,
          isPreparedIngredient: old.isPreparedIngredient,
        );
        _movements.add(FirefaStockMovement(
          id: 'movement-${_nextMovementId++}', outletId: outletId,
          itemId: old.id, itemName: old.name, type: 'correction',
          before: old.stock, after: record.physicalStock,
          note: 'Stock opname ${record.id}: ${record.note}',
          timestamp: DateTime.now().toIso8601String(),
        ));
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
      await waitForPendingSave();
      return true;
    } catch (_) {
      _items..clear()..addAll(oldItems);
      _movements..clear()..addAll(oldMovements);
      _opnames..clear()..addAll(oldOpnames);
      _nextMovementId = oldNextMovementId;
      notifyListeners();
      _save();
      await waitForPendingSave();
      rethrow;
    }
  }

  /// Explains why an inventory item cannot safely be deleted.
  /// Historical movement rows are retained, but live references and stock
  /// must be resolved before removing the catalog item.
  String? removalBlockReason(String outletId, String id) {
    if (!_initialized) return 'Inventory belum diinisialisasi.';
    final index = _index(outletId, id);
    if (index < 0) return 'Barang tidak ditemukan pada outlet ini.';
    final item = _items[index];

    if (item.stock != 0) {
      return 'Sisa stok ${item.stock} ${item.unit}. Habiskan atau sesuaikan stok ke nol terlebih dahulu.';
    }
    if (_recipes.any((line) =>
        line.outletId == outletId && line.ingredientId == id)) {
      return 'Barang masih digunakan pada resep menu. Hapus atau ubah resep terkait terlebih dahulu.';
    }
    if (_prepRecipes.any((line) => line.outletId == outletId &&
        (line.ingredientId == id || line.preparedItemId == id))) {
      return 'Barang masih terkait resep bahan olahan. Hapus atau ubah resep olahan terlebih dahulu.';
    }
    if (_opnames.any((record) =>
        record.outletId == outletId &&
        record.itemId == id &&
        record.status == 'pending')) {
      return 'Masih ada stock opname yang menunggu keputusan.';
    }
    final hasUnreversedPosConsumption = _movements.any((movement) {
      if (movement.outletId != outletId ||
          movement.itemId != id ||
          movement.type != 'out' ||
          !movement.note.startsWith('POS order ')) {
        return false;
      }
      final orderId = movement.note.substring('POS order '.length);
      return !_reversedOrderIds.contains(orderId);
    });
    if (hasUnreversedPosConsumption) {
      return 'Barang masih terkait pemakaian stok pesanan POS yang belum dipulihkan.';
    }
    return null;
  }

  bool remove(String outletId, String id) {
    final reason = removalBlockReason(outletId, id);
    if (reason != null) return false;
    final index = _index(outletId, id);
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
      'prepRecipes': _prepRecipes.map((line) => line.toJson()).toList(),
      'preparedYields': _preparedYields,
      'processedOrderIds': _processedOrderIds.toList(),
      'reversedOrderIds': _reversedOrderIds.toList(),
      'processedTransferIds': _processedTransferIds.toList(),
      'pendingOrderConsumptions': _pendingOrderConsumptions,
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


  Map<String, dynamic> exportLocalSnapshot() {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    return {
      'version': 1,
      'nextId': _nextId,
      'items': _items.map((item) => item.toJson()).toList(),
      'nextMovementId': _nextMovementId,
      'movements': _movements.map((m) => m.toJson()).toList(),
      'nextOpnameId': _nextOpnameId,
      'opnames': _opnames.map((record) => record.toJson()).toList(),
      'recipes': _recipes.map((line) => line.toJson()).toList(),
      'prepRecipes': _prepRecipes.map((line) => line.toJson()).toList(),
      'preparedYields': _preparedYields,
      'processedOrderIds': _processedOrderIds.toList(),
      'reversedOrderIds': _reversedOrderIds.toList(),
      'processedTransferIds': _processedTransferIds.toList(),
      'pendingOrderConsumptions': _pendingOrderConsumptions,
    };
  }

  void validateLocalSnapshot(Map<String, dynamic> snapshot) {
    _validateSnapshotData(snapshot);
  }

  Future<void> restoreLocalSnapshot(Map<String, dynamic> snapshot) async {
    if (!_initialized) throw StateError('Inventory belum diinisialisasi');
    validateLocalSnapshot(snapshot);
    final items = (snapshot['items'] as List).map((e) => FirefaInventoryItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final movements = (snapshot['movements'] as List? ?? []).map((e) => FirefaStockMovement.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final opnames = (snapshot['opnames'] as List? ?? []).map((e) => FirefaStockOpname.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final recipes = (snapshot['recipes'] as List? ?? []).map((e) => FirefaRecipeLine.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final prepRecipes = (snapshot['prepRecipes'] as List? ?? []).map((e) => FirefaPrepRecipeLine.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final preparedYields = Map<String, int>.from(Map<String, dynamic>.from(snapshot['preparedYields'] as Map? ?? const {}).map((key, value) => MapEntry(key, value as int)));
    _items..clear()..addAll(items);
    _movements..clear()..addAll(movements);
    _opnames..clear()..addAll(opnames);
    _recipes..clear()..addAll(recipes);
    _prepRecipes..clear()..addAll(prepRecipes);
    _preparedYields..clear()..addAll(preparedYields);
    _processedOrderIds..clear()..addAll((snapshot['processedOrderIds'] as List? ?? []).cast<String>());
    _reversedOrderIds..clear()..addAll((snapshot['reversedOrderIds'] as List? ?? []).cast<String>());
    _processedTransferIds..clear()..addAll((snapshot['processedTransferIds'] as List? ?? []).cast<String>());
    _pendingOrderConsumptions..clear()..addAll(Map<String, Map<String, dynamic>>.from(
      Map<String, dynamic>.from(snapshot['pendingOrderConsumptions'] as Map? ?? const {}).map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
      ),
    ));
    _nextId = snapshot['nextId'] as int;
    _nextMovementId = snapshot['nextMovementId'] as int? ?? 1;
    _nextOpnameId = snapshot['nextOpnameId'] as int? ?? 1;
    notifyListeners();
    _save();
    await waitForPendingSave();
  }

  Future<void> waitForPendingSave() => _pendingSave;
}
