import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirefaMenuItem {
  const FirefaMenuItem({
    required this.id,
    required this.outletId,
    required this.name,
    required this.category,
    required this.price,
    required this.isActive,
  });

  final String id;
  final String outletId;
  final String name;
  final String category;
  final int price;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'id': id,
    'outletId': outletId,
    'name': name,
    'category': category,
    'price': price,
    'isActive': isActive,
  };

  factory FirefaMenuItem.fromJson(Map<String, dynamic> json) => FirefaMenuItem(
    id: json['id'] as String,
    outletId: json['outletId'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    price: json['price'] as int,
    isActive: json['isActive'] as bool,
  );

  FirefaMenuItem copyWith({bool? isActive, String? name, String? category, int? price}) => FirefaMenuItem(
    id: id,
    outletId: outletId,
    name: name ?? this.name,
    category: category ?? this.category,
    price: price ?? this.price,
    isActive: isActive ?? this.isActive,
  );
}

/// Independent local catalog; POS still uses its existing demo products.
class FirefaMenuStore extends ChangeNotifier {
  FirefaMenuStore._();
  static final FirefaMenuStore instance = FirefaMenuStore._();

  static const storageKey = 'firefa_menu_catalog_v1';
  static const categories = <String>[
    'Coffee', 'Non Coffee', 'Food', 'Snacks', 'Dessert', 'Other',
  ];

  final List<FirefaMenuItem> _items = [];
  bool _initialized = false;
  Future<void> _pendingSave = Future<void>.value();
  int _nextId = 1;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = (decoded['items'] as List<dynamic>)
          .map((value) => FirefaMenuItem.fromJson(
              Map<String, dynamic>.from(value as Map)))
          .toList();
      final nextId = decoded['nextId'] as int;
      _items..clear()..addAll(items);
      _nextId = nextId;
    }
    _initialized = true;
    notifyListeners();
  }

  List<FirefaMenuItem> forOutlet(String outletId) {
    if (!_initialized) {
      throw StateError('FirefaMenuStore.initialize() belum dipanggil');
    }
    return List.unmodifiable(
      _items.where((item) => item.outletId == outletId),
    );
  }

  bool add({
    required String outletId,
    required String name,
    required String category,
    required int price,
  }) {
    if (!_initialized) return false;
    final normalized = name.trim();
    if (outletId.isEmpty ||
        normalized.isEmpty ||
        normalized.length > 80 ||
        !categories.contains(category) ||
        price <= 0 ||
        price > 999999999 ||
        _items.any((item) =>
            item.outletId == outletId &&
            item.name.toLowerCase() == normalized.toLowerCase())) {
      return false;
    }

    _items.add(FirefaMenuItem(
      id: 'menu-${_nextId++}',
      outletId: outletId,
      name: normalized,
      category: category,
      price: price,
      isActive: true,
    ));
    notifyListeners();
    _save();
    return true;
  }

  bool setActive(String outletId, String id, bool active) {
    if (!_initialized) return false;
    final index = _items.indexWhere(
      (item) => item.outletId == outletId && item.id == id,
    );
    if (index < 0) return false;
    if (_items[index].isActive == active) return true;
    _items[index] = _items[index].copyWith(isActive: active);
    notifyListeners();
    _save();
    return true;
  }

  bool update({
    required String outletId,
    required String id,
    required String name,
    required String category,
    required int price,
  }) {
    if (!_initialized) return false;
    final index = _items.indexWhere(
      (item) => item.outletId == outletId && item.id == id,
    );
    final normalized = name.trim();
    if (index < 0 ||
        normalized.isEmpty ||
        normalized.length > 80 ||
        !categories.contains(category) ||
        price <= 0 ||
        price > 999999999 ||
        _items.any((item) =>
            item.outletId == outletId &&
            item.id != id &&
            item.name.toLowerCase() == normalized.toLowerCase())) {
      return false;
    }
    final current = _items[index];
    if (current.name == normalized &&
        current.category == category &&
        current.price == price) {
      return true;
    }
    _items[index] = current.copyWith(
      name: normalized,
      category: category,
      price: price,
    );
    notifyListeners();
    _save();
    return true;
  }

  bool remove(String outletId, String id) {
    if (!_initialized) return false;
    final index = _items.indexWhere(
      (item) => item.outletId == outletId && item.id == id,
    );
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
    });
    _pendingSave = _pendingSave
        .catchError((Object error) {
          debugPrint('FIREFA menu save sebelumnya gagal: $error');
        })
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          if (!await prefs.setString(storageKey, snapshot)) {
            throw StateError('Gagal menyimpan katalog menu lokal');
          }
        });
    unawaited(_pendingSave.catchError((Object error) {
      debugPrint('FIREFA menu save gagal: $error');
    }));
  }

  Future<void> waitForPendingSave() => _pendingSave;
}
