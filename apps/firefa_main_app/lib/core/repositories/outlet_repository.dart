import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/outlet_model.dart';

class OutletRepository {
  OutletRepository({this._preferences});

  static const storageKey = 'firefa_core_outlets_v1';
  SharedPreferences? _preferences;
  bool _initialized = false;
  final Map<String, OutletModel> _outlets = {};

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await _prefs;
    final raw = prefs.getString(storageKey);
    final restored = <String, OutletModel>{};
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final value in decoded) {
        final outlet = OutletModel.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
        if (outlet.id.trim().isEmpty || restored.containsKey(outlet.id)) {
          throw const FormatException('Data outlet tidak valid atau duplikat.');
        }
        restored[outlet.id] = outlet;
      }
    } else {
      restored.addAll({
        'outlet-001': const OutletModel(
          id: 'outlet-001',
          name: 'Outlet Utama',
          address: '',
          active: true,
        ),
        'outlet-002': const OutletModel(
          id: 'outlet-002',
          name: 'Outlet 2',
          address: '',
          active: true,
        ),
      });
      await _persist(restored);
    }
    _outlets
      ..clear()
      ..addAll(restored);
    _initialized = true;
  }

  List<OutletModel> getOutlets({bool activeOnly = false}) {
    _ensureInitialized();
    final values = _outlets.values.where(
      (outlet) => !activeOnly || outlet.active,
    );
    return List.unmodifiable(values);
  }

  OutletModel? findById(String id) {
    _ensureInitialized();
    return _outlets[id.trim()];
  }

  Future<void> save(OutletModel outlet) async {
    await initialize();
    final id = outlet.id.trim();
    final name = outlet.name.trim();
    if (id.isEmpty || id.length > 100 || name.isEmpty || name.length > 160 ||
        outlet.address.length > 240) {
      throw ArgumentError('Data outlet tidak valid.');
    }
    final normalized = OutletModel(
      id: id,
      name: name,
      address: outlet.address.trim(),
      active: outlet.active,
      tenantId: outlet.tenantId?.trim(),
    );
    final next = Map<String, OutletModel>.from(_outlets)..[id] = normalized;
    await _persist(next);
    _outlets
      ..clear()
      ..addAll(next);
  }

  Future<bool> remove(String id) async {
    await initialize();
    final key = id.trim();
    if (!_outlets.containsKey(key)) return false;
    final next = Map<String, OutletModel>.from(_outlets)..remove(key);
    await _persist(next);
    _outlets
      ..clear()
      ..addAll(next);
    return true;
  }

  Future<void> _persist(Map<String, OutletModel> values) async {
    final data = jsonEncode(values.values.map((item) => item.toJson()).toList());
    if (!await (await _prefs).setString(storageKey, data)) {
      throw StateError('Gagal menyimpan data outlet.');
    }
  }

  void _ensureInitialized() {
    if (!_initialized) throw StateError('OutletRepository belum diinisialisasi.');
  }
}
