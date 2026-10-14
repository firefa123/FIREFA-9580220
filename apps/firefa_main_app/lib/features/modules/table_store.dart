import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirefaTable {
  const FirefaTable({required this.id, required this.outletId, required this.name, required this.occupied, this.reservationOrderId});
  final String id;
  final String outletId;
  final String name;
  final bool occupied;
  final String? reservationOrderId;

  Map<String, dynamic> toJson() => {'id': id, 'outletId': outletId, 'name': name, 'occupied': occupied, if (reservationOrderId != null) 'reservationOrderId': reservationOrderId};
  factory FirefaTable.fromJson(Map<String, dynamic> json) => FirefaTable(
    id: json['id'] as String,
    outletId: json['outletId'] as String,
    name: json['name'] as String,
    occupied: json['occupied'] as bool,
    reservationOrderId: json['reservationOrderId'] as String?,
  );
  FirefaTable copyWith({bool? occupied, String? name, String? reservationOrderId, bool clearReservationOrderId = false}) => FirefaTable(
    id: id, outletId: outletId, name: name ?? this.name, occupied: occupied ?? this.occupied,
    reservationOrderId: clearReservationOrderId ? null : reservationOrderId ?? this.reservationOrderId,
  );
}

/// Local-only table layout. Not connected to POS or the offline order outbox.
class FirefaTableStore extends ChangeNotifier {
  FirefaTableStore._();
  static final FirefaTableStore instance = FirefaTableStore._();
  static const _key = 'firefa_tables_v1';
  final List<FirefaTable> _tables = [];
  bool _initialized = false;
  bool Function(String outletId, String tableName)? _hasActiveOrder;
  Future<void> _pendingSave = Future<void>.value();

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final restored = decoded.map((value) => FirefaTable.fromJson(Map<String, dynamic>.from(value as Map))).toList();
      _tables..clear()..addAll(restored);
    }
    _initialized = true;
    notifyListeners();
  }

  /// Registers the order store's source of truth for active dine-in orders.
  /// Keeping this as a callback avoids coupling the two persistence stores.
  void setActiveOrderChecker(bool Function(String outletId, String tableName)? checker) {
    _hasActiveOrder = checker;
  }

  bool _hasActiveOrderFor(FirefaTable table) =>
      _hasActiveOrder?.call(table.outletId, table.name) ?? false;

  List<FirefaTable> forOutlet(String outletId) {
    if (!_initialized) throw StateError('FirefaTableStore must be initialized');
    return List.unmodifiable(_tables.where((table) => table.outletId == outletId));
  }

  List<FirefaTable> allTablesForSync() {
    if (!_initialized) throw StateError('FirefaTableStore must be initialized');
    return List.unmodifiable(_tables);
  }

  bool add(String outletId, String name) {
    if (!_initialized) return false;
    final normalized = name.trim();
    if (outletId.trim().isEmpty || normalized.isEmpty || normalized.length > 40 || _tables.any((t) => t.outletId == outletId && t.name.toLowerCase() == normalized.toLowerCase())) return false;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _tables.add(FirefaTable(id: id, outletId: outletId, name: normalized, occupied: false));
    notifyListeners();
    _save();
    return true;
  }

  bool setOccupied(String outletId, String id, bool occupied) {
    if (!_initialized) return false;
    final index = _tables.indexWhere((t) => t.id == id && t.outletId == outletId);
    if (index < 0) return false;
    if (_tables[index].occupied == occupied) return true;
    if (!occupied && _hasActiveOrderFor(_tables[index])) return false;
    _tables[index] = _tables[index].copyWith(occupied: occupied);
    notifyListeners();
    _save();
    return true;
  }

  /// Reserves a table for a specific POS order, distinguishing order reservations
  /// from manual occupancy so interrupted completion can be repaired on restart.
  bool reserveForOrder(String outletId, String id, String orderId) {
    if (!_initialized || orderId.trim().isEmpty) return false;
    final index = _tables.indexWhere((t) => t.id == id && t.outletId == outletId);
    if (index < 0) return false;
    final table = _tables[index];
    if (table.reservationOrderId != null && table.reservationOrderId != orderId) {
      return false;
    }
    if (table.occupied && table.reservationOrderId == null &&
        !_hasActiveOrderFor(table)) {
      // A manually occupied table cannot be silently taken by a new order.
      return false;
    }
    _tables[index] = table.copyWith(occupied: true, reservationOrderId: orderId);
    notifyListeners();
    _save();
    return true;
  }

  /// Releases only the reservation owned by the specified order.
  bool releaseOrderReservation(String outletId, String id, String orderId) {
    if (!_initialized) return false;
    final index = _tables.indexWhere((t) => t.id == id && t.outletId == outletId);
    if (index < 0 || _tables[index].reservationOrderId != orderId) return false;
    _tables[index] = _tables[index].copyWith(
      occupied: false,
      clearReservationOrderId: true,
    );
    notifyListeners();
    _save();
    return true;
  }

  bool rename(String outletId, String id, String name) {
    if (!_initialized) return false;
    final normalized = name.trim();
    final index = _tables.indexWhere((t) => t.id == id && t.outletId == outletId);
    if (index < 0 || normalized.isEmpty || normalized.length > 40) {
      return false;
    }
    if (_hasActiveOrderFor(_tables[index])) {
      return false;
    }
    if (_tables.any((t) => t.outletId == outletId && t.id != id &&
        t.name.toLowerCase() == normalized.toLowerCase())) {
      return false;
    }
    if (_tables[index].name == normalized) return true;
    _tables[index] = _tables[index].copyWith(name: normalized);
    notifyListeners();
    _save();
    return true;
  }

  bool remove(String outletId, String id) {
    if (!_initialized) return false;
    final index = _tables.indexWhere((t) => t.id == id && t.outletId == outletId);
    if (index < 0 || _hasActiveOrderFor(_tables[index])) return false;
    _tables.removeAt(index);
    notifyListeners();
    _save();
    return true;
  }

  void _save() {
    final snapshot = jsonEncode(_tables.map((t) => t.toJson()).toList());
    _pendingSave = _pendingSave.catchError((Object e) { debugPrint('Table save failed: $e'); }).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_key, snapshot)) throw StateError('Table save failed');
    });
    unawaited(_pendingSave.catchError((Object e) { debugPrint('Table save failed: $e'); }));
  }


  List<Map<String, dynamic>> exportLocalSnapshot() {
    if (!_initialized) throw StateError('Meja belum diinisialisasi');
    return _tables.map((table) => table.toJson()).toList();
  }

  void validateLocalSnapshot(List<dynamic> snapshot) {
    final tables = snapshot.map((e) => FirefaTable.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final ids = <String>{};
    for (final table in tables) {
      if (table.id.trim().isEmpty || table.outletId.trim().isEmpty || table.name.trim().isEmpty ||
          !ids.add('${table.outletId}:${table.id}')) {
        throw const FormatException('Data meja pada backup tidak valid.');
      }
    }
  }

  Future<void> restoreLocalSnapshot(List<dynamic> snapshot) async {
    if (!_initialized) throw StateError('Meja belum diinisialisasi');
    validateLocalSnapshot(snapshot);
    final tables = snapshot.map((e) => FirefaTable.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    _tables..clear()..addAll(tables);
    notifyListeners();
    _save();
    await waitForPendingSave();
  }

  Future<void> waitForPendingSave() => _pendingSave;
}
