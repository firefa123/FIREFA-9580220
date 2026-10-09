import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirefaTable {
  const FirefaTable({required this.id, required this.outletId, required this.name, required this.occupied});
  final String id;
  final String outletId;
  final String name;
  final bool occupied;

  Map<String, dynamic> toJson() => {'id': id, 'outletId': outletId, 'name': name, 'occupied': occupied};
  factory FirefaTable.fromJson(Map<String, dynamic> json) => FirefaTable(
    id: json['id'] as String,
    outletId: json['outletId'] as String,
    name: json['name'] as String,
    occupied: json['occupied'] as bool,
  );
  FirefaTable copyWith({bool? occupied, String? name}) => FirefaTable(
    id: id, outletId: outletId, name: name ?? this.name, occupied: occupied ?? this.occupied,
  );
}

/// Local-only table layout. Not connected to POS or the offline order outbox.
class FirefaTableStore extends ChangeNotifier {
  FirefaTableStore._();
  static final FirefaTableStore instance = FirefaTableStore._();
  static const _key = 'firefa_tables_v1';
  final List<FirefaTable> _tables = [];
  bool _initialized = false;
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

  List<FirefaTable> forOutlet(String outletId) {
    if (!_initialized) throw StateError('FirefaTableStore must be initialized');
    return List.unmodifiable(_tables.where((table) => table.outletId == outletId));
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
    _tables[index] = _tables[index].copyWith(occupied: occupied);
    notifyListeners();
    _save();
    return true;
  }

  bool rename(String outletId, String id, String name) {
    if (!_initialized) return false;
    final normalized = name.trim();
    final index = _tables.indexWhere((t) => t.id == id && t.outletId == outletId);
    if (index < 0 || normalized.isEmpty || normalized.length > 40) return false;
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
    if (index < 0) return false;
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

  Future<void> waitForPendingSave() => _pendingSave;
}
