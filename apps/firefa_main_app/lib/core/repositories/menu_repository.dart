import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/menu_item.dart';

class MenuRepository {
  MenuRepository({this._preferences});

  static const storageKey = 'firefa_core_products_v1';
  SharedPreferences? _preferences;
  bool _initialized = false;
  final Map<String, MenuItem> _menus = {};

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await _prefs;
    final raw = prefs.getString(storageKey);
    final restored = <String, MenuItem>{};
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final value in decoded) {
        final menu = MenuItem.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
        if (menu.id.trim().isEmpty || restored.containsKey(menu.id)) {
          throw const FormatException('Produk tidak valid atau ID duplikat.');
        }
        restored[menu.id] = menu;
      }
    } else {
      restored.addAll({
        '1': const MenuItem(
          id: '1',
          name: 'Nasi Goreng Special',
          category: 'Food',
          price: 25000,
          available: true,
        ),
        '2': const MenuItem(
          id: '2',
          name: 'Es Teh',
          category: 'Drink',
          price: 8000,
          available: true,
        ),
      });
      await _persist(restored);
    }
    _menus
      ..clear()
      ..addAll(restored);
    _initialized = true;
  }

  List<MenuItem> getMenus({String? outletId, bool availableOnly = false}) {
    _ensureInitialized();
    final values = _menus.values.where((menu) {
      final outletMatches = outletId == null ||
          menu.outletId == null ||
          menu.outletId == outletId;
      return outletMatches && (!availableOnly || menu.available);
    });
    return List.unmodifiable(values);
  }

  MenuItem? findById(String id) {
    _ensureInitialized();
    return _menus[id.trim()];
  }

  Future<void> save(MenuItem menu) async {
    await initialize();
    final id = menu.id.trim();
    final name = menu.name.trim();
    final category = menu.category.trim();
    if (id.isEmpty || id.length > 100 || name.isEmpty || name.length > 160 ||
        category.isEmpty || menu.price < 0) {
      throw ArgumentError('Data produk tidak valid.');
    }
    _validateUniqueIdentifiers(menu, excludingId: id);
    final normalized = MenuItem(
      id: id,
      name: name,
      category: category,
      price: menu.price,
      available: menu.available,
      outletId: menu.outletId?.trim(),
      sku: menu.sku?.trim(),
      barcode: menu.barcode?.trim(),
      variants: List.unmodifiable(menu.variants),
    );
    final next = Map<String, MenuItem>.from(_menus)..[id] = normalized;
    await _persist(next);
    _menus
      ..clear()
      ..addAll(next);
  }

  Future<bool> remove(String id) async {
    await initialize();
    final key = id.trim();
    if (!_menus.containsKey(key)) return false;
    final next = Map<String, MenuItem>.from(_menus)..remove(key);
    await _persist(next);
    _menus
      ..clear()
      ..addAll(next);
    return true;
  }

  void _validateUniqueIdentifiers(MenuItem candidate, {required String excludingId}) {
    for (final existing in _menus.values) {
      if (existing.id == excludingId) continue;
      final sameOutlet = existing.outletId == candidate.outletId;
      if (!sameOutlet) continue;
      if (_sameNonEmpty(existing.sku, candidate.sku) ||
          _sameNonEmpty(existing.barcode, candidate.barcode)) {
        throw StateError('SKU atau barcode sudah digunakan pada outlet ini.');
      }
    }
    final variantIds = <String>{};
    final variantCodes = <String>{};
    for (final variant in candidate.variants) {
      if (variant.id.trim().isEmpty || variant.name.trim().isEmpty ||
          variant.price < 0 || !variantIds.add(variant.id.trim())) {
        throw ArgumentError('Varian produk tidak valid atau duplikat.');
      }
      for (final code in [variant.sku, variant.barcode]) {
        final normalized = code?.trim() ?? '';
        if (normalized.isNotEmpty && !variantCodes.add(normalized)) {
          throw ArgumentError('SKU/barcode varian duplikat.');
        }
      }
    }
  }

  bool _sameNonEmpty(String? first, String? second) {
    final a = first?.trim().toLowerCase() ?? '';
    final b = second?.trim().toLowerCase() ?? '';
    return a.isNotEmpty && a == b;
  }

  Future<void> _persist(Map<String, MenuItem> values) async {
    final data = jsonEncode(values.values.map((item) => item.toJson()).toList());
    if (!await (await _prefs).setString(storageKey, data)) {
      throw StateError('Gagal menyimpan data produk.');
    }
  }

  void _ensureInitialized() {
    if (!_initialized) throw StateError('MenuRepository belum diinisialisasi.');
  }
}
