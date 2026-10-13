import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'conflict_management.dart';

/// Durable local conflict inbox. Conflicts remain separate from business data.
class FirefaConflictStore extends ChangeNotifier {
  FirefaConflictStore._();
  static final FirefaConflictStore instance = FirefaConflictStore._();
  static const _key = 'firefa_conflict_inbox_v1';
  final List<FirefaSyncConflict> _items = [];
  bool _initialized = false;
  Future<void> _pendingSave = Future<void>.value();
  List<FirefaSyncConflict> get conflicts => List.unmodifiable(_items);
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      _items..clear()..addAll((jsonDecode(raw) as List).map(_fromJson));
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> add(FirefaSyncConflict conflict) async {
    if (!_initialized) throw StateError('Conflict inbox belum diinisialisasi.');
    final index = _items.indexWhere((item) => item.eventId == conflict.eventId);
    final previous = index >= 0 ? _items[index] : null;
    if (index >= 0) { _items[index] = conflict; } else { _items.add(conflict); }
    try { await _save(); } catch (_) {
      if (index >= 0 && previous != null) { _items[index] = previous; }
      else { _items.remove(conflict); }
      rethrow;
    }
    notifyListeners();
  }

  Future<void> remove(String eventId) async {
    final removed = _items.where((item) => item.eventId == eventId).toList();
    _items.removeWhere((item) => item.eventId == eventId);
    try { await _save(); } catch (_) { _items.addAll(removed); rethrow; }
    notifyListeners();
  }

  Future<void> _save() {
    final snapshot = jsonEncode(_items.map((item) => item.toJson()).toList());
    _pendingSave = _pendingSave.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_key, snapshot)) {
        throw StateError('Gagal menyimpan conflict inbox lokal.');
      }
    });
    return _pendingSave;
  }

  FirefaSyncConflict _fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return FirefaSyncConflict(
      eventId: json['eventId'] as String,
      outletId: json['outletId'] as String,
      orderId: json['orderId'] as String,
      kind: FirefaConflictKind.values.byName(json['kind'] as String),
      localSnapshot: Map<String, dynamic>.from(json['localSnapshot'] as Map),
      serverSnapshot: Map<String, dynamic>.from(json['serverSnapshot'] as Map),
      detectedAt: DateTime.parse(json['detectedAt'] as String),
    );
  }
}
