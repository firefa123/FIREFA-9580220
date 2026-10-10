import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'conflict_management.dart';

/// Durable local conflict inbox. Conflicts are stored separately from orders
/// so resolving a conflict never mutates active POS transactions implicitly.
class FirefaConflictStore extends ChangeNotifier {
  FirefaConflictStore._();
  static final FirefaConflictStore instance = FirefaConflictStore._();

  static const _key = 'firefa_conflict_inbox_v1';
  final List<FirefaSyncConflict> _items = [];
  bool _initialized = false;

  List<FirefaSyncConflict> get conflicts => List.unmodifiable(_items);

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final data = jsonDecode(raw) as List;
      _items
        ..clear()
        ..addAll(data.map(_fromJson));
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> add(FirefaSyncConflict conflict) async {
    _items.add(conflict);
    await _save();
    notifyListeners();
  }

  Future<void> remove(String eventId) async {
    _items.removeWhere((item) => item.eventId == eventId);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(
      _items.map((item) => item.toJson()).toList(),
    ));
  }

  FirefaSyncConflict _fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return FirefaSyncConflict(
      eventId: json['eventId'],
      outletId: json['outletId'],
      orderId: json['orderId'],
      kind: FirefaConflictKind.values.byName(json['kind']),
      localSnapshot: Map<String, dynamic>.from(json['localSnapshot']),
      serverSnapshot: Map<String, dynamic>.from(json['serverSnapshot']),
      detectedAt: DateTime.parse(json['detectedAt']),
    );
  }
}
