import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirefaSupplier {
  const FirefaSupplier({
    required this.id,
    required this.outletId,
    required this.name,
    required this.contact,
    required this.phone,
    required this.address,
    required this.isActive,
  });

  final String id, outletId, name, contact, phone, address;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'id': id, 'outletId': outletId, 'name': name,
    'contact': contact, 'phone': phone, 'address': address,
    'isActive': isActive,
  };

  factory FirefaSupplier.fromJson(Map<String, dynamic> json) => FirefaSupplier(
    id: json['id'] as String,
    outletId: json['outletId'] as String,
    name: json['name'] as String,
    contact: json['contact'] as String,
    phone: json['phone'] as String,
    address: json['address'] as String,
    isActive: json['isActive'] as bool,
  );
}

class FirefaSupplierStore extends ChangeNotifier {
  FirefaSupplierStore._();
  static final FirefaSupplierStore instance = FirefaSupplierStore._();
  static const storageKey = 'firefa_suppliers_v1';

  final List<FirefaSupplier> _suppliers = [];
  Future<void>? _initializing;
  Future<void> _pendingSave = Future<void>.value();
  bool _initialized = false;
  int _nextId = 1;

  Future<void> initialize() => _initializing ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final restored = (decoded['suppliers'] as List<dynamic>)
            .map((entry) => FirefaSupplier.fromJson(Map<String, dynamic>.from(entry as Map)))
            .toList();
        _suppliers..clear()..addAll(restored);
        _nextId = decoded['nextId'] as int;
      }
      _initialized = true;
      notifyListeners();
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  List<FirefaSupplier> forOutlet(String outletId) {
    if (!_initialized) throw StateError('Supplier belum diinisialisasi');
    return List.unmodifiable(_suppliers.where((s) => s.outletId == outletId));
  }

  bool _valid({
    required String outletId,
    required String name,
    required String contact,
    required String phone,
    required String address,
    String? exceptId,
  }) {
    final normalized = name.trim().toLowerCase();
    return outletId.trim().isNotEmpty &&
        normalized.isNotEmpty && normalized.length <= 80 &&
        contact.trim().length <= 80 && phone.trim().length <= 30 &&
        address.trim().length <= 250 &&
        !_suppliers.any((s) => s.outletId == outletId &&
            s.id != exceptId && s.name.toLowerCase() == normalized);
  }

  bool add({
    required String outletId, required String name,
    required String contact, required String phone, required String address,
  }) {
    if (!_initialized || !_valid(outletId: outletId, name: name,
        contact: contact, phone: phone, address: address)) return false;
    _suppliers.add(FirefaSupplier(
      id: 'supplier-${_nextId++}', outletId: outletId,
      name: name.trim(), contact: contact.trim(),
      phone: phone.trim(), address: address.trim(), isActive: true,
    ));
    notifyListeners();
    _save();
    return true;
  }

  bool update({
    required String outletId, required String id, required String name,
    required String contact, required String phone, required String address,
  }) {
    if (!_initialized || !_valid(outletId: outletId, name: name,
        contact: contact, phone: phone, address: address, exceptId: id)) return false;
    final index = _suppliers.indexWhere((s) => s.outletId == outletId && s.id == id);
    if (index < 0) return false;
    final old = _suppliers[index];
    _suppliers[index] = FirefaSupplier(
      id: id, outletId: outletId, name: name.trim(),
      contact: contact.trim(), phone: phone.trim(),
      address: address.trim(), isActive: old.isActive,
    );
    notifyListeners();
    _save();
    return true;
  }

  bool setActive(String outletId, String id, bool active) {
    if (!_initialized) return false;
    final index = _suppliers.indexWhere((s) => s.outletId == outletId && s.id == id);
    if (index < 0) return false;
    final old = _suppliers[index];
    _suppliers[index] = FirefaSupplier(
      id: old.id, outletId: old.outletId, name: old.name,
      contact: old.contact, phone: old.phone,
      address: old.address, isActive: active,
    );
    notifyListeners();
    _save();
    return true;
  }

  void _save() {
    final snapshot = jsonEncode({
      'version': 1, 'nextId': _nextId,
      'suppliers': _suppliers.map((s) => s.toJson()).toList(),
    });
    _pendingSave = _pendingSave.catchError((Object error) {
      debugPrint('Supplier save sebelumnya gagal: $error');
    }).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, snapshot)) {
        throw StateError('Gagal menyimpan supplier lokal');
      }
    });
    unawaited(_pendingSave.catchError((Object error) {
      debugPrint('Supplier save gagal: $error');
    }));
  }

  Future<void> waitForPendingSave() => _pendingSave;
}
